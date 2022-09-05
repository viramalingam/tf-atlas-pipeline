#!/bin/sh

experiment=$1
round=$2
fold=$3
oak_dir=$4

if ! [[ -d /scratch/users/vir/my_scripts ]]; 
then
    cd /scratch/users/vir/; rm -rf my_scripts; mkdir my_scripts
    cd /scratch/users/vir/my_scripts
    git clone --depth 1 --branch v1.6.5 https://github.com/viramalingam/tf-atlas-pipeline.git
    chmod -R 777 tf-atlas-pipeline
fi
cd /scratch/users/vir/my_scripts/tf-atlas-pipeline/sherlock/modisco/

if [ -f $oak_dir/shap/$round/$fold/$experiment/profile_scores.h5 ] && [ -f $oak_dir/shap/$round/$fold/$experiment/counts_scores.h5 ] ; then
    if [ -f $oak_dir/modisco/$round/$fold/$experiment/profile/modisco_results.h5 ] && [ -f $oak_dir/modisco/$round/$fold/$experiment/counts/modisco_results.h5 ] ; then
        echo "modisco run exists"
    else
        if ! [[ -d $oak_dir/modisco/$round/$experiment ]]; 
        then
            mkdir $oak_dir/modisco/$round/$fold/$experiment
            mkdir $oak_dir/modisco/$round/$fold/$experiment/counts
            mkdir $oak_dir/modisco/$round/$fold/$experiment/profile
        fi
        modisco_dir=$oak_dir/modisco/$round/$fold/$experiment
        

        sbatch --export=ALL --requeue \
            -J $experiment.modisco \
            -p akundaje,owners,normal \
            -t 1440 -c 10 --mem=32G \
            -o $modisco_dir/output_log.txt \
            -e $modisco_dir/error_log.txt \
            run_modisco.sh  $experiment ${round} $fold ${oak_dir}/shap/${round}/$fold/${experiment} 25000 $modisco_dir
    fi
else
    echo "do interpretation step first"
fi
