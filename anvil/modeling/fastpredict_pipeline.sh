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
background_regions=${11}


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

echo $( timestamp ): "cp" $testing_input_json \
$project_dir/testing_input.json | tee -a $logfile 
cp $testing_input_json $project_dir/testing_input.json



# cp splits json template
echo $( timestamp ): "cp" $splits_json \
$project_dir/splits.json | tee -a $logfile 
cp $splits_json $project_dir/splits.json



ls /project/data/

#set threads based on number of peaks

if [ $(wc -l < ${data_dir}/${experiment}_peaks.bed) -lt 3500 ];then
    threads=1
else
    threads=2
fi

head ${data_dir}/${experiment}_peaks.bed


#get the test chromosome

echo 'test_chromosome=jq .["0"]["test"][0] $project_dir/splits.json | sed s/"//g'

test_chromosome=`jq '.["0"]["test"][0]' $project_dir/splits.json | sed 's/"//g'` 

# modify he input json for the testing


# modify the testing_input json for 
cp $project_dir/testing_input.json $project_dir/testing_input_all.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_all.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_all.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/combined/g" $project_dir/testing_input_all.json 
sed -i -e "s/<test_loci>/combined/g" $project_dir/testing_input_all.json | tee -a $logfile

free -g -c 10 | tee -a $logfile &

echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_test_chroms \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_test_chroms \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads



echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_all_chroms \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_all_chroms \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads


# modify the testing_input json for 
cp $project_dir/testing_input.json $project_dir/testing_input_peaks.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_peaks.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_peaks.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/peaks/g" $project_dir/testing_input_peaks.json 
sed -i -e "s/<test_loci>/peaks/g" $project_dir/testing_input_peaks.json | tee -a $logfile


echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_test_chroms \\
    --input-data $project_dir/testing_input_peaks.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_test_chroms \
    --input-data $project_dir/testing_input_peaks.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads


echo $( timestamp ): "
fastpredict \\
    --model $model_dir/${1}_split000.h5 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_test_peaks_all_chroms \\
    --input-data $project_dir/testing_input_peaks.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len 2114 \\
    --output-len 1000 \\
    --output-window-size 1000 \\
    --batch-size 64 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads" | tee -a $logfile 

fastpredict \
    --model $model_dir/${1}_split000.h5 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $(paste -s -d ' ' $reference_dir/hg38_chroms.txt) \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_test_peaks_all_chroms \
    --input-data $project_dir/testing_input_peaks.json \
    --sequence-generator-name BPNet \
    --input-seq-len 2114 \
    --output-len 1000 \
    --output-window-size 1000 \
    --batch-size 64 \
    --generate-predicted-profile-bigWigs \
    --threads $threads

# create necessary files to copy the predictions results to cromwell folder

tail -n 1 $predictions_dir_test_peaks_test_chroms/predict.log | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_test_peaks_test_chroms/spearman.txt
tail -n 2 $predictions_dir_test_peaks_test_chroms/predict.log | head -n 1 | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_test_peaks_test_chroms/pearson.txt
tail -n 7 $predictions_dir_test_peaks_test_chroms/predict.log | head -n 1 | awk '{print $NF}' > $predictions_dir_test_peaks_test_chroms/jsd.txt


tail -n 1 $predictions_dir_all_peaks_test_chroms/predict.log | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_all_peaks_test_chroms/spearman.txt
tail -n 2 $predictions_dir_all_peaks_test_chroms/predict.log | head -n 1 | awk '{a=$8;print (substr(a,2,6)+substr($9,1,6))/2}' > $predictions_dir_all_peaks_test_chroms/pearson.txt
tail -n 7 $predictions_dir_all_peaks_test_chroms/predict.log | head -n 1 | awk '{print $NF}' > $predictions_dir_all_peaks_test_chroms/jsd.txt

