#!/bin/bash
#SBATCH --job-name=bases2fastq-
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --output=bases2fastq_%x_%j.out
#SBATCH --error=bases2fastq_%x_%j.err

# ============================================================================
# USAGE
# ============================================================================
#   sbatch run_bases2fastq.sh                          # manifest auto-detected
#   sbatch run_bases2fastq.sh /path/to/manifest.csv    # manifest supplied
#
# If no manifest path is given, bases2fastq falls back to its own detection of
# the run manifest inside the AVITI run folder.
# ============================================================================

set -euo pipefail

# ================================
# ACTIVATE ENVIRONMENT
# ================================
source /home/$USER/miniconda3/etc/profile.d/conda.sh
conda activate singularity

# ================================
# >>> EDIT THIS SECTION EACH RUN <<<
# ================================
# Full path to AVITI run folder (must be under /mbl/share)
INPUT_DIR="/mbl/share/instruments/aviti/..."

# Full path to output directory (must be under /hpc/groups)
OUTPUT_DIR="/hpc/groups/mbl-group/silvia-data/ANALYSED_RUNS/..._ANALYSED"

# ================================
# FIXED SETTINGS (DO NOT EDIT)
# Assumes .sif is in /home
# ================================
SIF="/home/$USER/bases2fastq_2.3.0.sif"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

# Optional run manifest, taken from the first command-line argument.
# Empty => auto-detection by bases2fastq.
MANIFEST="${1:-}"

# Host directories bound into the container
HOST_INPUT_ROOT="/mbl/share"
HOST_OUTPUT_ROOT="/hpc/groups"

# Fixed mount points inside the container
MOUNT_INPUT="/mnt1"
MOUNT_OUTPUT="/mnt2"
CONTAINER_MANIFEST="/tmp/run_manifest.csv"

# ================================
# VALIDATION CHECKS (HOST SIDE)
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

if [ -n "$MANIFEST" ]; then
  if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: MANIFEST file not found: $MANIFEST"
    exit 1
  fi
  # singularity --bind requires an absolute host path.
  MANIFEST="$(readlink -f "$MANIFEST")"
fi

# ================================
# PREPARE PATHS FOR CONTAINER
# ================================
# Strip host roots and prepend container mount points.
CONTAINER_INPUT="${MOUNT_INPUT}${INPUT_DIR#"$HOST_INPUT_ROOT"}"
CONTAINER_OUTPUT="${MOUNT_OUTPUT}${OUTPUT_DIR#"$HOST_OUTPUT_ROOT"}"

# Guards: ${VAR#prefix} silently returns VAR unchanged if the prefix does not
# match, which would produce a bogus container path (e.g. /mnt2/hpc/scratch/...).
# Fail loudly here rather than inside the container.
if [ "${INPUT_DIR#"$HOST_INPUT_ROOT"}" = "$INPUT_DIR" ]; then
  echo "ERROR: INPUT_DIR is not under $HOST_INPUT_ROOT: $INPUT_DIR"
  exit 1
fi

if [ "${OUTPUT_DIR#"$HOST_OUTPUT_ROOT"}" = "$OUTPUT_DIR" ]; then
  echo "ERROR: OUTPUT_DIR is not under $HOST_OUTPUT_ROOT: $OUTPUT_DIR"
  exit 1
fi

# The manifest is bind-mounted as a single file to a fixed container path, so it
# does not need to live under either bound root.

# Refuse to write into a directory that already contains results. bases2fastq
# may partially overwrite rather than fail, which is hard to spot afterwards.
if [ -d "$OUTPUT_DIR" ] && [ -n "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]; then
  echo "ERROR: OUTPUT_DIR exists and is not empty: $OUTPUT_DIR"
  echo "       Remove it or choose a new path before re-running."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ================================
# BUILD COMMAND
# ================================
BIND_ARGS=(
  --bind "${HOST_INPUT_ROOT}:${MOUNT_INPUT}"
  --bind "${HOST_OUTPUT_ROOT}:${MOUNT_OUTPUT}"
)

B2F_ARGS=( --num-threads "$THREADS" )

if [ -n "$MANIFEST" ]; then
  BIND_ARGS+=( --bind "${MANIFEST}:${CONTAINER_MANIFEST}" )
  B2F_ARGS+=( --run-manifest "$CONTAINER_MANIFEST" )
fi

# ================================
# LOG INFO
# ================================
echo "Starting bases2fastq"
echo "Input:              $INPUT_DIR"
echo "Output:             $OUTPUT_DIR"
if [ -n "$MANIFEST" ]; then
  echo "Manifest:           $MANIFEST"
  echo "Container manifest: $CONTAINER_MANIFEST"
else
  echo "Manifest:           (none supplied - auto-detected by bases2fastq)"
fi
echo "Container input:    $CONTAINER_INPUT"
echo "Container output:   $CONTAINER_OUTPUT"
echo "Threads:            $THREADS"
echo "Container image:    $SIF"
echo "------------------------------------"

# ================================
# RUN BASECALLING + DEMULTIPLEXING
# ================================
rc=0
singularity run \
  "${BIND_ARGS[@]}" \
  "$SIF" \
  bases2fastq \
  "${B2F_ARGS[@]}" \
  "$CONTAINER_INPUT" \
  "$CONTAINER_OUTPUT" || rc=$?

echo "------------------------------------"
if [ "$rc" -ne 0 ]; then
  echo "ERROR: bases2fastq failed with exit code $rc"
  exit "$rc"
fi
echo "Run complete"
