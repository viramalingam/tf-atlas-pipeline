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
chroms_txt=$5
lambda=$6
window=$7
sqrt_transform=$8


echo $1 $2 $3 $4 $5 $6 $7 $8

echo 'mkdir project_dir'
project_dir=/${experiment}
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

finemo extract-regions-bpnet-h5 -c ${shap_h5} -o ${hits_dir}/regions_bw.npz -w ${window} -p ${hits_dir}/peaks.bed

echo $( timestamp ): "finemo extract-regions-bpnet-h5 -c" ${shap_h5} "-o" ${hits_dir}/regions_bw.npz "-w" ${window} "-p" ${hits_dir}/peaks.bed | tee -a $logfile

if [ "$sqrt_transform" == "True" ]; then
    finemo call-hits -l ${lambda} -r ${hits_dir}/regions_bw.npz -m ${modisco_h5} -p ${hits_dir}/peaks.bed -C ${chroms_txt} -o ${hits_dir} --compile --sqrt-transform
    echo $( timestamp ): "finemo call-hits -l" ${lambda} "-r" ${hits_dir}/regions_bw.npz "-m" ${modisco_h5} "-p" ${hits_dir}/peaks.bed "-C" ${chroms_txt} "-o" ${hits_dir} "--compile" "--sqrt-transform" | tee -a $logfile
else
    finemo call-hits -l ${lambda} -r ${hits_dir}/regions_bw.npz -m ${modisco_h5} -p ${hits_dir}/peaks.bed -C ${chroms_txt} -o ${hits_dir} --compile
    echo $( timestamp ): "finemo call-hits -l" ${lambda} "-r" ${hits_dir}/regions_bw.npz "-m" ${modisco_h5} "-p" ${hits_dir}/peaks.bed "-C" ${chroms_txt} "-o" ${hits_dir} "--compile" | tee -a $logfile
fi
finemo report -H ${hits_dir}/hits.tsv -r ${hits_dir}/regions_bw.npz -m ${modisco_h5} -p ${hits_dir}/peaks.bed -o ${hits_dir}/ -W ${window}
echo $( timestamp ): "finemo report -H" ${hits_dir}/hits.tsv "-r" ${hits_dir}/regions_bw.npz "-m" ${modisco_h5} "-p" ${hits_dir}/peaks.bed "-o" ${hits_dir}/ "-W" ${window} | tee -a $logfile