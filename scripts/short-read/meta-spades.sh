#!/bin/bash
#SBATCH --job-name=meta-spades
#SBATCH --output=meta-spades_%j.out
#SBATCH --error=meta-spades_%j.err
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --partition=medium

: '
meta-spades.sh
===========================
Runs SPAdes in metagenomic mode (--meta) on paired-end reads.

Usage:
    sbatch meta-spades.sh <R1> <R2> <OUTPUT_DIR>

Arguments:
    R1            Path to forward (R1) FASTQ file
    R2            Path to reverse (R2) FASTQ file
    OUTPUT_DIR    Directory to write SPAdes output into. Will be created
                  if it does not already exist.

SLURM:
    --cpus-per-task is passed directly to SPAdes --threads.
    Adjust --mem as needed depending on input size.

Dependencies:
    Conda environment: <CONDA_ENV_NAME>  (must contain SPAdes >4.2.0)

Example:
    sbatch meta-spades.sh \
        UK006_1.fastq \
        UK006_2.fastq \
        spades_out/UK006
'

# ── Conda ──────────────────────────────────────────────────────────────────────
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate assembly

# ── Arguments ──────────────────────────────────────────────────────────────────
R1="${1:?ERROR: R1 path not provided. Usage: sbatch $0 <R1> <R2> <OUTPUT_DIR>}"
R2="${2:?ERROR: R2 path not provided. Usage: sbatch $0 <R1> <R2> <OUTPUT_DIR>}"
OUTPUT_DIR="${3:?ERROR: Output directory not provided. Usage: sbatch $0 <R1> <R2> <OUTPUT_DIR>}"

# ── Validate inputs ────────────────────────────────────────────────────────────
[[ -f "${R1}" ]] || { echo "ERROR: R1 file not found: ${R1}"; exit 1; }
[[ -f "${R2}" ]] || { echo "ERROR: R2 file not found: ${R2}"; exit 1; }

mkdir -p "${OUTPUT_DIR}"
mkdir -p logs

# ── Threads from SLURM ─────────────────────────────────────────────────────────
THREADS="${SLURM_CPUS_PER_TASK:-16}"

# ── Run ────────────────────────────────────────────────────────────────────────
echo "========================================"
echo "SPAdes metagenomic assembly"
echo "  R1:         ${R1}"
echo "  R2:         ${R2}"
echo "  Output:     ${OUTPUT_DIR}"
echo "  Threads:    ${THREADS}"
echo "  Started:    $(date)"
echo "========================================"

spades.py \
    --meta \
    -k 21,33,55 \
    -1 "${R1}" \
    -2 "${R2}" \
    -o "${OUTPUT_DIR}" \
    --threads "${THREADS}"

EXIT_CODE=$?

echo "========================================"
echo "  Finished:   $(date)"
echo "  Exit code:  ${EXIT_CODE}"
echo "========================================"

exit ${EXIT_CODE}
