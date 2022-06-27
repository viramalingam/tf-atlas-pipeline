#!/bin/bash

experiment=$1
shap_dir=$2
max_seqlets=$3
modisco_dir=$4

##modisco

echo "singularity run /oak/stanford/groups/akundaje/vir/tfatlas/docker_images/vivekramalingam_tf-atlas_gcp-modeling_v1.3.2.sif bash /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh" ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/${experiment}

singularity run /oak/stanford/groups/akundaje/vir/tfatlas/docker_images/tvivekramalingam_tf-atlas_gcp-modeling_v1.3.2.sif bash /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/${experiment}

echo "copying all files to cromwell_root folder"

cp -r /scratch/users/vir/${experiment}/modisco_profile/* $modisco_dir/profile
cp -r /scratch/users/vir/${experiment}/modisco_counts/* $modisco_dir/counts

if [ -f $oak_dir/modisco/$round/$experiment/counts/modisco_results.h5 ] && [ -f $oak_dir/modisco/$round/$experiment/profile/modisco_results.h5 ];
then
printf "$experiment success\n"
else
echo "$experiment failed\n" >> /oak/stanford/groups/akundaje/vir/tfatlas/modisco/error/failed_experiments.txt
fi

rm -rf /scratch/users/vir/$experiment
