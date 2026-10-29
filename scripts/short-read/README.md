# Short-read scripts

Scripts for processing short-read sequencing data, typically produced by Illumina or Element Biosciences sequencers. Each script includes usage instructions in the header comments.


### seqkit_stats.sh
```
Calculate simple summary stats for a collection of .fasta/.fastq/.fastq.gz files.

Usage:
  sbatch seqkit_stats.sh [-l <list.txt>] <input_path> <output_dir>
  bash   seqkit_stats.sh [-l <list.txt>] <input_path> <output_dir>

Options:
  -l <list.txt>    Plain-text file of strings, one per line. Only files whose
                   *basename* contains one of these strings are processed.
                   Matching is case-sensitive substring matching, and strings
                   are treated literally (no globbing). Blank lines and lines
                   beginning with '#' are ignored, as is surrounding
                   whitespace and trailing returns.
                   Requires <input_path> to be a directory.
                   Strings matching no files raise a warning; the run
                   continues with whatever did match.
  -h               Show this help text and exit.

Arguments:
  $1  input_path   Path to a single FASTQ/FASTA file, OR a directory
                   containing FASTQ and/or FASTA files (searched recursively).
                   Supported extensions: .fastq, .fastq.gz, .fq, .fq.gz,
                                        .fasta, .fasta.gz, .fa, .fa.gz
  $2  output_dir   Directory to write results into (created if absent).

Outputs (written to <output_dir>/):
  seqkit_stats.tsv          Full seqkit stats table (TSV, all metrics).
  seqkit_stats_summary.txt  Human-readable run summary.

Examples:
  # Everything under a directory
  bash seqkit_stats.sh /data/run3588/fastq results/
  # Only the samples named in samples.txt
  bash seqkit_stats.sh -l samples.txt /data/run3588/fastq results/
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

### bam2assembly.sh
```
Takes a mapped, sorted BAM for a single sample and runs a coverage summary, mapped-read
extraction, de novo assembly (SPAdes) and assembly QC (QUAST + BUSCO):
  1. Per-contig and sliding-window coverage of the BAM (samtools coverage / bedcov)
  2. Extract read pairs where both mates are mapped and write paired FASTQs
     (skipped if the FASTQs already exist in OUTDIR)
  3. SPAdes assembly from the extracted FASTQs
  4. QUAST assembly statistics (optionally against a reference)
  5. BUSCO completeness assessment

Usage:
    sbatch bam2assembly.sh

Arguments:
    All inputs are set in the 'User config' block of the script itself:
      INPUT_BAM        Sorted, indexed BAM of reads mapped to a reference (sole input)
      OUTDIR           Output directory (created if absent)
      SAMPLE           Sample ID, used as a prefix for all outputs
      WINDOW_SIZE      Sliding window size (bp) for coverage (default: 10000)
      REFERENCE_FASTA  Optional reference FASTA (.fa/.fna, gz OK) passed to QUAST -r.
                       Leave "" to run QUAST without a reference
      BUSCO_LINEAGE    BUSCO lineage dataset appropriate for your organism (e.g. mammalia_odb10)
      SPADES_ENV       Conda env containing SPAdes + samtools
      ASSESS_ENV       Conda env containing QUAST + BUSCO

Outputs (written to OUTDIR):
    <SAMPLE>.coverage_summary.txt          Per-contig coverage (samtools coverage)
    <SAMPLE>.sliding_window_coverage.tsv   Mean depth per window (chrom, start, end, mean_depth)
    <SAMPLE>.mapped_pairs.bam              Reads where both mates are mapped
    <SAMPLE>.mapped_R1.fastq.gz            Extracted forward reads
    <SAMPLE>.mapped_R2.fastq.gz            Extracted reverse reads
    spades_assembly/                       SPAdes output (scaffolds.fasta is used downstream)
    quast_output/                          QUAST report (report.txt)
    <SAMPLE>_busco/                        BUSCO results
    Intermediates kept: <SAMPLE>.chrom_sizes.txt, .windows.bed, .windows_rawcov.tsv

SLURM:
    --cpus-per-task is passed as the thread count to samtools, SPAdes, QUAST and BUSCO
    (falls back to 4 if unset).
    Adjust --mem as needed. SPAdes on large genomes may need considerably more than 64G.
    Set --partition to your cluster's partition name.

Behaviour notes:
    Read extraction uses samtools view -F 12, which drops any read that is unmapped or whose
    mate is unmapped. Reads are then collated and exported with samtools fastq, which excludes
    secondary/supplementary alignments by default. Singletons are discarded.
    If both mapped FASTQs already exist in OUTDIR, extraction is skipped. This means the script
    can be re-run after a failed assembly without repeating step 2.
    The script exits with an error if the mapped FASTQs are missing or empty before assembly.
    BUSCO runs with -f, so existing BUSCO output for the same sample is overwritten.

Dependencies:
    Conda env containing SPAdes and samtools (SPADES_ENV)
    Conda env containing QUAST and BUSCO (ASSESS_ENV)
```

### downsample_pe.sh
```
Randomly downsamples a pair of raw paired-end FASTQ files to a fixed number of read pairs
using BBTools reformat.sh. Subsampling is seeded, so it can be reproduced.

Usage:
    sbatch downsample_pe.sh <sample> <R1> <R2> <output_dir> [max_reads] [seed]

Arguments:
    sample        Sample ID, used for the output subdirectory, filenames and log names
    R1            Path to forward (R1) FASTQ file (.fastq or .fastq.gz)
    R2            Path to reverse (R2) FASTQ file (.fastq or .fastq.gz)
    output_dir    Directory to write results into (created if absent)
    max_reads     Optional. Number of read PAIRS to keep (default: 100000)
    seed          Optional. Random seed for subsampling (default: 12345)

Outputs (uncompressed FASTQ; existing files are overwritten):
    <output_dir>/<sample>/<sample>_R1_downsampled.fastq
    <output_dir>/<sample>/<sample>_R2_downsampled.fastq
    <output_dir>/logs/downsample/<sample>.out    Run summary and reformat.sh stdout
    <output_dir>/logs/downsample/<sample>.err    reformat.sh stderr

SLURM:
    --cpus-per-task is passed to reformat.sh as threads=, so BBTools uses only the CPUs it was
    given rather than auto-detecting every core on the node. It falls back to 1 thread when
    run outside SLURM.
    Adjust --mem as needed. The JVM heap (-Xmx) is set to 80% of the SLURM memory
    allocation (from --mem or --mem-per-cpu x --cpus-per-task). It falls back to 8000 MB
    when run outside SLURM.
    Set --partition to your cluster's partition name.

Behaviour notes:
    If either input file is missing or empty, the script writes empty placeholder outputs,
    logs a warning and exits 0. This lets it run inside workflows without stopping the
    whole batch for one empty sample.
    If an input has fewer than max_reads pairs, all of its reads are kept.
    The script exits with an error if conda or reformat.sh can't be found, if the conda env
    can't be activated, or if reformat.sh fails.
    The .out log is cleared at the start of each run. The .err log is appended to.

Dependencies:
    Conda env containing BBTools (reformat.sh), e.g. conda install -c bioconda bbmap.
    Set CONDA_ENV in the script, or override it at submission:
        CONDA_ENV=myenv sbatch downsample_pe.sh ...

Example:
    sbatch downsample_pe.sh \
        UK006 \
        UK006_R1.fastq.gz \
        UK006_R2.fastq.gz \
        downsampled/ \
        500000 12345
```
