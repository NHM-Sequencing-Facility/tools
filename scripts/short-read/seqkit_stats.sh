#!/bin/bash
#SBATCH --job-name=seqkit_stats
#SBATCH --output=seqkit_stats_%j.out
#SBATCH --error=seqkit_stats_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=medium

# =============================================================================
# seqkit_stats.sh
# Run seqkit stats on one or more FASTQ or FASTA files.
#
# Usage:
#   sbatch seqkit_stats.sh [-l <list.txt>] <input_path> <output_dir>
#   bash   seqkit_stats.sh [-l <list.txt>] <input_path> <output_dir>
#
# Options:
#   -l <list.txt>    Plain-text file of strings, one per line. Only files whose
#                    *basename* contains one of these strings are processed.
#                    Matching is case-sensitive substring matching, and strings
#                    are treated literally (no globbing). Blank lines and lines
#                    beginning with '#' are ignored, as is surrounding
#                    whitespace and trailing carriage returns.
#                    Requires <input_path> to be a directory.
#                    Strings matching no files raise a warning; the run
#                    continues with whatever did match.
#   -h               Show this help text and exit.
#
# Arguments:
#   $1  input_path   Path to a single FASTQ/FASTA file, OR a directory
#                    containing FASTQ and/or FASTA files (searched recursively).
#                    Supported extensions: .fastq, .fastq.gz, .fq, .fq.gz,
#                                         .fasta, .fasta.gz, .fa, .fa.gz
#   $2  output_dir   Directory to write results into (created if absent).
#
# Outputs (written to <output_dir>/):
#   seqkit_stats.tsv          Full seqkit stats table (TSV, all metrics).
#   seqkit_stats_summary.txt  Human-readable run summary.
#
# Examples:
#   # Everything under a directory
#   bash seqkit_stats.sh /data/run3588/fastq results/
#
#   # Only the samples named in samples.txt
#   bash seqkit_stats.sh -l samples.txt /data/run3588/fastq results/
# =============================================================================

set -euo pipefail

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate read_qc

usage() {
    sed -n '10,50p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# 1. Option parsing & argument validation
# ---------------------------------------------------------------------------
LIST_FILE=""

while getopts ":l:h" opt; do
    case "${opt}" in
        l) LIST_FILE="${OPTARG}" ;;
        h) usage; exit 0 ;;
        :) echo "[ERROR] Option -${OPTARG} requires an argument." >&2; exit 1 ;;
        \?) echo "[ERROR] Unknown option: -${OPTARG}" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -lt 2 ]]; then
    echo "[ERROR] Usage: $(basename "$0") [-l <list.txt>] <input_path> <output_dir>" >&2
    exit 1
fi

INPUT_PATH="${1}"
OUTPUT_DIR="${2}"

if [[ ! -e "${INPUT_PATH}" ]]; then
    echo "[ERROR] Input path does not exist: ${INPUT_PATH}" >&2
    exit 1
fi

if [[ -n "${LIST_FILE}" ]]; then
    if [[ ! -f "${LIST_FILE}" ]]; then
        echo "[ERROR] List file does not exist or is not a regular file: ${LIST_FILE}" >&2
        exit 1
    fi
    if [[ ! -d "${INPUT_PATH}" ]]; then
        echo "[ERROR] -l requires <input_path> to be a directory (got: ${INPUT_PATH})" >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 2. Build file list
# ---------------------------------------------------------------------------
declare -a FASTQ_FILES=()
declare -a MATCH_REPORT=()      # "<pattern>\t<n_files>" lines, for the summary
declare -a UNMATCHED=()

if [[ -f "${INPUT_PATH}" ]]; then
    # Single file supplied — validate extension
    if [[ "${INPUT_PATH}" =~ \.(fastq|fastq\.gz|fq|fq\.gz|fasta|fasta\.gz|fa|fa\.gz)$ ]]; then
        FASTQ_FILES=("${INPUT_PATH}")
    else
        echo "[ERROR] File does not appear to be a FASTQ or FASTA: ${INPUT_PATH}" >&2
        exit 1
    fi
elif [[ -d "${INPUT_PATH}" ]]; then
    # Directory supplied — find all FASTQ/FASTA files recursively
    declare -a ALL_FILES=()
    mapfile -t ALL_FILES < <(
        find "${INPUT_PATH}" -type f \
            \( -name "*.fastq"    -o -name "*.fastq.gz" \
               -o -name "*.fq"    -o -name "*.fq.gz"    \
               -o -name "*.fasta" -o -name "*.fasta.gz" \
               -o -name "*.fa"    -o -name "*.fa.gz"    \) \
        | sort
    )

    if [[ -z "${LIST_FILE}" ]]; then
        FASTQ_FILES=("${ALL_FILES[@]}")
    else
        # ---- Filter mode: keep only files matching a string from LIST_FILE ----
        declare -a PATTERNS=()
        while IFS= read -r line || [[ -n "${line}" ]]; do
            line="${line%$'\r'}"                       # strip CRLF line endings
            line="${line#"${line%%[![:space:]]*}"}"    # strip leading whitespace
            line="${line%"${line##*[![:space:]]}"}"    # strip trailing whitespace
            [[ -z "${line}" ]] && continue             # skip blank lines
            [[ "${line}" == \#* ]] && continue         # skip comments
            PATTERNS+=("${line}")
        done < "${LIST_FILE}"

        if [[ ${#PATTERNS[@]} -eq 0 ]]; then
            echo "[ERROR] List file contains no usable strings: ${LIST_FILE}" >&2
            exit 1
        fi

        declare -A KEEP=()
        for pat in "${PATTERNS[@]}"; do
            n_hits=0
            for f in "${ALL_FILES[@]}"; do
                base="$(basename "${f}")"
                if [[ "${base}" == *"${pat}"* ]]; then
                    KEEP["${f}"]=1
                    n_hits=$((n_hits + 1))
                fi
            done
            MATCH_REPORT+=("$(printf '%s\t%d' "${pat}" "${n_hits}")")
            if [[ ${n_hits} -eq 0 ]]; then
                echo "[WARN] No files matched string: '${pat}'" >&2
                UNMATCHED+=("${pat}")
            fi
        done

        # Rebuild in the original sorted order, de-duplicated
        for f in "${ALL_FILES[@]}"; do
            if [[ -n "${KEEP[${f}]:-}" ]]; then
                FASTQ_FILES+=("${f}")
            fi
        done
    fi
else
    echo "[ERROR] Input path is neither a file nor a directory: ${INPUT_PATH}" >&2
    exit 1
fi

if [[ ${#FASTQ_FILES[@]} -eq 0 ]]; then
    if [[ -n "${LIST_FILE}" ]]; then
        echo "[ERROR] No FASTQ or FASTA files under '${INPUT_PATH}' matched any string in '${LIST_FILE}'." >&2
    else
        echo "[ERROR] No FASTQ or FASTA files found under: ${INPUT_PATH}" >&2
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Prepare output directory (and SLURM log directory)
# ---------------------------------------------------------------------------
mkdir -p "${OUTPUT_DIR}"
mkdir -p logs   # for SLURM stdout/stderr; harmless if running interactively

OUTPUT_TSV="${OUTPUT_DIR}/seqkit_stats.tsv"
OUTPUT_SUMMARY="${OUTPUT_DIR}/seqkit_stats_summary.txt"

# ---------------------------------------------------------------------------
# 4. Environment loading & validation
# ---------------------------------------------------------------------------
# Verify seqkit is available
if ! command -v seqkit &>/dev/null; then
    echo "[ERROR] seqkit not found on PATH. Load the appropriate module or activate conda env." >&2
    exit 1
fi

SEQKIT_VERSION=$(seqkit version 2>&1 | head -1)
THREADS="${SLURM_CPUS_PER_TASK:-8}"

# ---------------------------------------------------------------------------
# 5. Log run info
# ---------------------------------------------------------------------------
echo "============================================================"
echo "  seqkit stats run"
echo "============================================================"
echo "  Script       : $0"
echo "  Input path   : ${INPUT_PATH}"
echo "  List file    : ${LIST_FILE:-N/A (no filtering)}"
echo "  Output dir   : ${OUTPUT_DIR}"
echo "  Files found  : ${#FASTQ_FILES[@]}"
echo "  Threads      : ${THREADS}"
echo "  seqkit       : ${SEQKIT_VERSION}"
echo "  Start time   : $(date '+%Y-%m-%d %H:%M:%S')"
echo "  SLURM job ID : ${SLURM_JOB_ID:-N/A (interactive)}"
echo "============================================================"
echo ""

if [[ -n "${LIST_FILE}" ]]; then
    echo "--- String match counts ---"
    printf '  %s\n' "${MATCH_REPORT[@]}" | column -t -s $'\t'
    if [[ ${#UNMATCHED[@]} -gt 0 ]]; then
        echo ""
        echo "  [WARN] ${#UNMATCHED[@]} string(s) matched no files: ${UNMATCHED[*]}"
    fi
    echo ""
fi

printf '  %s\n' "${FASTQ_FILES[@]}"
echo ""

# ---------------------------------------------------------------------------
# 6. Run seqkit stats
# ---------------------------------------------------------------------------
# Flags:
#   -a / --all        Include all metrics: GC%, N50, Q20/Q30 for FASTQ, etc.
#   -T / --tabular    TSV output (machine-friendly)
#   -j THREADS        Parallel threads
#   -e / --skip-err   Skip files with read errors rather than aborting
#   -b / --basename   Store only the filename in the 'file' column

echo "[INFO] Running seqkit stats..."

seqkit stats \
    --all \
    --tabular \
    --threads "${THREADS}" \
    --skip-err \
    "${FASTQ_FILES[@]}" \
    > "${OUTPUT_TSV}"

echo "[INFO] Stats written to: ${OUTPUT_TSV}"

# ---------------------------------------------------------------------------
# 7. Write human-readable summary
# ---------------------------------------------------------------------------
{
    echo "seqkit stats summary"
    echo "Run date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Input path : ${INPUT_PATH}"
    echo "List file  : ${LIST_FILE:-N/A (no filtering)}"
    echo "seqkit     : ${SEQKIT_VERSION}"
    echo "Files      : ${#FASTQ_FILES[@]}"
    echo ""
    if [[ -n "${LIST_FILE}" ]]; then
        echo "String match counts:"
        printf '  %s\n' "${MATCH_REPORT[@]}" | column -t -s $'\t'
        if [[ ${#UNMATCHED[@]} -gt 0 ]]; then
            echo ""
            echo "WARNING: the following string(s) matched no files:"
            printf '  %s\n' "${UNMATCHED[@]}"
        fi
        echo ""
    fi
    # Pretty-print the TSV with column alignment
    column -t -s $'\t' "${OUTPUT_TSV}"
} > "${OUTPUT_SUMMARY}"

echo "[INFO] Summary written to: ${OUTPUT_SUMMARY}"

# ---------------------------------------------------------------------------
# 8. Quick console preview
# ---------------------------------------------------------------------------
echo ""
echo "--- Preview (first 5 data rows) ---"
head -6 "${OUTPUT_TSV}" | column -t -s $'\t'
echo ""

echo "============================================================"
echo "  Finished : $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
