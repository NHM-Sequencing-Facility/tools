#!/bin/bash
#SBATCH --job-name=nanoplot
#SBATCH --cpus-per-task=16
#SBATCH --mem=8G
#SBATCH --output=%x_%j.log
#SBATCH --error=%x_%j.err

# =============================================================================
# nanoplot.sh
# Run NanoPlot on one or more ONT FASTQ files.
#
# Usage:
#   sbatch nanoplot.sh <input_path> [output_root]
#   bash   nanoplot.sh <input_path> [output_root]
#
# Arguments:
#   $1  input_path    Path to a single .fastq/.fastq.gz file, OR a directory
#                     to search recursively for .fastq / .fastq.gz files.
#   $2  output_root   (Optional) Root directory under which per-sample output
#                     subdirs are created. Defaults to alongside each input file.
#
# Output structure (one subdir per file):
#   <output_root>/<sample_name>_nanoplot/
#       NanoPlot-report.html
#       NanoStats.txt
#       NanoStats.tsv          (--tsv_stats)
#       NanoPlot-data.tsv.gz   (--store)
#       *.pdf                  (--format pdf)
# =============================================================================

set -uo pipefail   # -e intentionally omitted: per-file errors handled manually

THREADS="${SLURM_CPUS_PER_TASK:-24}"

# ---------------------------------------------------------------------------
# 1. Argument validation
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    echo "[ERROR] Usage: $(basename "$0") <input_path> [output_root]" >&2
    exit 1
fi

INPUT_PATH="${1}"
OUTPUT_ROOT="${2:-}"   # empty = place output alongside each input file

if [[ ! -e "${INPUT_PATH}" ]]; then
    echo "[ERROR] Input path does not exist: ${INPUT_PATH}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Build file list
# ---------------------------------------------------------------------------
declare -a FASTQ_FILES

if [[ -f "${INPUT_PATH}" ]]; then
    if [[ "${INPUT_PATH}" =~ \.(fastq|fastq\.gz|fq|fq\.gz)$ ]]; then
        FASTQ_FILES=("${INPUT_PATH}")
    else
        echo "[ERROR] File does not appear to be a FASTQ: ${INPUT_PATH}" >&2
        exit 1
    fi
elif [[ -d "${INPUT_PATH}" ]]; then
    mapfile -t FASTQ_FILES < <(
        find "${INPUT_PATH}" -type f \
            \( -name "*.fastq" -o -name "*.fastq.gz" \
               -o -name "*.fq"    -o -name "*.fq.gz"    \) \
        | sort
    )
else
    echo "[ERROR] Input path is neither a file nor a directory: ${INPUT_PATH}" >&2
    exit 1
fi

if [[ ${#FASTQ_FILES[@]} -eq 0 ]]; then
    echo "[ERROR] No .fastq / .fastq.gz files found under: ${INPUT_PATH}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Conda environment
# ---------------------------------------------------------------------------
# Initialise conda for non-interactive shells, then activate the environment.
CONDA_BASE="$(conda info --base 2>/dev/null)" || {
    echo "[ERROR] conda not found on PATH. Load the appropriate module first." >&2
    exit 1
}
# shellcheck source=/dev/null
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate nanoplot

if ! command -v NanoPlot &>/dev/null; then
    echo "[ERROR] NanoPlot not found after activating conda env 'nanoplot'." >&2
    exit 1
fi

NANOPLOT_VERSION=$(NanoPlot --version 2>&1 | head -1)

# ---------------------------------------------------------------------------
# 4. Run summary header
# ---------------------------------------------------------------------------
echo "============================================================"
echo "  NanoPlot batch run"
echo "============================================================"
echo "  Script        : $0"
echo "  Input path    : ${INPUT_PATH}"
echo "  Output root   : ${OUTPUT_ROOT:-<alongside each input file>}"
echo "  Files found   : ${#FASTQ_FILES[@]}"
echo "  Threads       : ${THREADS}"
echo "  NanoPlot      : ${NANOPLOT_VERSION}"
echo "  Start time    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "  SLURM job ID  : ${SLURM_JOB_ID:-N/A (interactive)}"
echo "============================================================"
printf '  %s\n' "${FASTQ_FILES[@]}"
echo ""

# ---------------------------------------------------------------------------
# 5. Process each file
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
FAIL_LIST=()

for infile in "${FASTQ_FILES[@]}"; do

    # -- Derive sample name (strip .fastq, .fq, .gz suffixes) ---------------
    base=$(basename "${infile}")
    sample="${base%.gz}"
    sample="${sample%.fastq}"
    sample="${sample%.fq}"

    # -- Resolve output directory --------------------------------------------
    if [[ -n "${OUTPUT_ROOT}" ]]; then
        outdir="${OUTPUT_ROOT}/${sample}_nanoplot"
    else
        outdir="$(dirname "${infile}")/${sample}_nanoplot"
    fi

    mkdir -p "${outdir}"

    echo "------------------------------------------------------------"
    echo "  [$(( PASS + FAIL + 1 ))/${#FASTQ_FILES[@]}] ${sample}"
    echo "  Input  : ${infile}"
    echo "  Output : ${outdir}"
    echo "  Time   : $(date '+%H:%M:%S')"
    echo "------------------------------------------------------------"

    # -- Run NanoPlot --------------------------------------------------------
    NanoPlot \
        --threads "${THREADS}" \
        --huge \
        --info_in_report \
        --tsv_stats \
        --store \
        --loglength \
        --N50 \
        --format pdf \
        --fastq "${infile}" \
        --outdir "${outdir}"

    exit_code=$?

    if [[ ${exit_code} -eq 0 ]]; then
        echo "  [OK] ${sample}"
        (( PASS++ )) || true
    else
        echo "  [FAILED] ${sample} (exit code ${exit_code})" >&2
        FAIL_LIST+=("${infile}")
        (( FAIL++ )) || true
    fi

    echo ""
done

# ---------------------------------------------------------------------------
# 6. Final summary
# ---------------------------------------------------------------------------
echo "============================================================"
echo "  Run complete : $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Passed       : ${PASS} / ${#FASTQ_FILES[@]}"
echo "  Failed       : ${FAIL} / ${#FASTQ_FILES[@]}"
if [[ ${FAIL} -gt 0 ]]; then
    echo ""
    echo "  Failed files:"
    printf '    %s\n' "${FAIL_LIST[@]}"
fi
echo "============================================================"

# Exit non-zero if any file failed
[[ ${FAIL} -eq 0 ]]
