#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
testing_input_json=$2
reference_file=$3
reference_file_index=$4
chrom_sizes=$5
chroms_txt=$6
bigwigs=$7
peaks=$8
# background_regions=$9
model=${9}

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_shap.log
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

# create the shap directories
shap_dir_peaks=$project_dir/shap_dir_peaks
echo $( timestamp ): "mkdir" $shap_dir_peaks | tee -a $logfile
mkdir $shap_dir_peaks

# shap_dir_all=$project_dir/shap_dir_all
# echo $( timestamp ): "mkdir" $shap_dir_all | tee -a $logfile
# mkdir $shap_dir_all


# copy down bigwig files, bed file, reference, and model file


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


# Step 1: Copy the bigwigs, model and peak files

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile 

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/


echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile 

echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/


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


# modify the testing_input json for 
cp $project_dir/testing_input.json $project_dir/testing_input_peaks.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_peaks.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_peaks.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/peaks/g" $project_dir/testing_input_peaks.json 
sed -i -e "s/<test_loci>/peaks/g" $project_dir/testing_input_peaks.json | tee -a $logfile


cp $project_dir/testing_input_peaks.json $shap_dir_peaks/testing_input_peaks.json
cp $model_dir/${1}_split000.h5 $shap_dir_peaks/${1}_split000.h5


echo $( timestamp ): "
shap_scores \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --model $model_dir/${1}_split000.h5 \\
    --bed-file $data_dir/${1}_peaks.bed \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --output-dir $shap_dir_peaks \\
    --input-seq-len 2114 \\
    --control-len 1000 \\
    --task-id 0 \\
    --orig-multi-loss True \\
    --input-data $project_dir/testing_input_peaks.json" | tee -a $logfile

shap_scores \
    --reference-genome $reference_dir/hg38.genome.fa \
    --model $model_dir/${1}_split000.h5 \
    --bed-file $data_dir/${1}_peaks.bed \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --output-dir $shap_dir_peaks \
    --input-seq-len 2114 \
    --control-len 1000 \
    --task-id 0 \
    --orig-multi-loss True \
    --input-data $project_dir/testing_input_peaks.json # this file doesnt have negatives

echo $( timestamp ): "
python importance_hdf5_to_bigwig.py \\
        -h5 $shap_dir_peaks/profile_scores.h5 \\
        -c $reference_dir/chrom.sizes \\
        -r $data_dir/${1}_peaks.bed \\
        -o $shap_dir_peaks/profile_scores.bw\\
        -s $shap_dir_peaks/profile_scores.stats.txt" \\ | tee -a $logfile 

python importance_hdf5_to_bigwig.py \
        -h5 $shap_dir_peaks/profile_scores.h5 \
        -c $reference_dir/chrom.sizes \
        -r $data_dir/${1}_peaks.bed \
        -o $shap_dir_peaks/profile_scores.bw\
        -s $shap_dir_peaks/profile_scores.stats.txt
        
echo $( timestamp ): "
python importance_hdf5_to_bigwig.py \\
        -h5 $shap_dir_peaks/counts_scores.h5 \\
        -c $reference_dir/chrom.sizes \\
        -r $data_dir/${1}_peaks.bed \\
        -o $shap_dir_peaks/counts_scores.bw\\
        -s $shap_dir_peaks/counts_scores.stats.txt" \\ | tee -a $logfile 

python importance_hdf5_to_bigwig.py \
        -h5 $shap_dir_peaks/counts_scores.h5 \
        -c $reference_dir/chrom.sizes \
        -r $data_dir/${1}_peaks.bed \
        -o $shap_dir_peaks/counts_scores.bw\
        -s $shap_dir_peaks/counts_scores.stats.txt
        




# # modify the testing_input json for 
# cp $project_dir/testing_input.json $project_dir/testing_input_all.json
# echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_all.json 
# sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_all.json | tee -a $logfile 

# echo  $( timestamp ): "sed -i -e" "s/<test_loci>/combined/g" $project_dir/testing_input_all.json 
# sed -i -e "s/<test_loci>/combined/g" $project_dir/testing_input_all.json | tee -a $logfile


# cp $project_dir/testing_input_all.json $shap_dir_all/testing_input_all.json
# cp $model_dir/${1}_split000.h5 $shap_dir_all/${1}_split000.h5


# echo $( timestamp ): "
# shap_scores \\
#     --reference-genome $reference_dir/hg38.genome.fa \\
#     --model $model_dir/${1}_split000.h5 \\
#     --bed-file $data_dir/${1}_combined.bed \\
#     --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
#     --output-dir $shap_dir_all \\
#     --input-seq-len 2114 \\
#     --control-len 1000 \\
#     --task-id 0 \\
#     --input-data $project_dir/testing_input_all.json" | tee -a $logfile

# shap_scores \
#     --reference-genome $reference_dir/hg38.genome.fa \
#     --model $model_dir/${1}_split000.h5 \
#     --bed-file $data_dir/${1}_combined.bed \
#     --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
#     --output-dir $shap_dir_all \
#     --input-seq-len 2114 \
#     --control-len 1000 \
#     --task-id 0 \
#     --input-data $project_dir/testing_input_all.json # this file doesnt have negatives

# echo $( timestamp ): "
# python importance_hdf5_to_bigwig.py \\
#         -h5 $shap_dir_all/profile_scores.h5 \\
#         -c $reference_dir/chrom.sizes \\
#         -r $data_dir/${1}_combined.bed \\
#         -o $shap_dir_all/profile_scores.bw\\
#         -s $shap_dir_all/profile_scores.stats.txt" \\ | tee -a $logfile 

# python importance_hdf5_to_bigwig.py \
#         -h5 $shap_dir_all/profile_scores.h5 \
#         -c $reference_dir/chrom.sizes \
#         -r $data_dir/${1}_combined.bed \
#         -o $shap_dir_all/profile_scores.bw\
#         -s $shap_dir_all/profile_scores.stats.txt
        
# echo $( timestamp ): "
# python importance_hdf5_to_bigwig.py \\
#         -h5 $shap_dir_all/counts_scores.h5 \\
#         -c $reference_dir/chrom.sizes \\
#         -r $data_dir/${1}_combined.bed \\
#         -o $shap_dir_all/counts_scores.bw\\
#         -s $shap_dir_all/counts_scores.stats.txt" \\ | tee -a $logfile 

# python importance_hdf5_to_bigwig.py \
#         -h5 $shap_dir_all/counts_scores.h5 \
#         -c $reference_dir/chrom.sizes \
#         -r $data_dir/${1}_combined.bed \
#         -o $shap_dir_all/counts_scores.bw\
#         -s $shap_dir_all/counts_scores.stats.txt