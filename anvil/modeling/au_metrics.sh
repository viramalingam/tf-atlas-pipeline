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
reverse_complement_average=${12}
input_seq_len=${13}
output_len=${14}
exclude_background_regions=${15}


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
echo $background_regions
echo $reverse_complement_augmentation
echo $exclude_background_regions

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_au_metrics.log
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
predictions_dir_all_peaks_test_chroms=$project_dir/predictions_and_metrics_all_peaks_test_chroms
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_test_chroms| tee -a $logfile
mkdir $predictions_dir_all_peaks_test_chroms



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



echo $( timestamp ): "cp" $background_regions ${data_dir}/${experiment}_background_regions.bed.gz |\
tee -a $logfile 

cp $background_regions ${data_dir}/${experiment}_background_regions.bed.gz


echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_background_regions.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${experiment}_background_regions.bed.gz

# set ${data_dir}/${experiment}_background_regions.bed.gz as $data_dir/${experiment}_background_regions_filtered.bed. Will be overwrittenr if exclude_background_regions is present

echo $( timestamp ):"cp" ${data_dir}/${experiment}_background_regions.bed.gz $data_dir/${experiment}_background_regions_filtered.bed |\
tee -a $logfile 

cp ${data_dir}/${experiment}_background_regions.bed $data_dir/${experiment}_background_regions_filtered.bed


# remove the exclude_background_regions bed file from the negative_regions list for auprc auroc calculations

if [[ -n "${exclude_background_regions}" ]];then
    
    if [[ ${exclude_background_regions} != '' ]];then
     
        echo $( timestamp ): "cp" $exclude_background_regions ${data_dir} | tee -a $logfile 

        cp $exclude_background_regions ${data_dir}/exclude_background_regions.bed.gz

        echo $( timestamp ): "gunzip" ${data_dir}/exclude_background_regions.bed.gz |\
                tee -a $logfile 

        gunzip ${data_dir}/exclude_background_regions.bed.gz


        echo $( timestamp ): "
        bedtools intersect -v -a ${data_dir}/${experiment}_background_regions.bed \\
            -b ${data_dir}/exclude_background_regions.bed > $data_dir/${experiment}_background_regions_filtered.bed" | \
            tee -a $logfile 

        bedtools intersect -v -a ${data_dir}/${experiment}_background_regions.bed \
            -b ${data_dir}/exclude_background_regions.bed > $data_dir/${experiment}_background_regions_filtered.bed
    fi
fi




echo $( timestamp ): "cat" ${data_dir}/${experiment}_peaks.bed ${data_dir}/${experiment}_background_regions_filtered.bed ">" ${data_dir}/${experiment}_combined.bed |\
tee -a $logfile 

cat ${data_dir}/${experiment}_peaks.bed ${data_dir}/${experiment}_background_regions_filtered.bed > ${data_dir}/${experiment}_combined.bed


# cp input json template

echo $( timestamp ): "cp" $testing_input_json \
$project_dir/testing_input.json | tee -a $logfile 
cp $testing_input_json $project_dir/testing_input.json


# cp splits json template
echo $( timestamp ): "cp" $splits_json \
$project_dir/splits.json | tee -a $logfile 
cp $splits_json $project_dir/splits.json


#set threads based on number of peaks

if [ $(wc -l < ${data_dir}/${experiment}_peaks.bed) -lt 3000 ];then
    threads=1
else
    threads=4
fi


# modify the testing_input json for prediction
cp $project_dir/testing_input.json $project_dir/testing_input_all.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_all.json 
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_all.json | tee -a $logfile 

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/combined/g" $project_dir/testing_input_all.json 
sed -i -e "s/<test_loci>/combined/g" $project_dir/testing_input_all.json | tee -a $logfile



#get the test chromosome for chromosome wise training regime

if [[ -n "$(jq '.["0"]["test"] // empty' $project_dir/splits.json)" ]]; then 

    test_chromosome=`jq '.["0"]["test"] | join(" ")' $project_dir/splits.json | sed 's/"//g'`

    echo 'test_chromosome=jq .["0"]["test"] | join(" ") $project_dir/splits.json | sed s/"//g'

else
    
    test_chromosome='None'

    echo "test_chromosome=$test_chromosome"

fi



echo $( timestamp ): "
bpnet-predict \\
    --model $model_dir/${1}_split000 \\
    --chrom-sizes $reference_dir/chrom.sizes \\
    --chroms $test_chromosome \\
    --test-indices-file 'None' \\
    --reference-genome $reference_dir/hg38.genome.fa \\
    --output-dir $predictions_dir_all_peaks_test_chroms \\
    --input-data $project_dir/testing_input_all.json \\
    --sequence-generator-name BPNet \\
    --input-seq-len ${input_seq_len} \\
    --output-len ${output_len} \\
    --output-window-size ${output_len} \\
    --batch-size 1024 \\
    --generate-predicted-profile-bigWigs \\
    --threads $threads \\
    $(case ${reverse_complement_average} in (true) printf -- '--reverse-complement-average';; (false) ;; esac )" | tee -a $logfile 

bpnet-predict \
    --model $model_dir/${1}_split000 \
    --chrom-sizes $reference_dir/chrom.sizes \
    --chroms $test_chromosome \
    --test-indices-file 'None' \
    --reference-genome $reference_dir/hg38.genome.fa \
    --output-dir $predictions_dir_all_peaks_test_chroms \
    --input-data $project_dir/testing_input_all.json \
    --sequence-generator-name BPNet \
    --input-seq-len ${input_seq_len} \
    --output-len ${output_len} \
    --output-window-size ${output_len} \
    --batch-size 1024 \
    --generate-predicted-profile-bigWigs \
    --threads $threads \
    $(case ${reverse_complement_average} in (true) printf -- '--reverse-complement-average';; (false) ;; esac )
    

echo $( timestamp ): "Calculating the AUPRC and AUROC metrics ..."

echo $( timestamp ): "
python /my_scripts/tf-atlas-pipeline/anvil/modeling/auprc_auroc_calculations.py \\
    --h5_file $predictions_dir_all_peaks_test_chroms/${experiment}_split000_predictions.h5 \\
    --output_dir $predictions_dir_all_peaks_test_chroms \\
    --peak_file ${data_dir}/${experiment}_peaks.bed \\
    --neg_file ${data_dir}/${experiment}_background_regions_filtered.bed \\
    --output_len ${output_len} \\
    --chroms $test_chromosome" | tee -a $logfile 

python /my_scripts/tf-atlas-pipeline/anvil/modeling/auprc_auroc_calculations.py \
    --h5_file $predictions_dir_all_peaks_test_chroms/${experiment}_split000_predictions.h5 \
    --output_dir $predictions_dir_all_peaks_test_chroms \
    --peak_file ${data_dir}/${experiment}_peaks.bed \
    --neg_file ${data_dir}/${experiment}_background_regions_filtered.bed \
    --output_len ${output_len} \
    --chroms $test_chromosome