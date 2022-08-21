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
nonpeaks=$4
number_of_folds=$5


mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_splits.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create indices directory
indices_dir=$project_dir/splits_indices
echo $( timestamp ): "mkdir" $indices_dir | tee -a $logfile
mkdir $indices_dir

# create indices directory
supplemental_outputs=$project_dir/supplemental_outputs
echo $( timestamp ): "mkdir" $supplemental_outputs | tee -a $logfile
mkdir $supplemental_outputs

#Copy the bigwig files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 



echo $( timestamp ): "
python /my_scripts/tf-atlas-pipeline/anvil/modeling/peak_wise_splits.py \
    --bigwig ${data_dir}/${experiment}_plus.bigWig \
    --peaks $peaks \
    --nonpeaks $nonpeaks \
    --inputlen 2114 \
    -j 128 \
    --number-of-folds $number_of_folds \
    -o $indices_dir\
    --supplemental_output_path $supplemental_outputs" | tee -a $logfile 

python /my_scripts/tf-atlas-pipeline/anvil/modeling/peak_wise_splits.py \
    --bigwig ${data_dir}/${experiment}_plus.bigWig \
    --peaks $peaks \
    --nonpeaks $nonpeaks \
    --inputlen 2114 \
    -j 128 \
    --number-of-folds $number_of_folds \
    -o $indices_dir \
    --supplemental_output_path $supplemental_outputs