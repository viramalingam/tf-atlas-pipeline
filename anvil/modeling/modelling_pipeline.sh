#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
training_input_json=$2
testing_input_json=$3
bpnet_params_json=$4
splits_json=$5
reference_file=$6
reference_file_index=$7
chrom_sizes=$8
chroms_txt=$9
bigwigs=${10}
peaks=${11}
background_regions=${12}
learning_rate=${13}
indices_files=${14}

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_modeling.log
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
predictions_dir_all_peaks_all_chroms=$project_dir/predictions_and_metrics_all_peaks_all_chroms
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_all_chroms| tee -a $logfile
mkdir $predictions_dir_all_peaks_all_chroms

# create the predictions directory with all peaks and test chromosomes
predictions_dir_all_peaks_test_chroms=$project_dir/predictions_and_metrics_all_peaks_test_chroms
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_test_chroms| tee -a $logfile
mkdir $predictions_dir_all_peaks_test_chroms

# create the predictions directory with test_peaks and test chroms
predictions_dir_test_peaks_test_chroms=$project_dir/predictions_and_metrics_test_peaks_test_chroms
echo $( timestamp ): "mkdir" $predictions_dir_test_peaks_test_chroms | tee -a $logfile
mkdir $predictions_dir_test_peaks_test_chroms

# create the predictions directory with test_peaks and all_chroms
predictions_dir_test_peaks_all_chroms=$project_dir/predictions_and_metrics_test_peaks_all_chroms
echo $( timestamp ): "mkdir" $predictions_dir_test_peaks_all_chroms | tee -a $logfile
mkdir $predictions_dir_test_peaks_all_chroms


# create the predictions directory with all peaks and test chromosomes for calculation with zero bias
predictions_dir_all_peaks_test_chroms_wo_bias=$project_dir/predictions_and_metrics_all_peaks_test_chroms_wo_bias
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_test_chroms_wo_bias| tee -a $logfile
mkdir $predictions_dir_all_peaks_test_chroms_wo_bias

# create the predictions directory with test_peaks and test chroms for calculation with zero bias
predictions_dir_test_peaks_test_chroms_wo_bias=$project_dir/predictions_and_metrics_test_peaks_test_chroms_wo_bias
echo $( timestamp ): "mkdir" $predictions_dir_test_peaks_test_chroms_wo_bias | tee -a $logfile
mkdir $predictions_dir_test_peaks_test_chroms_wo_bias



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


# Step 1: Copy the bigwig and peak files

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


# cp input json template

# First the input json for the train command (with loci from 
# the combined bed file, peaks + gc-matched negatives)

echo $( timestamp ): "cp" $training_input_json \
$project_dir/training_input.json | tee -a $logfile 
cp $training_input_json $project_dir/training_input.json

# modify the input json 
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/training_input.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/training_input.json | tee -a $logfile 


echo $( timestamp ): "cp" $testing_input_json \
$project_dir/testing_input.json | tee -a $logfile 
cp $testing_input_json $project_dir/testing_input.json


# cp bpnet params json template
echo $( timestamp ): "cp" $bpnet_params_json \
$project_dir/bpnet_params.json| tee -a $logfile 
cp $bpnet_params_json $project_dir/bpnet_params.json



# cp splits json template
echo $( timestamp ): "cp" $splits_json \
$project_dir/splits.json | tee -a $logfile 
cp $splits_json $project_dir/splits.json

echo $indices_files
# cp train val test indices files
if [[ -n "${indices_files}" ]];then
    echo "indices variable set"
    if [[ $indices_files!='' ]];then
        echo $indices_files | sed 's/,/ /g' | xargs cp -t $indices_dir/
        echo $( timestamp ): "cp" $indices_files ${indices_dir}/ |\
        tee -a $logfile 
    fi
fi

echo "/project/data/"
ls /project/data/
echo '$project_dir/training_input.json'
cat $project_dir/training_input.json

# compute the counts loss weight to be used for this experiment
echo $( timestamp ): "counts_loss_weight=\`counts_loss_weight --input-data \
$project_dir/training_input.json\`" | tee -a $logfile

#default counts_loss_weight
counts_loss_weight=100

#compute the counts_loss_weight; if it does not work default will be used
counts_loss_weight=`counts_loss_weight --input-data $project_dir/training_input.json`

# print the counts loss weight
echo $( timestamp ): "counts_loss_weight:" $counts_loss_weight | tee -a $logfile 

# modify the bpnet params json to reflect the counts loss weight
echo  $( timestamp ): "sed -i -e" "s/<>/$counts_loss_weight/g" \
$project_dir/bpnet_params.json | tee -a $logfile 
sed -i -e "s/<>/$counts_loss_weight/g" $project_dir/bpnet_params.json

#set threads based on number of peaks

if [ $(wc -l < ${data_dir}/${experiment}_peaks.bed) -lt 3500 ];then
    threads=1
else
    threads=2
fi

head ${data_dir}/${experiment}_peaks.bed

echo $( timestamp ): "
train \\
    --input-data $project_dir/training_input.json \\
    --output-dir $model_dir \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt)  \\
    --shuffle \\
    --epochs 2 \\
    --splits $project_dir/splits.json \\
    --model-arch-name BPNet \\
    --model-arch-params-json $project_dir/bpnet_params.json \\
    --sequence-generator-name BPNet \\
    --model-output-filename $1 \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --threads $threads \\
    --batch-size 64 \\
    --reverse-complement-augmentation \\
    --learning-rate $learning_rate \\
    --early-stopping-patience 10 \\
    --reduce-lr-on-plateau-patience 5" | tee -a $logfile 

train \
    --input-data $project_dir/training_input.json \
    --output-dir $model_dir \
    --reference-genome $reference_dir/hg38.genome.fa \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt)  \
    --shuffle \
    --epochs 2 \
    --splits $project_dir/splits.json \
    --model-arch-name BPNet \
    --model-arch-params-json $project_dir/bpnet_params.json \
    --sequence-generator-name BPNet \
    --model-output-filename $1 \
    --input-seq-len 2114 \
    --output-len 1000 \
    --threads $threads \
    --batch-size 64 \
    --reverse-complement-augmentation \
    --learning-rate $learning_rate \
    --early-stopping-patience 10 \
    --reduce-lr-on-plateau-patience 5
    
# save the values used for training
cp $project_dir/training_input.json $model_dir/
cp ${data_dir}/${experiment}_peaks.bed $model_dir/
cp ${data_dir}/${experiment}_background_regions.bed $model_dir/
cp ${data_dir}/${experiment}_combined.bed $model_dir/
cp $project_dir/bpnet_params.json $model_dir/
cp $project_dir/splits.json $model_dir/
cp -r $indices_dir $model_dir/


# modify the testing_input json for prediction
cp $project_dir/testing_input.json $project_dir/testing_input_all.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_all.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_all.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/combined/g" $project_dir/testing_input_all.json 
sed -i -e "s/<test_loci>/combined/g" $project_dir/testing_input_all.json | tee -a $logfile

# default values for the test_indices files; will be overwritten with acutall values if present
test_peaks_test_chroms_indices_file='None'
test_peaks_all_chroms_indices_file='None'
all_peaks_all_chroms_indices_file='None'
all_peaks_test_chroms_indices_file='None'

if [[ -n "${indices_files}" ]];then
    if [[ ${indices_files} != '' ]];then


     seq 0 $(wc -l ${data_dir}/${experiment}_peaks.bed | awk '{print $1-1}')> $indices_dir/test_peaks_all_chroms_indices.txt

     seq 0 $(wc -l ${data_dir}/${experiment}_combined.bed | awk '{print $1-1}')> $indices_dir/all_peaks_all_chroms_indices.txt


     test_peaks_test_chroms_indices_file=$(jq '.["0"]["loci_test_indices_file"]' $project_dir/splits.json | sed 's/"//g')
     
     echo "test_peaks_test_chroms_indices_file:" $test_peaks_test_chroms_indices_file
     
     test_peaks_all_chroms_indices_file=$indices_dir/test_peaks_all_chroms_indices.txt
     all_peaks_all_chroms_indices_file=$indices_dir/all_peaks_all_chroms_indices.txt

     background_test_indices_file=$(jq '.["0"]["background_test_indices_file"]' $project_dir/splits.json | sed 's/"//g')
     number_of_peaks=$(wc -l ${data_dir}/${experiment}_peaks.bed)
     awk -v var="$number_of_peaks" '{print ($1 + var)}' $background_test_indices_file > $indices_dir/background_test_indices_file_global_index.txt
     cat $test_peaks_test_chroms_indices_file $indices_dir/background_test_indices_file_global_index.txt > $indices_dir/all_peaks_test_chroms_indices.txt

     all_peaks_test_chroms_indices_file=$indices_dir/all_peaks_test_chroms_indices.txt


    fi
fi

#get the test chromosome for chromosome wise training regime

if [[ -n "$(jq '.["0"]["test"] // empty' $project_dir/splits.json)" ]]; then 

    test_chromosome=`jq '.["0"]["test"] | join(" ")' $project_dir/splits.json | sed 's/"//g'`

    echo 'test_chromosome=jq .["0"]["test"] | join(" ") $project_dir/splits.json | sed s/"//g'

else
    
    test_chromosome='None'

    echo "test_chromosome=$test_chromosome"

fi


#set all chromosomes as test chromosomes for some calculations for chromosome wise training regime

if [[ -n "$(jq '.["0"]["test"] // empty' $project_dir/splits.json)" ]]; then 
    
    test_all_chromosome=$(paste -s -d ' ' $reference_dir/hg38_chroms.txt)

    echo 'test_chromosome=$(paste -s -d ' ' $reference_dir/hg38_chroms.txt)'  

else

    test_all_chromosome='None'

    echo "test_chromosome=$test_chromosome"

fi

echo $( timestamp ): "
predict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --test-indices-file $all_peaks_test_chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_test_chroms \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

predict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --test-indices-file $all_peaks_test_chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_test_chroms \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads
    

echo $( timestamp ): "Calculating the AUPRC and AUROC metrics ..."

echo $( timestamp ): "
python /my_scripts/tf-atlas-pipeline/anvil/modeling/auprc_auroc_calculations.py \\
    --h5_file $predictions_dir_all_peaks_test_chroms/${experiment}_split000_predictions.h5 \\
    --output_dir $predictions_dir_all_peaks_test_chroms \\
    --peak_file ${data_dir}/${experiment}_peaks.bed \\
    --neg_file ${data_dir}/${experiment}_background_regions.bed \\
    --output_len 1000 \\
    --chroms $test_chromosome" | tee -a $logfile 

python /my_scripts/tf-atlas-pipeline/anvil/modeling/auprc_auroc_calculations.py \
    --h5_file $predictions_dir_all_peaks_test_chroms/${experiment}_split000_predictions.h5 \
    --output_dir $predictions_dir_all_peaks_test_chroms \
    --peak_file ${data_dir}/${experiment}_peaks.bed \
    --neg_file ${data_dir}/${experiment}_background_regions.bed \
    --output_len 1000 \
    --chroms $test_chromosome
    
echo $( timestamp ): "
predict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --test-indices-file $all_peaks_test_chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_test_chroms_wo_bias \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads\\
    --set-bias-as-zero" | tee -a $logfile 

predict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --test-indices-file $all_peaks_test_chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_test_chroms_wo_bias \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads \
    --set-bias-as-zero
    
echo $( timestamp ): "Calculating the AUPRC and AUROC metrics without bias..."

echo $( timestamp ): "
python /my_scripts/tf-atlas-pipeline/anvil/modeling/auprc_auroc_calculations.py \\
    --h5_file $predictions_dir_all_peaks_test_chroms_wo_bias/${experiment}_split000_predictions.h5 \\
    --output_dir $predictions_dir_all_peaks_test_chroms_wo_bias \\
    --peak_file ${data_dir}/${experiment}_peaks.bed \\
    --neg_file ${data_dir}/${experiment}_background_regions.bed \\
    --output_len 1000 \\
    --chroms $test_chromosome" | tee -a $logfile 

python /my_scripts/tf-atlas-pipeline/anvil/modeling/auprc_auroc_calculations.py \
    --h5_file $predictions_dir_all_peaks_test_chroms_wo_bias/${experiment}_split000_predictions.h5 \
    --output_dir $predictions_dir_all_peaks_test_chroms_wo_bias \
    --peak_file ${data_dir}/${experiment}_peaks.bed \
    --neg_file ${data_dir}/${experiment}_background_regions.bed \
    --output_len 1000 \
    --chroms $test_chromosome


echo $( timestamp ): "
predict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_all_chromosome \\
    --test-indices-file $all_peaks_all_chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_all_chroms \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

predict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_all_chromosome \
    --test-indices-file $all_peaks_all_chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_all_chroms \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads


# modify the testing_input json for prediction
cp $project_dir/testing_input.json $project_dir/testing_input_peaks.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_peaks.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_peaks.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/peaks/g" $project_dir/testing_input_peaks.json 
sed -i -e "s/<test_loci>/peaks/g" $project_dir/testing_input_peaks.json | tee -a $logfile



echo $( timestamp ): "
predict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --test-indices-file $test_peaks_test_chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_test_chroms \\
    --input-data $project_dir/testing_input_peaks.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

predict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --test-indices-file $test_peaks_test_chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_test_chroms \
    --input-data $project_dir/testing_input_peaks.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads
    
    
echo $( timestamp ): "
predict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --test-indices-file $test_peaks_test_chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_test_chroms_wo_bias \\
    --input-data $project_dir/testing_input_peaks.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads \\
    --set-bias-as-zero" | tee -a $logfile 

predict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --test-indices-file $test_peaks_test_chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_test_chroms_wo_bias \
    --input-data $project_dir/testing_input_peaks.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads \
    --set-bias-as-zero

echo $( timestamp ): "
predict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_all_chromosome \\
    --test-indices-file $test_peaks_all_chroms_indices_file \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_all_chroms \\
    --input-data $project_dir/testing_input_peaks.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

predict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_all_chromosome \
    --test-indices-file $test_peaks_all_chroms_indices_file \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_all_chroms \
    --input-data $project_dir/testing_input_peaks.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads

