#!/bin/bash
#SBATCH --job-name=bam2assembly
#SBATCH --output=bam2assembly_%j.log
#SBATCH --error=bam2assembly_%j.err
#SBATCH --cpus-per-task=4              # CHANGE: number of CPUs (THREADS is taken from this)
#SBATCH --mem=64G                      # CHANGE: memory (SPAdes on large genomes may need a lot more)
#SBATCH --partition=<partition>        # CHANGE: your cluster's partition name

# ===========================================================================
# bam2assembly.sh
# version: 1.0
#
# Coverage summary, mapped-read extraction, de novo assembly and assembly QC
# for a single sample, starting from a mapped, sorted BAM.
#
#   1. Per-contig and sliding-window coverage of the BAM (samtools)
#   2. Extract read pairs where both mates are mapped and write paired FASTQs
#      (skipped if the FASTQs already exist in OUTDIR)
#   3. SPAdes assembly from the extracted FASTQs
#   4. QUAST assembly statistics (optionally against a reference)
#   5. BUSCO completeness assessment
#
# Requirements:
#   - Conda environment with SPAdes + samtools   (SPADES_ENV)
#   - Conda environment with QUAST + BUSCO       (ASSESS_ENV)
#
# Input:
#   - Sorted, indexed BAM of reads mapped to a reference   (INPUT_BAM)
#
# Main outputs (in OUTDIR):
#   - <SAMPLE>.coverage_summary.txt, <SAMPLE>.sliding_window_coverage.tsv
#   - <SAMPLE>.mapped_pairs.bam (reads with both mates mapped)
#   - <SAMPLE>.mapped_R1.fastq.gz, <SAMPLE>.mapped_R2.fastq.gz
#   - spades_assembly/, quast_output/, <SAMPLE>_busco/
#
# Usage:
#   Edit the SBATCH header and User config block, then:
#   sbatch bam2assembly.sh
# ===========================================================================

# ---- User config ----
INPUT_BAM="/path/to/<SAMPLE>.sorted.bam"      # mapped, sorted BAM (sole input)
OUTDIR="/path/to/output_dir"                  # output directory
SAMPLE="<SAMPLE_ID>"                          # sample name, used as a prefix for all outputs
THREADS="${SLURM_CPUS_PER_TASK:-4}"           # taken from --cpus-per-task; falls back to 4
WINDOW_SIZE=10000                             # sliding window size (bp) for coverage
REFERENCE_FASTA=""                            # optional: reference genome FASTA (.fa/.fna, gz OK) for QUAST -r; leave "" to skip
BUSCO_LINEAGE="<lineage>_odb10"               # BUSCO lineage dataset appropriate for your organism (e.g. mammalia_odb10)
SPADES_ENV="<spades_env>"                     # conda env containing SPAdes + samtools
ASSESS_ENV="<assembly_assessment_env>"        # conda env containing QUAST + BUSCO
# ----------------------

# Make 'conda activate' available in a non-interactive batch shell
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "${SPADES_ENV}"

mkdir -p "${OUTDIR}"
cd "${OUTDIR}"

# ---------------------------------------------------------------------------
# 1. Coverage of the original mapped BAM against the reference it was mapped to
# ---------------------------------------------------------------------------
echo "[$(date)] Calculating per-contig average coverage"
samtools coverage -o "${SAMPLE}.coverage_summary.txt" "${INPUT_BAM}"

echo "[$(date)] Generating sliding-window (${WINDOW_SIZE} bp) coverage"
samtools view -H "${INPUT_BAM}" \
  | awk -F'\t' '/^@SQ/ {
        chr=""; len="";
        for(i=1;i<=NF;i++){
            if ($i ~ /^SN:/) chr=substr($i,4);
            if ($i ~ /^LN:/) len=substr($i,4)+0;
        }
        print chr"\t"len
    }' > "${SAMPLE}.chrom_sizes.txt"

awk -v w="${WINDOW_SIZE}" 'BEGIN{OFS="\t"} {
        chr=$1; len=$2;
        for (start=0; start<len; start+=w) {
            end = start+w;
            if (end>len) end=len;
            print chr, start, end;
        }
    }' "${SAMPLE}.chrom_sizes.txt" > "${SAMPLE}.windows.bed"

samtools bedcov "${SAMPLE}.windows.bed" "${INPUT_BAM}" > "${SAMPLE}.windows_rawcov.tsv"

awk 'BEGIN{OFS="\t"; print "chrom","start","end","mean_depth"} {
        len = $3-$2;
        mean = (len>0) ? $4/len : 0;
        print $1,$2,$3,mean;
    }' "${SAMPLE}.windows_rawcov.tsv" > "${SAMPLE}.sliding_window_coverage.tsv"

echo "[$(date)] Coverage outputs:"
echo "  Per-contig average: ${OUTDIR}/${SAMPLE}.coverage_summary.txt"
echo "  Sliding window:     ${OUTDIR}/${SAMPLE}.sliding_window_coverage.tsv"

# ---------------------------------------------------------------------------
# 2. Extract mapped read pairs and convert to paired FASTQ
# ---------------------------------------------------------------------------
R1="${OUTDIR}/${SAMPLE}.mapped_R1.fastq.gz"
R2="${OUTDIR}/${SAMPLE}.mapped_R2.fastq.gz"

if [[ -f "${R1}" && -f "${R2}" ]]; then
    echo "[$(date)] Mapped FASTQs already exist, skipping extraction:"
    echo "  R1: ${R1}"
    echo "  R2: ${R2}"
else
    echo "[$(date)] Extracting mapped reads (both mates mapped) from ${INPUT_BAM}"

    # -F 4    : exclude unmapped reads (this read is mapped)
    # -F 8    : exclude reads whose mate is unmapped (mate is mapped)
    # combined -F 12 = drop reads where either this read or its mate is unmapped
    samtools view -@ "${THREADS}" -b -F 12 "${INPUT_BAM}" > "${SAMPLE}.mapped_pairs.bam"

    echo "[$(date)] Name-sorting/collating so mates are adjacent for FASTQ export"
    samtools collate -@ "${THREADS}" -o "${SAMPLE}.mapped_pairs.collated.bam" "${SAMPLE}.mapped_pairs.bam"

    echo "[$(date)] Converting to paired FASTQ"
    # samtools fastq excludes secondary/supplementary alignments by default
    samtools fastq -@ "${THREADS}" \
        -1 "${R1}" \
        -2 "${R2}" \
        -0 /dev/null -s /dev/null -n \
        "${SAMPLE}.mapped_pairs.collated.bam"

    # Remove the collated intermediate; mapped_pairs.bam is kept
    rm -f "${SAMPLE}.mapped_pairs.collated.bam"

    echo "[$(date)] Extraction outputs:"
    echo "  Mapped pairs BAM: ${OUTDIR}/${SAMPLE}.mapped_pairs.bam"
    echo "  R1:               ${R1}"
    echo "  R2:               ${R2}"
fi

# ---------------------------------------------------------------------------
# 3. SPAdes assembly
# ---------------------------------------------------------------------------
if [[ ! -s "${R1}" || ! -s "${R2}" ]]; then
    echo "ERROR: mapped FASTQs missing or empty — read extraction may have failed."
    echo "  Looked for: ${R1}"
    echo "  Looked for: ${R2}"
    exit 1
fi

echo "[$(date)] Running SPAdes assembly"
SPADES_OUT="${OUTDIR}/spades_assembly"
mkdir -p "${SPADES_OUT}"

spades.py \
    -1 "${R1}" \
    -2 "${R2}" \
    -o "${SPADES_OUT}" \
    -t "${THREADS}"

SCAFFOLDS="${SPADES_OUT}/scaffolds.fasta"
echo "[$(date)] SPAdes finished. Scaffolds: ${SCAFFOLDS}"

# ---------------------------------------------------------------------------
# 4. QUAST
# ---------------------------------------------------------------------------
conda activate "${ASSESS_ENV}"

echo "[$(date)] Running QUAST"
QUAST_OUT="${OUTDIR}/quast_output"

if [[ -n "${REFERENCE_FASTA}" ]]; then
    quast.py "${SCAFFOLDS}" -r "${REFERENCE_FASTA}" -o "${QUAST_OUT}" -t "${THREADS}"
else
    quast.py "${SCAFFOLDS}" -o "${QUAST_OUT}" -t "${THREADS}"
fi

echo "[$(date)] QUAST report: ${QUAST_OUT}/report.txt"

# ---------------------------------------------------------------------------
# 5. BUSCO
# ---------------------------------------------------------------------------
echo "[$(date)] Running BUSCO"
busco \
    -i "${SCAFFOLDS}" \
    -o "${SAMPLE}_busco" \
    --out_path "${OUTDIR}" \
    -m genome \
    -l "${BUSCO_LINEAGE}" \
    -c "${THREADS}" \
    -f

echo "[$(date)] BUSCO output: ${OUTDIR}/${SAMPLE}_busco"

echo "[$(date)] All steps complete."
