#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
shap=$2
max_seqlets=$3

echo $1 $2 $3

echo 'mkdir project_dir'
project_dir=/project
mkdir $project_dir

# create the log file
logfile=$project_dir/${1}_modisco.log
touch $logfile


# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the shap directory
shap_dir=$project_dir/shap
echo $( timestamp ): "mkdir" $shap_dir | tee -a $logfile
mkdir $shap_dir

# create the modisco directories
modisco_profile_dir=$project_dir/modisco_profile
echo $( timestamp ): "mkdir" $modisco_profile_dir | tee -a $logfile
mkdir $modisco_profile_dir

modisco_counts_dir=$project_dir/modisco_counts
echo $( timestamp ): "mkdir" $modisco_counts_dir | tee -a $logfile
mkdir $modisco_counts_dir

#Step 1: Copy the shap files

echo $shap | sed 's/,/ /g' | xargs cp -t ${shap_dir}/

echo $( timestamp ): "cp" $shap ${shap_dir}/ |\
tee -a $logfile 

#Step 2: Run modisco on counts and profile

mv ${shap_dir}/counts*scores*h5 ${shap_dir}/counts_scores.h5
mv ${shap_dir}/profile*scores*h5 ${shap_dir}/profile_scores.h5

echo $( timestamp ): "
python /tfmodisco-lite/modisco motifs\\
    --h5py $shap_dir/profile_scores.h5 \\
    --output $modisco_profile_dir/modisco_results.h5 \\
    --pngs_dir $modisco_profile_dir \\
    --max_seqlets $max_seqlets" | tee -a $logfile

python /tfmodisco-lite/modisco motifs\
    --h5py $shap_dir/profile_scores.h5 \
    --output $modisco_profile_dir/modisco_results.h5 \
    --pngs_dir $modisco_profile_dir \
    --max_seqlets $max_seqlets

    
echo $( timestamp ): "
python /tfmodisco-lite/modisco motifs\\
    --h5py $shap_dir/counts_scores.h5 \\
    --output $modisco_counts_dir/modisco_results.h5 \\
    --pngs_dir $modisco_counts_dir \\
    --max_seqlets $max_seqlets" | tee -a $logfile

python /tfmodisco-lite/modisco motifs\
    --h5py $shap_dir/counts_scores.h5 \
    --output $modisco_counts_dir/modisco_results.h5 \
    --pngs_dir $modisco_counts_dir \
    --max_seqlets $max_seqlets