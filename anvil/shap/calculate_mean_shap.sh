#!/bin/bash

counts_shaps=$1
profile_shaps=$2

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/mean_shap.log
touch $logfile

echo $( timestamp ): "
python /my_scripts/tf-atlas-pipeline/anvil/shap/mean_shap.py \\
    --counts_shaps $counts_shaps \\
    --profile_shaps $profile_shaps" | tee -a $logfile 
    
python /my_scripts/tf-atlas-pipeline/anvil/shap/mean_shap.py \
    --counts_shaps $counts_shaps \
    --profile_shaps $profile_shaps