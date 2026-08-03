#!/usr/bin/env bash
#SBATCH --job-name=mapNstat
#SBATCH --output=mapNstat_%j.out
#SBATCH --error=mapNstat_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=day
#
# NOTE: samples are processed sequentially in a single job, so the walltime
# needs to cover ALL samples - check your partition's limit ('day' above).
#
# Usage:
#   mkdir -p logs
#   sbatch mapNstat.sh -r ref.fasta -s samples.csv -o results -e mapping
#
# The reference is bwa-indexed automatically at the start if the index is
# missing. Per-sample rows are staged in <outdir>/flagstat/parts/ and combined
# into <outdir>/flagstat_summary.tsv at the end of the run; a sample whose row
# already exists is skipped, so an interrupted run can simply be resubmitted
# (use --force to remap everything from scratch).
#
# ---------------------------------------------------------------------------
# Samplesheet format (--samplesheet / -s)
#
#   Plain CSV, three columns, in this order:
#
#     sample,R1,R2
#
#     sample  Unique sample identifier. Used for output filenames, the @RG
#             ID/SM tags, and the 'sample' column of the summary TSV, so keep
#             it free of spaces, commas and '/'.
#     R1      Path to the forward reads  (.fastq or .fastq.gz)
#     R2      Path to the reverse reads  (.fastq or .fastq.gz)
#
#   The header line is optional - a first line beginning with "sample," is
#   skipped. Blank lines and trailing CRs (\r) are ignored. Column order is
#   fixed; there is no name-based lookup. Paths may be absolute or relative to
#   the directory you submit from, and must not themselves contain commas.
#
#   Example (samples.csv):
#
#     sample,R1,R2
#     NHMUK014000001,/data/raw/NHMUK014000001_R1_001.fastq.gz,/data/raw/NHMUK014000001_R2_001.fastq.gz
#     NHMUK014000002,/data/raw/NHMUK014000002_R1_001.fastq.gz,/data/raw/NHMUK014000002_R2_001.fastq.gz
# ---------------------------------------------------------------------------

set -euo pipefail

REFERENCE=""
SAMPLESHEET=""
OUTDIR="results"
CONDA_ENV=""
FORCE=0

usage() {
    cat <<EOF
Usage: $(basename "$0") -r <reference.fasta> -s <samples.csv> [-o <outdir>] [-e <conda_env>] [--force]

  -r  Reference FASTA (bwa-indexed automatically if the index is missing)
  -s  Samplesheet CSV: sample,R1,R2 (see notes at the top of this script)
  -o  Output directory (default: results)-r 	G	
  -e  Conda environment holding bwa and samtools (default: current env)
      --force  Remap samples even if their flagstat row already exists
  -h  This message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reference)   REFERENCE="$2"; shift 2 ;;
        -s|--samplesheet) SAMPLESHEET="$2"; shift 2 ;;
        -o|--outdir)      OUTDIR="$2"; shift 2 ;;
        -e|--env)         CONDA_ENV="$2"; shift 2 ;;
        --force)          FORCE=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "ERROR: unknown argument '$1'" >&2; usage; exit 1 ;;
    esac
done

[[ -n "$REFERENCE" ]]   || { echo "ERROR: -r reference is required" >&2; exit 1; }
[[ -f "$REFERENCE" ]]   || { echo "ERROR: reference not found: $REFERENCE" >&2; exit 1; }
[[ -n "$SAMPLESHEET" ]] || { echo "ERROR: -s samplesheet is required" >&2; exit 1; }
[[ -f "$SAMPLESHEET" ]] || { echo "ERROR: samplesheet not found: $SAMPLESHEET" >&2; exit 1; }

log() { echo "[$(date '+%F %T')] $*"; }

BAM_DIR="${OUTDIR}/bam"
STATS_DIR="${OUTDIR}/flagstat"
PARTS_DIR="${STATS_DIR}/parts"
SUMMARY="${OUTDIR}/flagstat_summary.tsv"
mkdir -p "$BAM_DIR" "$PARTS_DIR"

HEADER=$'sample\ttotal\tprimary\tsecondary\tsupplementary\tduplicates\tmapped\tmapped_pct\tprimary_mapped\tprimary_mapped_pct\tpaired_in_sequencing\tread1\tread2\tproperly_paired\tproperly_paired_pct\twith_itself_and_mate_mapped\tsingletons\tsingletons_pct\tmate_mapped_diff_chr\tmate_mapped_diff_chr_mapq5'

# ------------------------------------------------------------------ conda env
if [[ -n "$CONDA_ENV" ]]; then
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV"
fi
command -v bwa      >/dev/null || { echo "ERROR: bwa not on PATH" >&2; exit 1; }
command -v samtools >/dev/null || { echo "ERROR: samtools not on PATH" >&2; exit 1; }

THREADS="${SLURM_CPUS_PER_TASK:-4}"

# ------------------------------------------------------------- bwa index once
# All five index files must be present and non-empty, otherwise rebuild - this
# also catches a half-written index left behind by a killed job.
index_missing=0
for ext in amb ann bwt pac sa; do
    [[ -s "${REFERENCE}.${ext}" ]] || index_missing=1
done
if [[ "$index_missing" -eq 1 ]]; then
    log "no complete bwa index for ${REFERENCE} - running bwa index"
    bwa index "$REFERENCE"
else
    log "bwa index present for ${REFERENCE}"
fi

# ------------------------------------------------------------- sample loop
map_sample() {
    local sample="$1" r1="$2" r2="$3"
    local bam="${BAM_DIR}/${sample}.sorted.bam"
    local raw_stats="${STATS_DIR}/${sample}.flagstat.tsv"

    [[ -f "$r1" ]] || { echo "ERROR: R1 not found for ${sample}: $r1" >&2; return 1; }
    [[ -f "$r2" ]] || { echo "ERROR: R2 not found for ${sample}: $r2" >&2; return 1; }

    log "${sample}: bwa mem (${THREADS} threads)"
    bwa mem -t "$THREADS" \
            -R "@RG\tID:${sample}\tSM:${sample}\tPL:ILLUMINA" \
            "$REFERENCE" "$r1" "$r2" \
        | samtools sort -@ "$THREADS" -o "$bam" -
    samtools index -@ "$THREADS" "$bam"

    log "${sample}: samtools flagstat"
    samtools flagstat -@ "$THREADS" -O tsv "$bam" > "$raw_stats"

    # Reshape the long flagstat TSV into a single wide row for this sample.
    awk -v sample="$sample" '
        BEGIN { FS = "\t"; OFS = "\t" }
        {
            key = $3
            sub(/ \(QC-passed.*/, "", key)   # "total (QC-passed ...)" -> "total"
            v[key] = $1
        }
        function pct(a, b) { return (b > 0) ? sprintf("%.2f", (a / b) * 100) : "NA" }
        END {
            print sample,
                  v["total"], v["primary"], v["secondary"], v["supplementary"], v["duplicates"],
                  v["mapped"], pct(v["mapped"], v["total"]),
                  v["primary mapped"], pct(v["primary mapped"], v["primary"]),
                  v["paired in sequencing"], v["read1"], v["read2"],
                  v["properly paired"], pct(v["properly paired"], v["paired in sequencing"]),
                  v["with itself and mate mapped"],
                  v["singletons"], pct(v["singletons"], v["paired in sequencing"]),
                  v["with mate mapped to a different chr"],
                  v["with mate mapped to a different chr (mapQ>=5)"]
        }
    ' "$raw_stats" > "${PARTS_DIR}/${sample}.tsv"
}

n_done=0
n_skipped=0
n_failed=0
failed_samples=()

# Strip CRs, drop blank lines and an optional header line before looping.
while IFS=, read -r SAMPLE R1 R2; do
    [[ -n "$SAMPLE" && -n "$R1" && -n "$R2" ]] || {
        echo "WARNING: skipping malformed row: ${SAMPLE},${R1},${R2}" >&2
        n_failed=$((n_failed + 1)); failed_samples+=("${SAMPLE:-<blank>}")
        continue
    }

    if [[ "$FORCE" -eq 0 && -s "${PARTS_DIR}/${SAMPLE}.tsv" ]]; then
        log "${SAMPLE}: already done, skipping (use --force to remap)"
        n_skipped=$((n_skipped + 1))
        continue
    fi

    # Don't let one bad sample abort the whole run.
    if map_sample "$SAMPLE" "$R1" "$R2"; then
        n_done=$((n_done + 1))
        log "${SAMPLE}: done"
    else
        echo "WARNING: ${SAMPLE} failed - continuing" >&2
        rm -f "${PARTS_DIR}/${SAMPLE}.tsv"
        n_failed=$((n_failed + 1)); failed_samples+=("$SAMPLE")
    fi
done < <(sed 's/\r$//' "$SAMPLESHEET" | grep -v '^[[:space:]]*$' | grep -v '^sample,')

# ------------------------------------------------------------------- summary
printf '%s\n' "$HEADER" > "$SUMMARY"
n_rows=0
while IFS=, read -r sample _ _; do
    if [[ -s "${PARTS_DIR}/${sample}.tsv" ]]; then
        cat "${PARTS_DIR}/${sample}.tsv" >> "$SUMMARY"
        n_rows=$((n_rows + 1))
    fi
done < <(sed 's/\r$//' "$SAMPLESHEET" | grep -v '^[[:space:]]*$' | grep -v '^sample,')

log "mapped ${n_done}, skipped ${n_skipped}, failed ${n_failed}"
if [[ "$n_failed" -gt 0 ]]; then
    echo "Failed samples: ${failed_samples[*]}" >&2
fi
log "wrote ${n_rows} rows to ${SUMMARY}"

[[ "$n_failed" -eq 0 ]] || exit 1
