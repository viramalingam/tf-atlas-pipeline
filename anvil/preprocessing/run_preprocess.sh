#!/bin/bash


# import the utils script
source ./utils.sh

experiment=$1
encode_access_key=$2
encode_secret_key=$3
metadata_file_path=$4
chrom_sizes=$5

# create log file
logfile=$experiment.log
touch $logfile


# path to json file with pipeline params
pipeline_json="params_file.json"

# create pipeline params json
echo $( timestamp ): "
python \\
    create_pipeline_params_json.py \\
    $metadata_file_path \\
    $experiment \\
    $pipeline_json" | tee -a $logfile
    
python \
    create_pipeline_params_json.py \
    $metadata_file_path \
    $experiment \
    $pipeline_json
    



# get params from the pipleine json


assembly=`jq .assembly $pipeline_json | sed 's/"//g'`

unfiltered_alignments=`jq .unfiltered_alignments $pipeline_json | sed 's/"//g'`

unfiltered_alignments_md5sums=\
`jq .unfiltered_alignments_md5sums $pipeline_json | sed 's/"//g'`

alignments=`jq .alignments $pipeline_json | sed 's/"//g'`

alignments_md5sums=`jq .alignments_md5sums $pipeline_json | sed 's/"//g'`

control_unfiltered_alignments=\
`jq .control_unfiltered_alignments $pipeline_json | sed 's/"//g'`

control_unfiltered_alignments_md5sums=\
`jq .control_unfiltered_alignments_md5sums $pipeline_json | sed 's/"//g'`

control_alignments=`jq .control_alignments $pipeline_json | sed 's/"//g'`

control_alignments_md5sums=\
`jq .control_alignments_md5sums $pipeline_json | sed 's/"//g'`

peaks=`jq .peaks $pipeline_json | sed 's/"//g'`

peaks_md5sum=`jq .peaks_md5sum $pipeline_json | sed 's/"//g'`




# Step 0. Create all required directories and cp the files

dst_dir=$PWD/

# local reference files directory
reference_dir=${dst_dir}reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir $reference_dir

# directory to store downloaded files
downloads_dir=${dst_dir}downloads
echo $( timestamp ): "mkdir" $downloads_dir | tee -a $logfile
mkdir $downloads_dir

# directory to store intermediate preprocessing files
# (merged bams, bedGraphs)
intermediates_dir=${dst_dir}intermediates
echo $( timestamp ): "mkdir" $intermediates_dir | tee -a $logfile
mkdir $intermediates_dir

# directory to store bigWigs
bigWigs_dir=${dst_dir}bigWigs
echo $( timestamp ): "mkdir" $bigWigs_dir | tee -a $logfile
mkdir $bigWigs_dir



echo $( timestamp ): "cp" $chrom_sizes $reference_dir/chrom.sizes |\
tee -a $logfile 

cp $chrom_sizes $reference_dir/chrom.sizes


# Step 2. download bam files and peaks file

# 2.1 download unfiltered alignments bams
download_file "$unfiltered_alignments" "bam" \
"$unfiltered_alignments_md5sums" 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

# 2.2 download alignments bams
download_file "$alignments" "bam" "$alignments_md5sums" 1 $logfile \
$encode_access_key $encode_secret_key $downloads_dir


# 2.3 download control unfiltered alignmentsbams
download_file "$control_unfiltered_alignments" "bam" \
"$control_unfiltered_alignments_md5sums" 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir

# 2.4 download control alignments bams
download_file "$control_alignments" "bam" "$control_alignments_md5sums" 1 \
$logfile $encode_access_key $encode_secret_key $downloads_dir


# 2.5 download peaks file
download_file $peaks "bed.gz" $peaks_md5sum 1 $logfile $encode_access_key \
$encode_secret_key $downloads_dir


wait_for_jobs_to_finish "Download"

# Step 3. preprocess

# 3.1 preprocess experiment bams
./preprocessing.sh $experiment "$unfiltered_alignments" "$alignments" \
$downloads_dir $intermediates_dir $bigWigs_dir $stranded False $reference_dir \
$logfile &

echo $( timestamp ): [$!] "./preprocessing.sh" $experiment \
\"$unfiltered_alignments\" \"$alignments\" $downloads_dir $intermediates_dir \
$bigWigs_dir $stranded False $reference_dir $logfile  | tee -a $logfile

if [ "$has_control" = "True" ]
then
    # 3.2 preprocess experiment control bams
    ./preprocessing.sh $experiment "$control_unfiltered_alignments" \
    "$control_alignments" $downloads_dir $intermediates_dir $bigWigs_dir \
    $stranded True $reference_dir $logfile &
    
    echo $( timestamp ): [$!] "./preprocessing.sh" $experiment \
    \"$control_unfiltered_alignments\" \"$control_alignments\" $downloads_dir \
    $intermediates_dir $bigWigs_dir $stranded True $reference_dir $logfile | \
    tee -a $logfile
fi

wait_for_jobs_to_finish "Preprocessing"