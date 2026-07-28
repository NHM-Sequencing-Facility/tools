#!/bin/bash
#SBATCH --job-name=bases2fastq
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=bases2fastq_%j.out
#SBATCH --error=bases2fastq_%j.err

set -euo pipefail

# ================================
# ACTIVATE ENVIRONMENT
# ================================
source /home/$USER/miniconda3/etc/profile.d/conda.sh

conda activate singularity

# ================================
# >>> EDIT THIS SECTION EACH RUN <<<
# ================================

# Full path to AVITI run folder
INPUT_DIR=""

# Full path to output directory
OUTPUT_DIR=""

# ================================
# FIXED SETTINGS
# ================================

SIF="/home/danip3/bases2fastq_2.3.0.sif"

# ================================
# VALIDATION CHECKS
# ================================

echo "Checking inputs..."

if [ ! -d "$INPUT_DIR" ]; then
  echo "ERROR: INPUT_DIR does not exist: $INPUT_DIR"
  exit 1
fi

if [ ! -f "$SIF" ]; then
  echo "ERROR: SIF file not found: $SIF"
  exit 1
fi

# ================================
# PREPARE PATHS FOR CONTAINER
# ================================

# These are fixed mount points inside the container
MOUNT_INPUT="/mnt1"
MOUNT_OUTPUT="/mnt2"

# Convert full paths to container paths
CONTAINER_INPUT="${INPUT_DIR#/mbl/share}"
CONTAINER_OUTPUT="${OUTPUT_DIR#/hpc/groups}"

# Final container paths
CONTAINER_INPUT="${MOUNT_INPUT}${CONTAINER_INPUT}"
CONTAINER_OUTPUT="${MOUNT_OUTPUT}${CONTAINER_OUTPUT}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# ================================
# LOG INFO
# ================================

echo "Starting bases2fastq"
echo "Input:  $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo "Threads: 8"
echo "------------------------------------"

# ================================
# RUN BASECALLING + DEMULTIPLEXING
# ================================

singularity run \
  --bind /mbl/share:${MOUNT_INPUT},/hpc/groups:${MOUNT_OUTPUT} \
  "$SIF" \
  bases2fastq \
  --num-threads 8 \
  "$CONTAINER_INPUT" \
  "$CONTAINER_OUTPUT"

echo "------------------------------------"
echo "Run complete"
