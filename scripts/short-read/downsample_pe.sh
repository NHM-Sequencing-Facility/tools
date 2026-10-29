#!/bin/bash
#SBATCH --job-name=downsample_pe
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=[PLACEHOLDER]       # set to a partition on your cluster
#SBATCH --output=slurm-%x-%j.out
#SBATCH --error=slurm-%x-%j.err

# Downsample raw paired-end reads with BBTools reformat.sh
#
# Usage:
#   sbatch downsample_pe.sh <sample> <R1.fastq.gz> <R2.fastq.gz> <output_dir> [max_reads] [seed]
#
#   max_reads  number of read PAIRS to keep (default: 100000)
#   seed       random seed for reproducible subsampling (default: 12345)
#
# Requirements:
#   - A conda environment containing BBTools (reformat.sh). Set CONDA_ENV
#     below, or override at submission: CONDA_ENV=myenv sbatch downsample_pe.sh ...
#
# Outputs (uncompressed FASTQ; existing files are overwritten):
#   <output_dir>/<sample>/<sample>_R1_downsampled.fastq
#   <output_dir>/<sample>/<sample>_R2_downsampled.fastq
#   <output_dir>/logs/downsample/<sample>.{out,err}

set -euo pipefail

# ------- configuration
CONDA_ENV="${CONDA_ENV:-[PLACEHOLDER]}"   # conda env containing BBTools

SAMPLE="${1:-}"
R1_IN="${2:-}"
R2_IN="${3:-}"
OUTPUT_DIR="${4:-}"
MAX_READS="${5:-100000}"             # read PAIRS
SAMPLE_SEED="${6:-12345}"

if [[ -z "${SAMPLE}" || -z "${R1_IN}" || -z "${R2_IN}" || -z "${OUTPUT_DIR}" ]]; then
    echo "ERROR: missing arguments." >&2
    echo "Usage: sbatch $0 <sample> <R1> <R2> <output_dir> [max_reads] [seed]" >&2
    exit 1
fi

# ------- paths
R1_OUT="${OUTPUT_DIR}/${SAMPLE}/${SAMPLE}_R1_downsampled.fastq"
R2_OUT="${OUTPUT_DIR}/${SAMPLE}/${SAMPLE}_R2_downsampled.fastq"
LOG_DIR="${OUTPUT_DIR}/logs/downsample"
LOG_OUT="${LOG_DIR}/${SAMPLE}.out"
LOG_ERR="${LOG_DIR}/${SAMPLE}.err"

mkdir -p "${LOG_DIR}" "${OUTPUT_DIR}/${SAMPLE}"
: > "${LOG_OUT}"    # start a fresh log on each run

# Write key messages to both the per-sample log and the SLURM output files
log()  { echo "$*" | tee -a "${LOG_OUT}"; }
warn() { echo "WARNING: $*" | tee -a "${LOG_OUT}" >&2; }
die()  { echo "ERROR: $*" | tee -a "${LOG_OUT}" >&2; exit 1; }

# ------- software setup
if ! command -v conda > /dev/null 2>&1; then
    die "conda not found on PATH. Load or install conda before submitting."
fi
eval "$(conda shell.bash hook)"
set +u    # conda activate scripts can reference unset variables
conda activate "${CONDA_ENV}" || { set -u; die "could not activate conda env '${CONDA_ENV}'."; }
set -u

if ! command -v reformat.sh > /dev/null 2>&1; then
    die "reformat.sh not found in conda env '${CONDA_ENV}'. Install BBTools (e.g. conda install -c bioconda bbmap)."
fi

# ------- memory for JVM
# derive from SLURM's allocation (--mem sets SLURM_MEM_PER_NODE,
# --mem-per-cpu sets SLURM_MEM_PER_CPU); fall back to 8000 MB outside SLURM.
if [[ -n "${SLURM_MEM_PER_NODE:-}" ]]; then
    MEM_MB="${SLURM_MEM_PER_NODE}"
elif [[ -n "${SLURM_MEM_PER_CPU:-}" ]]; then
    MEM_MB=$(( SLURM_MEM_PER_CPU * ${SLURM_CPUS_PER_TASK:-1} ))
else
    MEM_MB=8000
fi
XMX_MB=$(( MEM_MB * 80 / 100 ))

# ------- run
log "Downsampling raw paired-end reads for ${SAMPLE}"
log "Started: $(date)"
log "Conda env: ${CONDA_ENV}"
log "R1 in: ${R1_IN}"
log "R2 in: ${R2_IN}"
log "Target read pairs: ${MAX_READS}"
log "Seed: ${SAMPLE_SEED}"
log "JVM heap: ${XMX_MB}m of ${MEM_MB}m allocated"

# Check if either input file is empty or missing
if [ ! -s "${R1_IN}" ] || [ ! -s "${R2_IN}" ]; then
    warn "one or both input files are empty or missing for ${SAMPLE} - creating empty placeholder outputs"
    : > "${R1_OUT}"
    : > "${R2_OUT}"
    log "Placeholder outputs created: $(date)"
    exit 0
fi

reformat.sh -Xmx${XMX_MB}m -eoom \
            in1="${R1_IN}" \
            in2="${R2_IN}" \
            out1="${R1_OUT}" \
            out2="${R2_OUT}" \
            samplereadstarget="${MAX_READS}" \
            sampleseed="${SAMPLE_SEED}" \
            overwrite=t \
            >> "${LOG_OUT}" 2>> "${LOG_ERR}" \
    || die "reformat.sh failed for ${SAMPLE}; see ${LOG_ERR}"

log "Completed: $(date)"
log "R1 output size: $(numfmt --to=iec "$(stat -c%s "${R1_OUT}")")"
log "R2 output size: $(numfmt --to=iec "$(stat -c%s "${R2_OUT}")")"
