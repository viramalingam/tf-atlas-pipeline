experiment=$1
shap=$2
max_seqlets=$3
modisco_dir=$4

##modisco

echo "run /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh" ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/$experiment/
/scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh ${experiment} ${shap_dir} ${max_seqlets} /scratch/users/vir/$experiment/

echo "copying all files to cromwell_root folder"

cp -r /project/modisco_profile $modisco_dir/profile
cp -r /project/modisco_counts $modisco_dir/counts

rm -rf /scratch/users/vir/$experiment
