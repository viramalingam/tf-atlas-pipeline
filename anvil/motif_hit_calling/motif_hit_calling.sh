#!/bin/bash

function timestamp {
    # Function to get the current time with the new line character
    # removed 
    
    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
modisco_h5=$2
peaks=$3
shap_h5=$4
match_type=$5
shap_h5_type=$6
alpha=$7
window=$8
chroms_txt=$9

echo $1 $2 $3 $4 $5 $6 $7 $8 $9

echo 'mkdir project_dir'
project_dir=/project
mkdir $project_dir

# create the log file
logfile=$project_dir/${1}_hit_calling.log
touch $logfile


# create the reference directory
hits_dir=$project_dir/hits
echo $( timestamp ): "mkdir" $hits_dir | tee -a $logfile
mkdir $hits_dir



echo $( timestamp ): "zcat" ${peaks} ">" ${hits_dir}/peaks.bed

zcat ${peaks} > ${hits_dir}/peaks.bed

zcat ${peaks} | head

finemo extract-regions-h5 -c ${shap_h5} -o ${hits_dir}/regions_bw.npz -w ${window} -t ${shap_h5_type}

finemo call-hits -a ${alpha} -M ${match_type} -r ${hits_dir}/regions_bw.npz -m ${modisco_h5} -p ${hits_dir}/peaks.bed -C ${chroms_txt} -o ${hits_dir}

finemo report -H /project/${experiment}/hits.tsv -r /project/${experiment}/regions_bw.npz -m ${modisco_h5} -p ${hits_dir}/peaks.bed -o /project/${experiment}/ -W ${window}