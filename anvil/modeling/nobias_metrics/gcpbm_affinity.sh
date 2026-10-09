#!/bin/bash
#
# Affinity distillation on gcPBM probes for one experiment (fold 0) on AnVIL / Terra:
# the released model and the model trained with bias = 0, scored by
# affinity_distillation.py on the same probes and backgrounds. Results go to
# $project_dir/gcpbm_outputs/ (scores.tsv.gz, metrics.tsv, check.json, deltas.npz,
# panel_peaks.fa and the one-number .txt files read by gcpbm_affinity.wdl).
#
# Positional arguments:
#   experiment model(,-separated: the release model files, with <EXP>_split000.tar,
#   <EXP>_peaks.bed and splits.json) model_bias0(,-separated: the bias = 0 training's
#   model files, with <EXP>_split000.tar) gcpbm_tsv gcpbm_column backgrounds_fa
#   n_background_windows(20, 50, 100 or 200) n_peak_backgrounds(> 0) reference_file
#   reference_file_index [probe_subset(> 0: a fixed random subset of probes, seed 0, for tests)]

set -euo pipefail

function timestamp {
    date +"%Y-%m-%d_%H-%M-%S" | tr -d '\n'
}

experiment=$1
model=$2
model_bias0=$3
gcpbm_tsv=$4
gcpbm_column=$5
backgrounds_fa=$6
n_background_windows=$7
n_peak_backgrounds=$8
reference_file=$9
reference_file_index=${10}
probe_subset=${11:-0}

project_dir=${PROJECT_DIR:-/project}
scripts_dir=${SCRIPTS_DIR:-$(dirname "$(readlink -f "$0")")}
out_dir=$project_dir/gcpbm_outputs
mkdir -p "$out_dir" "$project_dir/reference"
logfile=$out_dir/gcpbm_affinity.log
touch "$logfile"
log() { echo "$(timestamp): $*" | tee -a "$logfile"; }
fail() { log "ERROR: $*"; exit 1; }

log "experiment $experiment column $gcpbm_column windows $n_background_windows peaks $n_peak_backgrounds"
case "$n_background_windows" in
    20|50|100|200) ;;
    *) fail "n_background_windows must be 20, 50, 100 or 200, got '$n_background_windows'" ;;
esac
[[ "$n_peak_backgrounds" =~ ^[1-9][0-9]*$ ]] || fail "n_peak_backgrounds must be > 0, got '$n_peak_backgrounds'"
[[ "$probe_subset" =~ ^[0-9]+$ ]] || fail "probe_subset must be >= 0, got '$probe_subset'"

# exactly one file per pattern; the release model files carry the fold's peaks and splits
pick() {
    local hits
    hits=$(echo "$1" | tr ',' '\n' | grep -E "$2" || true)
    [ "$(echo "$hits" | grep -c .)" -eq 1 ] || fail "expected exactly one file matching $2 in $3, got: $(echo $hits)"
    [ -s "$hits" ] || fail "empty or missing: $hits"
    echo "$hits"
}
tar_r=$(pick "$model" "/${experiment}_split000\.tar$" model)
tar_t=$(pick "$model_bias0" "/${experiment}_split000\.tar$" model_bias0)
peaks=$(pick "$model" "/${experiment}_peaks\.bed$" model)
splits=$(pick "$model" "/splits\.json$" model)
[ "$(sha256sum < "$tar_r")" != "$(sha256sum < "$tar_t")" ] || fail "released and bias = 0 model tars are identical"
splits_t=$(echo "$model_bias0" | tr ',' '\n' | grep -E "/splits\.json$" || true)
if [ -n "$splits_t" ] && ! cmp -s "$splits" "$splits_t"; then
    fail "released and bias = 0 trainings used different splits.json"
fi

# reference next to its index (pyfaidx)
cp "$reference_file" "$project_dir/reference/hg38.genome.fa"
cp "$reference_file_index" "$project_dir/reference/hg38.genome.fa.fai"

export HDF5_USE_FILE_LOCKING=FALSE
export NVIDIA_TF32_OVERRIDE=0    # FP32 on Ampere and newer GPUs too
log "python affinity_distillation.py"
status=0
python "$scripts_dir/affinity_distillation.py" \
    --models "released=$tar_r" "bias0=$tar_t" \
    --probes "$gcpbm_tsv" --column "$gcpbm_column" \
    --backgrounds "$backgrounds_fa" --n-windows "$n_background_windows" \
    --peaks "$peaks" --splits "$splits" --fasta "$project_dir/reference/hg38.genome.fa" \
    --n-peak-backgrounds "$n_peak_backgrounds" \
    --probe-subset "$probe_subset" --probe-seed 0 \
    --check-n 64 --save-deltas npz --out-dir "$out_dir" \
    > "$project_dir/affinity_distillation.raw.log" 2>&1 || status=$?
# keep the log without TensorFlow's info / warning lines
grep -v -E "^20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9:.]+: [IW] " "$project_dir/affinity_distillation.raw.log" \
    | tee -a "$logfile" || true
rm -rf "$out_dir/_models"
[ "$status" -eq 0 ] || fail "affinity_distillation.py exited with $status"
[ -s "$out_dir/check.json" ] && [ -s "$out_dir/deltas.npz" ] || fail "outputs missing"
log done
