#!/bin/bash

################################################################################
# This pipeline takes as input a runfolder from an Illumina machine and does:
# - basecalling
# - adapter/quality/length read trimming
# - QC before and after trimming

# Requisites:
# - RunInfo.xml file must be in the run folder
# - SampleSheet.csv file must be in the run folder and contain the adapters
# - path to input runfolder and output folder

# Before running it, you should setup the conda environment (only once):
# conda create --name bash_illumina_pipeline
# conda activate bash_illumina_pipeline
# conda install -c bih-cubi bcl2fastq2
# conda install -c bioconda fastqc skewer trimmomatic
# conda install -c conda-forge -c bioconda multiqc
# conda install -c conda-forge dos2unix

# How to run it - e.g.:
# ./pipeline.sh \
# Input_runfolders/190404_NS500271_0142_AHKTWJAFXY/ \
# Output_runfolders/190404_NS500271_0142_AHKTWJAFXY/ \
# processed_rf_list.yaml > pipeline.log 2>pipeline.err
################################################################################

# Activate the conda environment:
set +eu
eval "$(conda shell.bash hook)"
conda activate bash_illumina_pipeline
set -eu
set -o pipefail
ulimit -n 4096

# Display usage if less than two arguments are supplied:
display_usage() { 
  echo -e "\nUsage:\n" 
  echo -e " - RUNFOLDER INPUT DIR (original runfolder)\n"
  echo -e " - RUNFOLDER OUTPUT DIR (the results will be written here)\n"
  echo -e " - PROCESSED RUNFOLDER LIST FILE (FULL PATH)\n"
} 
if [ $# -le 1 ]; then 
  display_usage
  exit 1
fi 

# Get input parameters:
rf_inp=$1             # RUNFOLDER INPUT DIR (original runfolder)
rf_out=$2             # RUNFOLDER OUTPUT DIR (the results will be written here)
processed_rf_file=$3  # PROCESSED RUNFOLDER LIST FILE (FULL PATH)

# Check whether the RunInfo.xml and SampleSheet.csv files exist:
if [[ ! -f "$rf_inp/RunInfo.xml" ]] ; then
  echo "Error: cannot find RunInfo.xml file. Exiting now."
  exit
fi
if [[ ! -f "$rf_inp/SampleSheet.csv" ]] ; then
  echo "Error: cannot find SampleSheet.csv file. Exiting now."
  exit
fi

# Create a new sample sheet w/o adapter sequences:
line_num=$(awk '/\[Data\]/ {print FNR}' $rf_inp/SampleSheet.csv)
new_sample_sheet="$rf_out/SampleSheet_DataOnly.csv"
CMD_1="awk 'NR>=$line_num' $rf_inp/SampleSheet.csv > $new_sample_sheet"
echo $CMD_1
eval $CMD_1

# Demultiplex and convert BCL files to FASTQ files:
CMD_2="bcl2fastq --runfolder-dir $rf_inp --output-dir $rf_out \
--ignore-missing-bcl --ignore-missing-positions --ignore-missing-filter \
--no-lane-splitting --sample-sheet $new_sample_sheet --min-log-level WARNING"
echo $CMD_2
$CMD_2
## --tiles="                     # ONLY FOR TESTING!
## SINGLE_TILE="s_1_11101"       # ONLY FOR TESTING!
## echo $CMD_2\"$SINGLE_TILE\"   # ONLY FOR TESTING!
## $CMD_2"$SINGLE_TILE"          # ONLY FOR TESTING!

# Move raw FASTQ files in the folder FASTQ_raw:
CMD_3="mkdir -p $rf_out/FASTQ_raw/"
echo $CMD_3
$CMD_3
CMD_4="mv $rf_out/*.fastq.gz $rf_out/FASTQ_raw/"
echo $CMD_4
$CMD_4

# Launch FastQC (except for the Undetermined) *before* trimming:
CMD_5="mkdir -p $rf_out/FastQC_before_trimming/"
echo $CMD_5
$CMD_5
for fastq in `ls $rf_out/FASTQ_raw/*.fastq.gz | grep -v Undetermined`; do 
  CMD_6="fastqc -t 8 --noextract -o $rf_out/FastQC_before_trimming/ $fastq"
  echo $CMD_6
  $CMD_6
done

# Launch MultiQC (except for the Undetermined) *before* trimming:
ls -1 $rf_out/FastQC_before_trimming/*fastqc.zip > $rf_out/fastq_filelist_before_trimming.txt
CMD_7="mkdir -p $rf_out/MultiQC_before_trimming/"
echo $CMD_7
$CMD_7
CMD_8="multiqc -l $rf_out/fastq_filelist_before_trimming.txt -n \
$rf_out/MultiQC_before_trimming/MultiQC_report_before_trimming.html \
--no-data-dir --interactive"
echo $CMD_8
$CMD_8

# Trim sequencing adapters, remove low-quality ends and too-short reads
# (note: skewer uses the default Illumina adapters when they are not set; 
# x:AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC ; y:AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTA)
adapter_R1=$(grep -w Adapter $rf_inp/SampleSheet.csv | cut -f 2 -d ",")
adapter_R2=$(grep -w AdapterRead2 $rf_inp/SampleSheet.csv | cut -f 2 -d ",")
if [ -z "$adapter_R1" ]
then
  adapter_R1_option=" "                  # R1 is missing
else
  adapter_R1_option="-x ${adapter_R1}"   # R1 is provided
fi
if [ -z "$adapter_R2" ]
then
  adapter_R2_option=" "                  # R2 is missing
else
  adapter_R2_option="-y ${adapter_R2}"   # R2 is provided
fi
CMD_9="mkdir -p $rf_out/FASTQ_trimmed/"
echo $CMD_9
$CMD_9
for a in `ls -1 $rf_out/FASTQ_raw/*R1_001.fastq.gz`; do 
  sample_id=$((basename $a .fastq.gz) | perl -pe 's/(_[^_]+){2}$/\n/');
  CMD_10="skewer -t 8 --quiet $adapter_R1_option $adapter_R2_option -z -m tail \
  ${rf_out}/FASTQ_raw/${sample_id}_R1_001.fastq.gz \
  ${rf_out}/FASTQ_raw/${sample_id}_R2_001.fastq.gz \
  -o ${rf_out}/FASTQ_trimmed/${sample_id}_skewer -l 25 -r 0.1"
  echo $CMD_10
  $CMD_10
  CMD_11="trimmomatic PE -phred33 -threads 8 \
  ${rf_out}/FASTQ_trimmed/${sample_id}_skewer-trimmed-pair1.fastq.gz \
  ${rf_out}/FASTQ_trimmed/${sample_id}_skewer-trimmed-pair2.fastq.gz \
  ${rf_out}/FASTQ_trimmed/${sample_id}_R1_trimmed.fastq.gz /dev/null \
  ${rf_out}/FASTQ_trimmed/${sample_id}_R2_trimmed.fastq.gz /dev/null \
  SLIDINGWINDOW:5:20 MINLEN:25"
  echo $CMD_11
  $CMD_11
done
CMD_12="find ${rf_out}/FASTQ_trimmed/ -name '*skewer*' -type f -exec rm {} \;"
echo $CMD_12
eval $CMD_12

# Launch FastQC (except for the Undetermined) *after* trimming:
CMD_13="mkdir -p $rf_out/FastQC_after_trimming/"
echo $CMD_13
$CMD_13
for fastq in `ls $rf_out/FASTQ_trimmed/*_trimmed.fastq.gz | grep -v Undetermined`; do 
  CMD_14="fastqc -t 8 --noextract -o $rf_out/FastQC_after_trimming/ $fastq"
  echo $CMD_14
  $CMD_14
done

# Launch MultiQC (except for the Undetermined) *after* trimming:
ls -1 $rf_out/FastQC_after_trimming/*fastqc.zip > $rf_out/fastqc_filelist_after_trimming.txt
CMD_15="mkdir -p $rf_out/MultiQC_after_trimming/"
echo $CMD_15
$CMD_15
CMD_16="multiqc -l $rf_out/fastqc_filelist_after_trimming.txt -n \
$rf_out/MultiQC_after_trimming/MultiQC_report_after_trimming.html \
--no-data-dir --interactive"
echo $CMD_16
$CMD_16

# Check whether a pair of FASTQ files was created for each input sample:
while read sample; do 
  if [[ ! -f "${rf_out}/FASTQ_raw/${sample}_R1_001.fastq.gz" ]] ; then
    echo "WARNING: FASTQ files could not be created for sample" $sample
  fi
done < <( tail -n +3 $rf_out/SampleSheet_DataOnly.csv | awk -F, '{print $1"_S"NR}')

# Append current runfolder to the list of processed runfolders:
echo "  - "$(basename $rf_inp) >> $processed_rf_file

# Report when all the steps above are done:
echo $rf_inp "processed, status" $?

