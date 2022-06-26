#!/bin/bash

experiment=$1
shap_dir=$2
max_seqlets=$3
modisco_dir=$4

##modisco

echo "singularity run /oak/stanford/groups/akundaje/vir/tfatlas/docker_images/test.sif bash /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh" ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/$experiment/

singularity run /oak/stanford/groups/akundaje/vir/tfatlas/docker_images/test.sif bash /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/$experiment/

echo "copying all files to cromwell_root folder"

cp -r /project/modisco_profile $modisco_dir/profile
cp -r /project/modisco_counts $modisco_dir/counts

rm -rf /scratch/users/vir/$experiment
