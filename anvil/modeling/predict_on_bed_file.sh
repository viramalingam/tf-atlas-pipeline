#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
model=$2
testing_input_json=$3
splits_json=$4
reference_file=$5
reference_file_index=$6
chrom_sizes=$7
chroms_txt=$8
bigwigs=${9}
peaks=${10}
input_seq_len=${11}
output_len=${12}

echo $experiment
echo $model
echo $testing_input_json
echo $splits_json
echo $reference_file
echo $reference_file_index
echo $chrom_sizes
echo $chroms_txt
echo $bigwigs
echo $peaks
echo $input_seq_len
echo $output_len


mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_fastpredict.log
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

# create indices directory
indices_dir=$project_dir/splits_indices
echo $( timestamp ): "mkdir" $indices_dir | tee -a $logfile
mkdir $indices_dir

# create the predictions directory with all peaks and all chromosomes
predictions_dir=$project_dir/predictions_and_metrics
echo $( timestamp ): "mkdir" $predictions_dir| tee -a $logfile
mkdir $predictions_dir



echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile 

echo $( timestamp ): "cp" $reference_file_index ${reference_dir}/hg38.genome.fa.fai |\
tee -a $logfile 

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile 


# copy down data and reference

cp $reference_file $reference_dir/hg38.genome.fa
cp $reference_file_index $reference_dir/hg38.genome.fa.fai
cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt


# Step 1: Copy the bigwig, model and peak files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 


echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/

echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile 

cd ${model_dir}

echo $( timestamp ): "tar -xvf" ${model_dir}/${1}_split000.tar |\
tee -a $logfile 

tar -xvf ${model_dir}/${1}_split000.tar

cd -


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${experiment}_peaks.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_peaks.bed.gz


# cp input json template

echo $( timestamp ): "cp" $testing_input_json \
$project_dir/testing_input.json | tee -a $logfile 
cp $testing_input_json $project_dir/testing_input.json

# cp splits json template
echo $( timestamp ): "cp" $splits_json \
$project_dir/splits.json | tee -a $logfile 
cp $splits_json $project_dir/splits.json


#set threads based on number of peaks

if [ $(wc -l < ${data_dir}/${experiment}_peaks.bed) -lt 3500 ];then
    threads=1
else
    threads=4
fi


# modify the testing_input json for prediction
cp $project_dir/testing_input.json $project_dir/testing_input_all.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_all.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_all.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/combined/g" $project_dir/testing_input_all.json 
sed -i -e "s/<test_loci>/peaks/g" $project_dir/testing_input_all.json | tee -a $logfile

# default values for the test_indices files; will be overwritten with acutall values if present
chroms_indices_file='None'

echo 'chroms_indices_file:' $chroms_indices_file

test_chromosome=$(paste -s -d ' ' $reference_dir/hg38_chroms.txt)

echo 'test_chromosome=$(paste -s -d ' ' $reference_dir/hg38_chroms.txt)'  

    
echo $( timestamp ): "
bpnet-predict \\
    --model $model_dir/${1}_split000 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --test-indices-file $chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len ${input_seq_len} \\
    --output-len ${output_len} \\
    --output-window-size ${output_len} \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads \\
    --reverse-complement-average" | tee -a $logfile 

bpnet-predict \
    --model $model_dir/${1}_split000 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --test-indices-file $chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len ${input_seq_len} \
    --output-len ${output_len} \
    --output-window-size ${output_len} \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads \
    --reverse-complement-average