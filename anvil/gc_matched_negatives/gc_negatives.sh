#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}


experiment=$1
reference_file=$2
reference_file_index=$3
reference_gc_stride_1000_flank_size_1057=$4
peaks=$5
chroms_sizes=$6
valid_chroms=$7

mkdir /project
project_dir=/project

# create the log file
logfile=$project_dir/${1}_gc_matched_negatives.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# copy down inliers bed file and reference files


echo $( timestamp ): "cp" $peaks ${data_dir}/${1}_inliers.bed.gz |\
tee -a $logfile 

cp $peaks ${data_dir}/${1}_inliers.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${1}_inliers.bed.gz |\
tee -a $logfile 

gunzip ${data_dir}/${1}_inliers.bed.gz

echo $( timestamp ): "cat ${1}_inliers.bed | awk '{print \$1}' | sort | uniq" |\
tee -a $logfile 

cat ${1}_inliers.bed | awk '{print $1}' | sort | uniq

if [[ -n "${valid_chroms}" ]];then
    echo "valid_chroms variable set"
    if [[ $valid_chroms!='' ]];then
        grep -f ${valid_chroms} ${data_dir}/${1}_inliers.bed > ${data_dir}/${1}_inliers_filtered.bed
        mv ${data_dir}/${1}_inliers_filtered.bed ${data_dir}/${1}_inliers.bed
    fi
fi


# after filtering if fitering was done

echo $( timestamp ): "cat ${1}_inliers.bed | awk '{print \$1}' | sort | uniq" |\
tee -a $logfile 

cat ${1}_inliers.bed | awk '{print $1}' | sort | uniq



# copy down data and reference

echo $( timestamp ): "cp" $reference_gc_stride_1000_flank_size_1057 ${reference_dir}/genomewide_gc_stride_1000_flank_size_1057.bed |\
tee -a $logfile 

echo $( timestamp ): "cp" $reference_file ${reference_dir}/genome.fa | \
tee -a $logfile 

echo $( timestamp ): "cp" $reference_file_index ${reference_dir}/genome.fa.fai |\
tee -a $logfile 

echo $( timestamp ): "cp" $chroms_sizes ${reference_dir}/chroms.sizes |\
tee -a $logfile 

cp $reference_file $reference_dir/genome.fa
cp $reference_file_index $reference_dir/genome.fa.fai

cp $reference_gc_stride_1000_flank_size_1057 ${reference_dir}/genomewide_gc_stride_1000_flank_size_1057.bed
cp $chroms_sizes ${reference_dir}/chroms.sizes



echo $( timestamp ): "
python get_gc_content.py \\
       --input_bed $data_dir/${1}_inliers.bed \\
       --ref_fasta $reference_dir/genome.fa \\
       --out_prefix $data_dir/$experiment.gc.bed \\
       --chroms_sizes ${reference_dir}/chroms.sizes \\
       --flank_size 1057" | tee -a $logfile 

python get_gc_content.py \
       --input_bed $data_dir/${1}_inliers.bed \
       --ref_fasta $reference_dir/genome.fa \
       --out_prefix $data_dir/$experiment.gc.bed \
       --chroms_sizes ${reference_dir}/chroms.sizes \
       --flank_size 1057

echo $( timestamp ): "
bedtools intersect -v -a \\
    $reference_dir/genomewide_gc_stride_1000_flank_size_1057.bed \\
    -b $data_dir/${1}_inliers.bed > $data_dir/${experiment}.tsv" | \
    tee -a $logfile 

bedtools intersect -v -a \
$reference_dir/genomewide_gc_stride_1000_flank_size_1057.bed \
-b $data_dir/${1}_inliers.bed > $data_dir/${experiment}.tsv

echo $( timestamp ): "
python get_gc_matched_negatives.py \\
        --candidate_negatives $data_dir/${experiment}.tsv \\
        --foreground_gc_bed  $data_dir/$experiment.gc.bed \\
        --output_prefix $data_dir/${experiment}_negatives \\
        --neg_to_pos_ratio_train 4" \\ | tee -a $logfile 

python get_gc_matched_negatives.py \
        --candidate_negatives $data_dir/${experiment}.tsv \
        --foreground_gc_bed  $data_dir/$experiment.gc.bed \
        --output_prefix $data_dir/${experiment}_negatives \
        --neg_to_pos_ratio_train 4


# also export the negatives only file
echo $( timestamp ): "mv" $data_dir/${experiment}_negatives.bed \
    $data_dir/gc_neg_only.bed  | tee -a $logfile 

mv $data_dir/${experiment}_negatives.bed $data_dir/gc_neg_only.bed

mv $data_dir/${experiment}_negatives_compared_with_foreground.png $data_dir/gc_distribution.png

