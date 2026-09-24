# Tools

A collection of tools, scripts and documentation for common bioinformatics tasks, from sequencing QC and demultiplexing to read mapping and assembly. This repository will

## Contents

- [Documentation](#documentation)
- [Scripts](#scripts)
  - [Short-read](#short-read)
  - [Long-read](#long-read)

## Documentation

| Resource | Description |
|----------|-------------|
| **Software** | A curated list of software and tools for a range of bioinformatics tasks. |
| **Practicals** | Online tutorials and practicals. |
| **SOPs** | Standard operating procedures for transferring data, running pipelines, etc. |

## Scripts

Each script is briefly described below. For full usage instructions, see the [short-read README](scripts/short-read/README.md) and the [long-read README](scripts/long-read/README.md).

### Short-read

Scripts for processing short-read sequencing data, typically from Illumina or Element Biosciences sequencers.

| Script | Description |
|--------|-------------|
| `seqkit_stats.sh` | Calculates summary statistics (read count, total bases, mean length, etc.) for FASTA/FASTQ files. Works on a single file or recursively on a directory, with optional filtering by sample name. |
| `meta-spades.sh` | Runs SPAdes in metagenomic mode on paired-end reads. Takes forward and reverse FASTQ files and an output directory, and submits the assembly as a SLURM job. |
| `mapNstat.sh` | Maps paired-end reads to a reference with BWA-MEM and reports per-sample mapping statistics with `samtools flagstat`. Takes a samplesheet CSV and processes all samples sequentially in a single job. |
| `illumina_qc_pipeline.sh` | Takes a raw Illumina run folder through basecalling, adapter and quality trimming, and FastQC/MultiQC reporting before and after trimming. |
| `bases2fastq.slurm` | Basecalls and demultiplexes raw AVITI24 data from the NHM's Element Biosciences sequencer using Bases2Fastq in a Singularity container. Uses a run manifest if provided, otherwise auto-detects settings. |

### Long-read

Scripts for processing long-read sequencing data from Oxford Nanopore Technologies (ONT) sequencers.

| Script | Description |
|--------|-------------|
| `nanoplot.sh` | Runs NanoPlot on one or more ONT FASTQ files to generate read quality and length distribution plots. Accepts a single file or a directory, and creates a separate output folder for each sample. 
