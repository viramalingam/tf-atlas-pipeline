#!/bin/bash
#
# BPNet performance with the bias (control) tracks set to zero vs with the
# real bias, for one experiment and one fold, on AnVIL / Terra. Modelled on
# anvil/modeling/au_metrics.sh: same inputs, /project layout and bpnet-predict
# call, plus
#   - a second bpnet-predict with --set-bias-as-zero
#   - predictions on peaks + ALL GC negatives (EXP_combined.bed): counts
#     Pearson / Spearman use peaks and peaks + all negatives; the binary
#     metrics drop negatives overlapping IDR ranked (ambiguous) peaks, as the
#     auprc_idr_removed recalculation did (bedtools intersect -v)
#   - auprc_auroc_calculations.py (the old script, --score total: log of total
#     predicted counts over both strands) for both predictions
#   - optionally the probe and baseline analyses (probe_features.py,
#     shuffled_background.py, probe_fit.py, label_shuffle.py, control_only.py)
# Results: $project_dir/nobias_outputs/ (nobias_metrics.tsv + one-number .txt
# files read by nobias_metrics.wdl), per-model TSVs in metrics_per_model.tar.
#
# Positional arguments (1-15 as au_metrics.sh):
#   experiment model(,-separated) testing_input_json splits_json reference_file
#   reference_file_index chrom_sizes chroms_txt bigwigs(,-separated) peaks
#   background_regions reverse_complement_average input_seq_len output_len
#   exclude_background_regions fold run_probes_and_baselines

function timestamp {
    # Function to get the current time with the new line character
    # removed

    # current time
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
model=$2
testing_input_json=$3
splits_json=$4
reference_file=$5
reference_file_index=$6
chrom_sizes=$7
chroms_txt=$8
bigwigs=${9}
peaks=${10}
background_regions=${11}
reverse_complement_average=${12}
input_seq_len=${13}
output_len=${14}
exclude_background_regions=${15}
fold=${16}
run_probes_and_baselines=${17:-true}

echo $experiment
echo $model
echo $testing_input_json
echo $splits_json
echo $reference_file
echo $reference_file_index
echo $chrom_sizes
echo $chroms_txt
echo $bigwigs
echo $peaks
echo $background_regions
echo $reverse_complement_average
echo $exclude_background_regions
echo $fold
echo $run_probes_and_baselines

# overridable only to test outside the container
project_dir=${PROJECT_DIR:-/project}
scripts_dir=${SCRIPTS_DIR:-$(dirname "$(readlink -f "$0")")}
mkdir -p $project_dir

# create the log file
logfile=$project_dir/${1}_nobias_metrics.log
touch $logfile

# create the data directory
data_dir=$project_dir/data
echo $( timestamp ): "mkdir" $data_dir | tee -a $logfile
mkdir -p $data_dir

# create the reference directory
reference_dir=$project_dir/reference
echo $( timestamp ): "mkdir" $reference_dir | tee -a $logfile
mkdir -p $reference_dir

# create the model directory
model_dir=$project_dir/model
echo $( timestamp ): "mkdir" $model_dir | tee -a $logfile
mkdir -p $model_dir

# create the predictions directories (peaks + all GC negatives, test chromosomes)
predictions_dir_all_peaks_test_chroms=$project_dir/predictions_and_metrics_all_peaks_test_chroms
predictions_dir_all_peaks_test_chroms_wo_bias=$project_dir/predictions_and_metrics_all_peaks_test_chroms_wo_bias
echo $( timestamp ): "mkdir" $predictions_dir_all_peaks_test_chroms $predictions_dir_all_peaks_test_chroms_wo_bias | tee -a $logfile
mkdir -p $predictions_dir_all_peaks_test_chroms $predictions_dir_all_peaks_test_chroms_wo_bias


echo $( timestamp ): "cp" $reference_file ${reference_dir}/hg38.genome.fa | \
tee -a $logfile

echo $( timestamp ): "cp" $reference_file_index ${reference_dir}/hg38.genome.fa.fai |\
tee -a $logfile

echo $( timestamp ): "cp" $chrom_sizes ${reference_dir}/chrom.sizes |\
tee -a $logfile

echo $( timestamp ): "cp" $chroms_txt ${reference_dir}/hg38_chroms.txt |\
tee -a $logfile


# copy down data and reference

cp $reference_file $reference_dir/hg38.genome.fa
cp $reference_file_index $reference_dir/hg38.genome.fa.fai
cp $chrom_sizes $reference_dir/chrom.sizes
cp $chroms_txt $reference_dir/hg38_chroms.txt
ln -sf $reference_dir/chrom.sizes $reference_dir/hg38.chrom.sizes   # name the nobias scripts expect


# Step 1: Copy the bigwig, model and peak files

echo $bigwigs | sed 's/,/ /g' | xargs cp -t $data_dir/

echo $( timestamp ): "cp" $bigwigs ${data_dir}/ |\
tee -a $logfile


echo $model | sed 's/,/ /g' | xargs cp -t $model_dir/

echo $( timestamp ): "cp" $model ${model_dir}/ |\
tee -a $logfile

cd ${model_dir}

echo $( timestamp ): "tar -xvf" ${model_dir}/${1}_split000.tar |\
tee -a $logfile

tar -xvf ${model_dir}/${1}_split000.tar

cd -


echo $( timestamp ): "cp" $peaks ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile

cp $peaks ${data_dir}/${experiment}_peaks.bed.gz

echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_peaks.bed.gz |\
tee -a $logfile

gunzip -f ${data_dir}/${experiment}_peaks.bed.gz



echo $( timestamp ): "cp" $background_regions ${data_dir}/${experiment}_background_regions.bed.gz |\
tee -a $logfile

cp $background_regions ${data_dir}/${experiment}_background_regions.bed.gz


echo $( timestamp ): "gunzip" ${data_dir}/${experiment}_background_regions.bed.gz |\
tee -a $logfile

gunzip -f ${data_dir}/${experiment}_background_regions.bed.gz

# set ${data_dir}/${experiment}_background_regions.bed as $data_dir/${experiment}_background_regions_filtered.bed. Will be overwritten if exclude_background_regions is present

echo $( timestamp ):"cp" ${data_dir}/${experiment}_background_regions.bed $data_dir/${experiment}_background_regions_filtered.bed |\
tee -a $logfile

cp ${data_dir}/${experiment}_background_regions.bed $data_dir/${experiment}_background_regions_filtered.bed


# remove the exclude_background_regions bed file from the negative_regions list for auprc auroc calculations

if [[ -n "${exclude_background_regions}" ]];then

    if [[ ${exclude_background_regions} != '' ]];then

        echo $( timestamp ): "cp" $exclude_background_regions ${data_dir} | tee -a $logfile

        cp $exclude_background_regions ${data_dir}/exclude_background_regions.bed.gz

        echo $( timestamp ): "gunzip" ${data_dir}/exclude_background_regions.bed.gz |\
                tee -a $logfile

        gunzip -f ${data_dir}/exclude_background_regions.bed.gz


        echo $( timestamp ): "
        bedtools intersect -v -a ${data_dir}/${experiment}_background_regions.bed \\
            -b ${data_dir}/exclude_background_regions.bed > $data_dir/${experiment}_background_regions_filtered.bed" | \
            tee -a $logfile

        bedtools intersect -v -a ${data_dir}/${experiment}_background_regions.bed \
            -b ${data_dir}/exclude_background_regions.bed > $data_dir/${experiment}_background_regions_filtered.bed
    fi
fi



# predictions on peaks + ALL GC negatives: counts metrics use every negative;
# the binary metrics select the filtered (ambiguous-removed) ones at scoring time

echo $( timestamp ): "cat" ${data_dir}/${experiment}_peaks.bed ${data_dir}/${experiment}_background_regions.bed ">" ${data_dir}/${experiment}_combined.bed |\
tee -a $logfile

cat ${data_dir}/${experiment}_peaks.bed ${data_dir}/${experiment}_background_regions.bed > ${data_dir}/${experiment}_combined.bed


# cp input json template

echo $( timestamp ): "cp" $testing_input_json \
$project_dir/testing_input.json | tee -a $logfile
cp $testing_input_json $project_dir/testing_input.json


# cp splits json template
echo $( timestamp ): "cp" $splits_json \
$project_dir/splits.json | tee -a $logfile
cp $splits_json $project_dir/splits.json


#set threads based on number of peaks

if [ $(wc -l < ${data_dir}/${experiment}_peaks.bed) -lt 3000 ];then
    threads=1
else
    threads=4
fi


# modify the testing_input json for prediction
cp $project_dir/testing_input.json $project_dir/testing_input_all.json
echo  $( timestamp ): "sed -i -e" "s/<experiment>/$1/g" $project_dir/testing_input_all.json
sed -i -e "s/<experiment>/$1/g" $project_dir/testing_input_all.json | tee -a $logfile

echo  $( timestamp ): "sed -i -e" "s/<test_loci>/combined/g" $project_dir/testing_input_all.json
sed -i -e "s/<test_loci>/combined/g" $project_dir/testing_input_all.json | tee -a $logfile

# paths inside the json template are /project/...; point them at $project_dir
sed -i -e "s#/project/#${project_dir}/#g" $project_dir/testing_input_all.json



#get the test chromosome for chromosome wise training regime

if [[ -n "$(jq '.["0"]["test"] // empty' $project_dir/splits.json)" ]]; then

    test_chromosome=`jq '.["0"]["test"] | join(" ")' $project_dir/splits.json | sed 's/"//g'`

    echo 'test_chromosome=jq .["0"]["test"] | join(" ") $project_dir/splits.json | sed s/"//g'

else

    test_chromosome='None'

    echo "test_chromosome=$test_chromosome"

fi


# Step 2: bpnet-predict with the bias tracks, then with --set-bias-as-zero
# (as au_metrics.sh, without the profile bigWigs, which the metrics do not use)

for bias_mode in real zero; do

    if [ $bias_mode = real ]; then
        out_dir=$predictions_dir_all_peaks_test_chroms
        bias_flag=""
    else
        out_dir=$predictions_dir_all_peaks_test_chroms_wo_bias
        bias_flag="--set-bias-as-zero"
    fi

    echo $( timestamp ): "
    bpnet-predict \\
        --model $model_dir/${1}_split000 \\
        --chrom-sizes $reference_dir/chrom.sizes \\
        --chroms $test_chromosome \\
        --test-indices-file 'None' \\
        --reference-genome $reference_dir/hg38.genome.fa \\
        --output-dir $out_dir \\
        --input-data $project_dir/testing_input_all.json \\
        --sequence-generator-name BPNet \\
        --input-seq-len ${input_seq_len} \\
        --output-len ${output_len} \\
        --output-window-size ${output_len} \\
        --batch-size 1024 \\
        --threads $threads \\
        $(case ${reverse_complement_average} in (true) printf -- '--reverse-complement-average';; (false) ;; esac ) $bias_flag" | tee -a $logfile

    bpnet-predict \
        --model $model_dir/${1}_split000 \
        --chrom-sizes $reference_dir/chrom.sizes \
        --chroms $test_chromosome \
        --test-indices-file 'None' \
        --reference-genome $reference_dir/hg38.genome.fa \
        --output-dir $out_dir \
        --input-data $project_dir/testing_input_all.json \
        --sequence-generator-name BPNet \
        --input-seq-len ${input_seq_len} \
        --output-len ${output_len} \
        --output-window-size ${output_len} \
        --batch-size 1024 \
        --threads $threads \
        $(case ${reverse_complement_average} in (true) printf -- '--reverse-complement-average';; (false) ;; esac ) $bias_flag
done


# Step 3: lay the files out as the nobias scripts expect (tfatlas tree under $project_dir)

echo $( timestamp ): "linking inputs into the tfatlas layout for the nobias scripts" | tee -a $logfile

tfatlas_dir=$project_dir/tfatlas
fold_dir=$tfatlas_dir/models/release_run_1/fold${fold}/${experiment}
mkdir -p $fold_dir/${experiment}_model
ln -sf ${data_dir}/${experiment}_peaks.bed $fold_dir/${experiment}_peaks.bed
ln -sf ${data_dir}/${experiment}_background_regions.bed $fold_dir/${experiment}_background_regions.bed
ln -sf ${data_dir}/${experiment}_combined.bed $fold_dir/${experiment}_combined.bed
ln -sf $project_dir/splits.json $fold_dir/splits.json
ln -sfn $model_dir/${experiment}_split000 $fold_dir/${experiment}_model/${experiment}_split000

released_dir=$tfatlas_dir/prediction/prediction_all_regions_test_chroms/release_run_1/fold${fold}/${experiment}
mkdir -p $released_dir
ln -sf $predictions_dir_all_peaks_test_chroms/${experiment}_split000_predictions.h5 $released_dir/

neg_dir=$tfatlas_dir/metrics/recalculate_auprc/gc_negatives_ranked_idr_removed
mkdir -p $neg_dir
gzip -c $data_dir/${experiment}_background_regions_filtered.bed > $neg_dir/${experiment}_gc_neg_ranked_idr_removed.bed.gz

processed_dir=$project_dir/processed/${experiment}
mkdir -p $processed_dir
for s in plus minus control_plus control_minus; do
    ln -sf ${data_dir}/${experiment}_${s}.bigWig $processed_dir/${experiment}_${s}.bigWig
done

export NOBIAS_TFATLAS=$tfatlas_dir
export NOBIAS_REF=$reference_dir/hg38.genome.fa
export NOBIAS_PROCESSED=$project_dir/processed
export NOBIAS_SCRATCH=$project_dir/nobias
export NOBIAS_OUT=$project_dir/nobias/metrics_per_model
export HDF5_USE_FILE_LOCKING=FALSE
export NVIDIA_TF32_OVERRIDE=0    # FP32 on Ampere GPUs too (TF 2.4 enables TF32 there by default)
zero_dir=$NOBIAS_SCRATCH/predictions/zero/fold${fold}/${experiment}
mkdir -p $zero_dir $NOBIAS_OUT
ln -sf $predictions_dir_all_peaks_test_chroms_wo_bias/${experiment}_split000_predictions.h5 $zero_dir/


# Step 4: AUPRC / AUROC (old auprc_auroc_calculations.py, --score total) and
# counts Pearson / Spearman (total counts), with bias and with bias = 0

failed=""
step() {    # NAME COMMAND...: run, log, and record a failure (exit status, or "done: N jobs, K errors" with K > 0)
    local name=$1; shift
    echo $( timestamp ): "$*" | tee -a $logfile
    "$@" 2>&1 | tee $project_dir/step_$name.log | tee -a $logfile
    local rc=${PIPESTATUS[0]}
    if [ $rc != 0 ] || grep -qE "done: [0-9]+ jobs, [1-9][0-9]* errors" $project_dir/step_$name.log; then
        failed="$failed $name"; echo $( timestamp ): "FAILED: $name (exit $rc)" | tee -a $logfile
    fi
}

printf "%s %s real\n%s %s zero\n" ${experiment} ${fold} ${experiment} ${fold} > $project_dir/metrics_jobs.txt
step metrics python $scripts_dir/metrics.py --jobs $project_dir/metrics_jobs.txt --workers 2


# Step 5 (optional): probes on the frozen model and the baselines -- frozen-model
# features; shuffled sequence (every region on its dinucleotide shuffle, own bias
# and bias = 0); probes (seed 0); label shuffling; control counts only

ncpu=$(nproc)
gpu=${NOBIAS_GPU-0}    # GPU index for the Python steps; NOBIAS_GPU="" runs them on CPU (local tests)
if [ "${run_probes_and_baselines}" = "true" ]; then
    printf "%s %s\n" ${experiment} ${fold} > $project_dir/control_jobs.txt
    step probe_features python $scripts_dir/probe_features.py --experiment ${experiment} --gpu "$gpu" --folds ${fold}
    step shuffled_sequence python $scripts_dir/shuffled_background.py --experiment ${experiment} --fold ${fold} --gpu "$gpu" --procs $ncpu
    step probe_fit python $scripts_dir/probe_fit.py --experiment ${experiment} --fold ${fold} --threads $ncpu --seeds 0
    step label_shuffle python $scripts_dir/label_shuffle.py --jobs $project_dir/metrics_jobs.txt --workers 2
    step control_only python $scripts_dir/control_only.py --jobs $project_dir/control_jobs.txt --workers 1
fi


# Step 6: collect

step collect python $scripts_dir/collect_metrics.py --root $NOBIAS_OUT --experiment ${experiment} --fold ${fold} --out-dir $project_dir/nobias_outputs

tar -cf $project_dir/nobias_outputs/metrics_per_model.tar -C $project_dir/nobias metrics_per_model
cp $logfile $project_dir/nobias_outputs/
if [ -n "$failed" ]; then
    echo $( timestamp ): "failed steps:$failed" | tee -a $logfile
    exit 1
fi
