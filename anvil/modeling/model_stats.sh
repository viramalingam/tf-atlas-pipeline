#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
model=$2

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_model_stats.log
touch $logfile

# create the data directory
model_dir=$project_dir/model
echo $( timestamp ): "mkdir" $model_dir | tee -a $logfile
mkdir $model_dir



# Step 1: Copy the model folder files

echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/

echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile 



echo $( timestamp ): "python ./model_stats.py -m ${model_dir}/${experiment}_split000.h5 \\
-o ${model_dir}" | tee -a $logfile 

python ./model_stats.py -p ${model_dir}/${experiment}_split000.h5 \
-o ${model_dir} | tee -a $logfile 

