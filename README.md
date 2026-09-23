# Tools
Collection of tools and scripts for a range of bioinformatics tasks.

## Docs

#### Software

A list of software and tools useful for a range of bioinformatics tasks.

#### Practicals

Online tutorials and practicals for a range of bioinformatics applications.

### SOPs

Standard operating procedures for transferring data between an FTP server and your local computer or HPC.

## Scripts

For information and instructions on using these scripts, please refer to [short reads README](scripts/short-read/README.md) and [long reads README](scripts/long-read/README.md)

### short-read

Scripts for processing short-read sequencing data, typically produced by Illumina or Element Biosciences sequencers.

#### seqkit_stats.sh
Calculates summary statistics (read count, total bases, mean length, etc.) for a collection of FASTA/FASTQ files. Supports processing a single file or a whole directory recursively, with optional filtering by sample name.

#### meta-spades.sh
Runs SPAdes in metagenomic mode on paired-end short reads. Takes forward and reverse FASTQ files and an output directory, and submits the assembly as a SLURM job.

#### mapNstat.sh
Maps paired-end reads to a reference sequence using BWA-MEM and computes per-sample mapping statistics with samtools flagstat. Takes a samplesheet CSV and processes all samples sequentially in a single job.

#### illumina_qc_pipeline.sh
Processes a raw Illumina run folder through basecalling, adapter and quality trimming, and QC reporting (FastQC/MultiQC) before and after trimming.

#### bases2fastq.slurm
Basecalls and demultiplexes raw AVITI24 sequencing data from the NHM's Element Biosciences sequencer using the Bases2Fastq tool, run inside a Singularity container. Accepts an optional run manifest or falls back to auto-detection.

### long-read

Scripts for processing long-read sequencing data produced by Oxford Nanopore Technologies (ONT) sequencers.

#### nanoplot.sh
Runs NanoPlot on one or more Oxford Nanopore FASTQ files to generate read quality and length distribution plots. Accepts a single file or a directory and creates a per-sample output folder for each.
