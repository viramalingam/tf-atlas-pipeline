#!/bin/sh

experiment=$1
round=$2
oak_dir=$3

if [[ -d $output_dir/$experiment ]] ; then
    if [[ -f $oak_dir/shap/$round/$experiment/profile_scores.h5 ] && [ -f $oak_dir/shap/$round/$experiment/counts_scores.h5 ]] ; then
        if [[ -f $oak_dir/modisco/$round/$experiment/profile/modisco_results.h5 ] && [ -f $oak_dir/modisco/$round/$experiment/counts/modisco_results.h5 ]] ; then
            echo "modisco run exists"
        else
            mkdir $oak_dir/modisco/$round/$experiment
            modisco_dir=$oak_dir/modisco/$round/$experiment

            cores=10
            score_type=profile
            sbatch --export=ALL --requeue \
                -J $experiment.modisco \
                -p owners,akundaje \
                -t '12:00:00' -c 10 --mem=60G \
                -o $modisco_dir/output_log.txt \
                -e $modisco_dir/error_log.txt \
                run_modisco.sh  $experiment $oak_dir/$experiment/ 20000 $modisco_dir
        fi
    else
        echo "do interpretation step first"
    fi
else
    echo "skipping experiment directory creation"
    echo "do preprocessing first for dataset "$experiment
fi