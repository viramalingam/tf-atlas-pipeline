experiment=$1
shap=$2
max_seqlets=$3
modisco_dir=$4

cd /scratch/users/vir/; rm -rf my_scripts; mkdir my_scripts
cd /scratch/users/vir/my_scripts
git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
chmod -R 777 tf-atlas-pipeline
cd tf-atlas-pipeline/anvil/modisco/

##modisco

echo "run /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh" ${experiment} ${shap_dir} ${max_seqlets}
/scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/modisco_pipeline.sh ${experiment} ${shap_dir} ${max_seqlets}

echo "copying all files to cromwell_root folder"

cp -r /project/modisco_profile $modisco_dir/profile
cp -r /project/modisco_counts $modisco_dir/counts

rm -rf /scratch/users/vir/$experiment
