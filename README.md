# tools
Collection of tools and scripts for a range of bioinformatics tasks.




## short-read

### seqkit_stats.sh
```
Calculate simple summary stats for a collection of N .fastq/.fastq.gz files.

Usage:
  sbatch seqkit_stats.sh <input_path> <output_dir>
  bash   seqkit_stats.sh <input_path> <output_dir>

Arguments:
  $1  input_path   Path to a single .fastq/.fastq.gz file, OR a directory
                   containing .fastq and/or .fastq.gz files (searched recursively).
  $2  output_dir   Directory to write results into (created if absent).

Outputs (written to <output_dir>/):
  seqkit_stats.tsv          Full seqkit stats table (TSV, all metrics).
  seqkit_stats_summary.txt  Human-readable run summary.

Requirements: seqkit installed in conda environment
```
