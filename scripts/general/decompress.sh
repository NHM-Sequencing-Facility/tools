#!/bin/bash
#SBATCH --job-name=decompress
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Exit on error
set -euo pipefail

# Activate env containing Pigz
conda activate archive

# Set input archive (.tar.gz) to decompress
# MUST supply absolute path, not relative
export INPUT_ARCHIVE="path/to/archive.tar.gz"

# Determine intermediate .tar
export INT_TAR="${INPUT_ARCHIVE%.gz}"

# Decompress using pigz with 8 threads
pigz -p 8 -dk "$INPUT_ARCHIVE"  # -d to decompress, -k to keep the original .tar.gz

# Extract using tar
tar -xvf "$INT_TAR" -C "${INPUT_ARCHIVE%/*}"

# Remove the intermediate .tar file
rm "$INT_TAR"
