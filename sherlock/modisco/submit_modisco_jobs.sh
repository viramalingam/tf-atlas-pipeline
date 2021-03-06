#!/bin/sh

experiment=$1
round=$2
oak_dir=$3

if ! [[ -d /scratch/users/vir/my_scripts ]]; 
then
    cd /scratch/users/vir/; rm -rf my_scripts; mkdir my_scripts
    cd /scratch/users/vir/my_scripts
    git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
    chmod -R 777 tf-atlas-pipeline
fi
cd /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/

if [ -f $oak_dir/shap/$round/$experiment/profile_scores.h5 ] && [ -f $oak_dir/shap/$round/$experiment/counts_scores.h5 ] ; then
    if [ -f $oak_dir/modisco/$round/$experiment/profile/modisco_results.h5 ] && [ -f $oak_dir/modisco/$round/$experiment/counts/modisco_results.h5 ] ; then
        echo "modisco run exists"
    else
        if ! [[ -d $oak_dir/modisco/$round/$experiment ]]; 
        then
            mkdir $oak_dir/modisco/$round/$experiment
            mkdir $oak_dir/modisco/$round/$experiment/counts
            mkdir $oak_dir/modisco/$round/$experiment/profile
        fi
        modisco_dir=$oak_dir/modisco/$round/$experiment
        
        
        
        cores=10
        score_type=profile
        sbatch --export=ALL --requeue \
            -J $experiment.modisco \
            -p akundaje,owners,normal \
            -t 1440 -c 10 --mem=32G \
            -o $modisco_dir/output_log.txt \
            -e $modisco_dir/error_log.txt \
            run_modisco.sh  $experiment ${oak_dir}/shap/${round}/${experiment} 25000 $modisco_dir
    fi
else
    echo "do interpretation step first"
fi