#!/bin/bash

experiment=$1
round=$2
fold=$3
shap_dir=$4
max_seqlets=$5
modisco_dir=$6

##modisco

if ! [[ -d /scratch/users/vir/$round/$fold/${experiment} ]]; 
then
    mkdir -p /scratch/users/vir/$round/$fold/${experiment}

fi


echo "singularity run /oak/stanford/groups/akundaje/vir/tfatlas/docker_images/vivekramalingam_tf-atlas_dev_modisco_lite.sif bash /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco_lite/modisco_pipeline.sh" ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/$round/$fold/${experiment}

singularity run /oak/stanford/groups/akundaje/vir/tfatlas/docker_images/vivekramalingam_tf-atlas_dev_modisco_lite.sif bash /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco_lite/modisco_pipeline.sh ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/$round/$fold/${experiment}

echo "copying all files to cromwell_root folder"

cp -r /scratch/users/vir/$round/$fold/${experiment}/modisco_profile/* $modisco_dir/profile
cp -r /scratch/users/vir/$round/$fold/${experiment}/modisco_counts/* $modisco_dir/counts

if [ -f $oak_dir/modisco/$round/$fold/$experiment/counts/modisco_results.h5 ] && [ -f $oak_dir/modisco/$round/$fold/$experiment/profile/modisco_results.h5 ];
then
printf "$experiment success\n"
else
echo "$experiment failed\n" >> /oak/stanford/groups/akundaje/vir/tfatlas/modisco/error/$round/$fold/failed_experiments.txt
fi

rm -rf /scratch/users/vir/$experiment
