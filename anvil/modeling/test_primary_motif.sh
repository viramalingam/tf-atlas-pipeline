#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
motifs=$2
model=$3
reference_file=$4
peaks=${5}
training_input=${6}

echo $experiment
echo "${motifs}"
echo $model
echo $reference_file
echo $peaks
echo $training_input

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_test_motifs.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# create the model directory
model_dir=$project_dir/model
echo $( timestamp ): "mkdir" $model_dir | tee -a $logfile
mkdir $model_dir

# create the predictions directory
predictions_dir=$project_dir/prediction
echo $( timestamp ): "mkdir" $predictions_dir | tee -a $logfile
mkdir $predictions_dir



echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile 

# copy down data and reference

cp $reference_file $reference_dir/hg38.genome.fa

# Step 1: Copy the model and peak files


echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/

echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile 


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}_peaks.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

if [ "$training_input" = "" ]; then
    cp ${model_dir}/training_input.json $data_dir/training_input.json
    echo $( timestamp ): "cp" ${model_dir}/training_input.json $data_dir/training_input.json | tee -a $logfile 
else
    cp $training_input $data_dir/training_input.json
    echo $( timestamp ): "cp" $training_input $data_dir/training_input.json | tee -a $logfile 
fi

control_files=`jq '.["0"]["bias"]["source"] | join(" ")' $data_dir/training_input.json`

        
if [ "$control_files" = "" ]; then
    echo $( timestamp ): '
    python test_motifs.py \\
        --peak ${data_dir}/${experiment}_peaks.bed.gz \\
        --h5model $model_dir/${1}_split000.h5 \\
        --no_control_model \\
        --motifs "${motifs}" \\
        --reference_genome $reference_dir/hg38.genome.fa \\
        --number_of_backgrounds 1000 \\
        --output_dir $predictions_dir \\
        --input_seq_len 2114 \\
        --output_len 1000' | tee -a $logfile 

    python test_motifs.py \
        --peak ${data_dir}/${experiment}_peaks.bed.gz \
        --h5model $model_dir/${1}_split000.h5 \
        --no_control_model \
        --motifs "${motifs}" \
        --reference_genome $reference_dir/hg38.genome.fa \
        --number_of_backgrounds 1000 \
        --output_dir $predictions_dir \
        --input_seq_len 2114 \
        --output_len 1000
        
else
    echo $( timestamp ): '
    python test_motifs.py \\
        --peak ${data_dir}/${experiment}_peaks.bed.gz \\
        --h5model $model_dir/${1}_split000.h5 \\
        --motifs "${motifs}" \\
        --reference_genome $reference_dir/hg38.genome.fa \\
        --number_of_backgrounds 1000 \\
        --output_dir $predictions_dir \\
        --input_seq_len 2114 \\
        --output_len 1000' | tee -a $logfile 

    python test_motifs.py \
        --peak ${data_dir}/${experiment}_peaks.bed.gz \
        --h5model $model_dir/${1}_split000.h5 \
        --motifs "${motifs}" \
        --reference_genome $reference_dir/hg38.genome.fa \
        --number_of_backgrounds 1000 \
        --output_dir $predictions_dir \
        --input_seq_len 2114 \
        --output_len 1000
        
fi
