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
trim_size=$4
initial_flank_to_add=$5
final_flank_to_add=$6

echo $1 $2 $3 $4 $5 $6

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

echo $( timestamp ): "mkdir" $modisco_profile_dir/trimmed_logos | tee -a $logfile
mkdir $modisco_profile_dir/trimmed_logos

echo $( timestamp ): "mkdir" $modisco_profile_dir/meme | tee -a $logfile
mkdir $modisco_profile_dir/meme

modisco_counts_dir=$project_dir/modisco_counts
echo $( timestamp ): "mkdir" $modisco_counts_dir | tee -a $logfile
mkdir $modisco_counts_dir

echo $( timestamp ): "mkdir" $modisco_counts_dir/trimmed_logos | tee -a $logfile
mkdir $modisco_counts_dir/trimmed_logos

echo $( timestamp ): "mkdir" $modisco_counts_dir/meme | tee -a $logfile
mkdir $modisco_counts_dir/meme

#Step 1: Copy the shap files

echo $shap | sed 's/,/ /g' | xargs cp -t ${shap_dir}/

echo $( timestamp ): "cp" $shap ${shap_dir}/ |\
tee -a $logfile 

#Step 2: Run modisco on counts and profile

mv ${shap_dir}/counts*scores*h5 ${shap_dir}/counts_scores.h5
mv ${shap_dir}/profile*scores*h5 ${shap_dir}/profile_scores.h5

echo $( timestamp ): "
python /tfmodisco-lite/modisco motifs\\
    --max_seqlets $max_seqlets \\
    --h5py $shap_dir/profile_scores.h5 \\
    -o $modisco_profile_dir/profile_scores.h5 \\
    --trim_size $trim_size \\
    --initial_flank_to_add $initial_flank_to_add \\
    --final_flank_to_add $final_flank_to_add" | tee -a $logfile

python /tfmodisco-lite/modisco motifs\
    --max_seqlets $max_seqlets \
    --h5py $shap_dir/profile_scores.h5 \
    -o $modisco_profile_dir/profile_scores.h5 \
    --trim_size $trim_size \
    --initial_flank_to_add $initial_flank_to_add \
    --final_flank_to_add $final_flank_to_add

echo $( timestamp ): "
python /tfmodisco-lite/modisco report \\
    -i $modisco_profile_dir/profile_scores.h5 \\
    -o $modisco_profile_dir/trimmed_logos" | tee -a $logfile


python /tfmodisco-lite/modisco report \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o $modisco_profile_dir/trimmed_logos

echo $( timestamp ): "
python /tfmodisco-lite/modisco meme \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o meme/{PFM,CWM,hCWM,CWM-PFM,hCWM-PFM}.meme \
    -t {PFM,CWM,hCWM,CWM-PFM,hCWM-PFM}" | tee -a $logfile

python /tfmodisco-lite/modisco meme \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o meme/CWM.meme \
    -t CWM

python /tfmodisco-lite/modisco meme \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o meme/PFM.meme \
    -t PFM

python /tfmodisco-lite/modisco meme \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o meme/hCWM.meme \
    -t hCWM

python /tfmodisco-lite/modisco meme \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o meme/CWM-PFM.meme \
    -t CWM-PFM

python /tfmodisco-lite/modisco meme \
    -i $modisco_profile_dir/profile_scores.h5 \
    -o meme/hCWM-PFM.meme \
    -t hCWM-PFM

echo $( timestamp ): "
python /tfmodisco-lite/modisco motifs\\
    --max_seqlets $max_seqlets \\
    --h5py $shap_dir/counts_scores.h5 \\
    -o $modisco_counts_dir/counts_scores.h5 \\
    --trim_size $trim_size \\
    --initial_flank_to_add $initial_flank_to_add \\
    --final_flank_to_add $final_flank_to_add" | tee -a $logfile

python /tfmodisco-lite/modisco motifs\
    --max_seqlets $max_seqlets \
    --h5py $shap_dir/counts_scores.h5 \
    -o $modisco_counts_dir/counts_scores.h5 \
    --trim_size $trim_size \
    --initial_flank_to_add $initial_flank_to_add \
    --final_flank_to_add $final_flank_to_add

echo $( timestamp ): "
python /tfmodisco-lite/modisco report \\
    -i $modisco_counts_dir/counts_scores.h5 \\
    -o $modisco_counts_dir/trimmed_logos" | tee -a $logfile


python /tfmodisco-lite/modisco report \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o $modisco_counts_dir/trimmed_logos

echo $( timestamp ): "
python /tfmodisco-lite/modisco meme \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o meme/{PFM,CWM,hCWM,CWM-PFM,hCWM-PFM}.meme \
    -t {PFM,CWM,hCWM,CWM-PFM,hCWM-PFM}" | tee -a $logfile

python /tfmodisco-lite/modisco meme \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o meme/CWM.meme \
    -t CWM

python /tfmodisco-lite/modisco meme \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o meme/PFM.meme \
    -t PFM

python /tfmodisco-lite/modisco meme \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o meme/hCWM.meme \
    -t hCWM

python /tfmodisco-lite/modisco meme \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o meme/CWM-PFM.meme \
    -t CWM-PFM

python /tfmodisco-lite/modisco meme \
    -i $modisco_counts_dir/counts_scores.h5 \
    -o meme/hCWM-PFM.meme \
    -t hCWM-PFM