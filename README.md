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

### bases2fastq.slurm
```
Runs ElementBioscience's Bases2Fastq tool to basecall and demultiplex AVITI24 sequence data generated at the NHM.
Can accept an optional external RunManifest.csv file, or fall back to bases2fastq's own auto-detection of the
manifest inside the run folder.

Usage:
    sbatch bases2fastq.slurm                          # manifest auto-detected
    sbatch bases2fastq.slurm /path/to/manifest.csv    # manifest supplied

Arguments:
    MANIFEST (optional): Path to an external run manifest CSV, given as the first command-line
        argument. May live anywhere readable; it is bind-mounted into the container as a single
        file. If omitted, no --run-manifest flag is passed and bases2fastq auto-detects.
    INPUT_DIR: Input directory path to raw AVITI24 sequencing run output. Must be under /mbl/share.
    OUTPUT_DIR: Path to desired output directory. Must be under /hpc/groups, and must not already
        exist as a non-empty directory.
    Both required paths are set within the script itself.

SLURM:
    --cpus-per-task is passed directly to bases2fastq --num-threads.
    Adjust --mem as needed depending on input size.

Behaviour notes:
    /mbl/share and /hpc/groups are bind-mounted into the container at /mnt1 and /mnt2 respectively,
    and INPUT_DIR/OUTPUT_DIR are rewritten to the corresponding container paths. The script exits
    with an error if either path falls outside its expected root.
    The script refuses to run if OUTPUT_DIR already exists and is non-empty, since bases2fastq may
    partially overwrite existing results rather than failing.
    The bases2fastq exit code is captured and propagated; "Run complete" is only printed on success.

Dependencies:
    Conda env (called 'singularity' by default) with singularity installed.
    bases2fastq_[VERSION].sif (see below). The path is set via the SIF variable in the script.

Set up:
    Since ElemBio only provides a Docker container and a static binary version of bases2fastq,
    both of which cannot be installed/run on the HPC cluster without admin rights, using her computer,
    Silvia converted the Docker container into a Singularity image,
    renamed it using the software version for accountability, and finally moved the image to the HPC cluster:

    conda activate singularity
    singularity pull docker://elembio/bases2fastq
    singularity exec bases2fastq_latest.sif bases2fastq --version
    # bases2fastq version 2.2.1.2035424704, use subject to license available at elementbiosciences.com
    mv bases2fastq_latest.sif bases2fastq_[VERSION].sif
    # example version = 2.3.0
```

### mapNstat.sh
```
Runs PE reads (fastq/fastq.gz format) against provided reference sequence using BWA-mem,
and then computes mapping statistics using samtools flagstat.

Usage:
    sbatch mapNstat.sh -r ref.fasta -s samples.csv -o results -e mapping

Arguments:
    -r    reference FASTA sequence. If it is not already indexed, the script will auto-detect
          and run bwa index first.
    -s    samplesheet CSV containing JUST the following column headings: sample,R1,R2
            sample = sample ID
            R1 = path to forward read file
            R2 = path to reverse read file
    -o    Output directory path
    -e    Path to conda environment contianing dependencies to activate (if not already activated)

Dependencies:
    Conda env containing bwa (v0.7.19) and samtools (v1.24)

NOTE: samples are processed sequentially in a single job, so the walltime
needs to cover ALL samples - check your partition's limit ('day' above).
```

### illumina_qc_pipeline.sh
```
This pipeline takes as input a runfolder from an Illumina machine and does:
  - basecalling
  - adapter/quality/length read trimming
  - QC before and after trimming

Requisites:
  - RunInfo.xml file must be in the run folder
  - SampleSheet.csv file must be in the run folder and contain the adapters
  - path to input runfolder and output folder

Before running it, you should setup the conda environment (only once):
  conda create --name bash_illumina_pipeline
  conda activate bash_illumina_pipeline
  conda install -c bih-cubi bcl2fastq2
  conda install -c bioconda fastqc skewer trimmomatic
  conda install -c conda-forge -c bioconda multiqc
  conda install -c conda-forge dos2unix

How to run it - e.g.:
  bash pipeline.sh [Input_runfolder] [Output_runfolder]

[written by Silvia Salatino]
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
