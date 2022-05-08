#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
bigwigs=$2
peaks=$3
background_regions=$4


mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_basic_stats.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the correltions directory with all peaks and all chromosomes
chip_control_correlation_peaks=$project_dir/chip_control_correlation_peaks
echo $( timestamp ): "mkdir" $chip_control_correlation_peaks| tee -a $logfile
mkdir $chip_control_correlation_peaks

chip_control_correlation_all_peaks=$project_dir/chip_control_correlation_all_peaks
echo $( timestamp ): "mkdir" $chip_control_correlation_all_peaks| tee -a $logfile
mkdir $chip_control_correlation_all_peaks


# Step 1: Copy the bigwig,models and peak files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}_peaks.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_peaks.bed.gz


echo $( timestamp ): "cp" $background_regions ${data_dir}/${experiment}_background_regions.bed.gz |\
tee -a $logfile 

cp $background_regions ${data_dir}/${experiment}_background_regions.bed.gz


echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_background_regions.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_background_regions.bed.gz


echo $( timestamp ): "cat" ${data_dir}/${experiment}_peaks.bed ${data_dir}/${experiment}_background_regions.bed ">" ${data_dir}/${experiment}_combined.bed.gz |\
tee -a $logfile 

cat ${data_dir}/${experiment}_peaks.bed ${data_dir}/${experiment}_background_regions.bed > ${data_dir}/${experiment}_combined.bed


echo $( timestamp ): "python ./basic_stats.py -p ${data_dir}/${experiment}_peaks.bed \\
--pos-bw-path ${data_dir}/${experiment}_plus.bigWig \\
--neg-bw-path ${data_dir}/${experiment}_minus.bigWig \\
--control-pos-bw-path ${data_dir}/${experiment}_control_plus.bigWig \\
--control-neg-bw-path ${data_dir}/${experiment}_control_minus.bigWig \\
-o ${chip_control_correlation_peaks}" | tee -a $logfile 

python ./basic_stats.py -p ${data_dir}/${experiment}_peaks.bed \
--pos-bw-path ${data_dir}/${experiment}_plus.bigWig \
--neg-bw-path ${data_dir}/${experiment}_minus.bigWig \
--control-pos-bw-path ${data_dir}/${experiment}_control_plus.bigWig \
--control-neg-bw-path ${data_dir}/${experiment}_control_minus.bigWig \
-o ${chip_control_correlation_peaks} | tee -a $logfile 


echo $( timestamp ): "python ./basic_stats.py -p ${data_dir}/${experiment}_combined.bed \\
--pos-bw-path ${data_dir}/${experiment}_plus.bigWig \\
--neg-bw-path ${data_dir}/${experiment}_minus.bigWig \\
--control-pos-bw-path ${data_dir}/${experiment}_control_plus.bigWig \\
--control-neg-bw-path ${data_dir}/${experiment}_control_minus.bigWig \\
-o ${chip_control_correlation_all_peaks}" | tee -a $logfile 

python ./basic_stats.py -p ${data_dir}/${experiment}_combined.bed \
--pos-bw-path ${data_dir}/${experiment}_plus.bigWig \
--neg-bw-path ${data_dir}/${experiment}_minus.bigWig \
--control-pos-bw-path ${data_dir}/${experiment}_control_plus.bigWig \
--control-neg-bw-path ${data_dir}/${experiment}_control_minus.bigWig \
-o ${chip_control_correlation_all_peaks} | tee -a $logfile 
