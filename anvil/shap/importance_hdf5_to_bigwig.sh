#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

chrom_sizes=$1
shaps_dir_input=$2


mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_shap.log
touch $logfile


# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir


# create the shap directories
shap_dir_peaks=$project_dir/shap_dir_peaks
echo $( timestamp ): "mkdir" $shap_dir_peaks | tee -a $logfile
mkdir $shap_dir_peaks

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 


# copy down data and reference

cp $chrom_sizes $reference_dir/chrom.sizes


# Step 1: Copy the shap h5 files

echo $( timestamp ): "cp" $shaps_dir_input ${shap_dir_peaks}/ |\
tee -a $logfile 

echo $shaps_dir_input | sed 's/,/ /g' | xargs cp -t $shap_dir_peaks/


echo $( timestamp ): "
python importance_hdf5_to_bigwig.py \\
        -h5 $shap_dir_peaks/profile_scores.h5 \\
        -c $reference_dir/chrom.sizes \\
        -r $shap_dir_peaks/peaks_valid_scores.bed \\
        -o $shap_dir_peaks/profile_scores.bw\\
        -s $shap_dir_peaks/profile_scores.stats.txt" \\ | tee -a $logfile 

python importance_hdf5_to_bigwig.py \
        -h5 $shap_dir_peaks/profile_scores.h5 \
        -c $reference_dir/chrom.sizes \
        -r $shap_dir_peaks/peaks_valid_scores.bed \
        -o $shap_dir_peaks/profile_scores.bw\
        -s $shap_dir_peaks/profile_scores.stats.txt
        
echo $( timestamp ): "
python importance_hdf5_to_bigwig.py \\
        -h5 $shap_dir_peaks/counts_scores.h5 \\
        -c $reference_dir/chrom.sizes \\
        -r $data_dir/peaks_valid_scores.bed \\
        -o $shap_dir_peaks/counts_scores.bw\\
        -s $shap_dir_peaks/counts_scores.stats.txt" \\ | tee -a $logfile 

python importance_hdf5_to_bigwig.py \
        -h5 $shap_dir_peaks/counts_scores.h5 \
        -c $reference_dir/chrom.sizes \
        -r $data_dir/peaks_valid_scores.bed \
        -o $shap_dir_peaks/counts_scores.bw\
        -s $shap_dir_peaks/counts_scores.stats.txt