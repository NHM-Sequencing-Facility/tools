# tools
Collection of tools and scripts for a range of bioinformatics tasks.




## short-read

### seqkit_stats.sh
```
Calculate simple summary stats for a collection of .fasta/.fastq/.fastq.gz files.

Usage:
  sbatch seqkit_stats.sh <input_path> <output_dir>
  bash   seqkit_stats.sh <input_path> <output_dir>

Arguments:
  $1  input_path   Path to a single FASTQ/FASTA file, OR a directory
                   containing FASTQ and/or FASTA files (searched recursively).
                   Supported extensions: .fastq, .fastq.gz, .fq, .fq.gz,
                                        .fasta, .fasta.gz, .fa, .fa.gz
  $2  output_dir   Directory to write results into (created if absent).

Outputs (written to <output_dir>/):
  seqkit_stats.tsv          Full seqkit stats table (TSV, all metrics).
  seqkit_stats_summary.txt  Human-readable run summary.

Requirements: seqkit installed in conda environment
```

### meta-spades.sh
```
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
```

## long-read

### nanoplot.sh
```
Run NanoPlot on one or more ONT FASTQ files.

Usage:
  sbatch nanoplot.sh <input_path> [output_root]
  bash   nanoplot.sh <input_path> [output_root]

Arguments:
  $1  input_path    Path to a single .fastq/.fastq.gz file, OR a directory
                    to search recursively for .fastq / .fastq.gz files.
  $2  output_root   (Optional) Root directory under which per-sample output
                    subdirs are created. Defaults to alongside each input file.

Output structure (one subdir per file):
  <output_root>/<sample_name>_nanoplot/
      NanoPlot-report.html
      NanoStats.txt
      NanoStats.tsv          (--tsv_stats)
      NanoPlot-data.tsv.gz   (--store)
      *.pdf                  (--format pdf)
```
