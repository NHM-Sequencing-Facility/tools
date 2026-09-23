# Long reads

Scripts for processing long-read sequencing data produced by Oxford Nanopore Technologies (ONT) sequencers. Each script includes usage instructions in the header comments.

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
