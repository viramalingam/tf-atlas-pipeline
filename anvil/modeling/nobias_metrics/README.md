# nobias_metrics

How much of a released ENCODE BPNet model's performance comes from its bias (control) track:
the model's metrics with the bias and with the bias set to zero, probes on the frozen model, and
bias-only baselines, for one experiment and one fold per run. Modelled on `../au_metrics.{wdl,sh}`:
same docker (`vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1`), inputs, `/project` layout and
`bpnet-predict` call, and the binary metrics come from the old `auprc_auroc_calculations.py` (copy
here, plus `--score`). Developed in `/oak/stanford/groups/akundaje/vir/tfatlas/metrics/recalculate_nobias`
(Sherlock / kali runs of the same scripts over the 2614 released experiments).

## Metrics

Every score gets AUPRC, AUROC (test peaks vs GC negatives with ambiguous IDR-ranked peaks
removed; chance = positive fraction) and Pearson / Spearman of predicted vs observed log total
counts (test peaks; test peaks + all GC negatives), on the fold's test chromosomes.

| score | sequence | bias | readout |
|---|---|---|---|
| model, with bias | real | the region's control | released model |
| model, bias = 0 | real | zero | released model |
| linear probe, bias = 0 | real (64 frozen trunk features) | none | probe trained on the training chromosomes |
| linear probe, with bias | real (64 features) | log control counts | probe |
| control counts only | none | the region's control | model's bias weight x log control counts |
| shuffled sequence, same bias | dinucleotide shuffle of the region | the region's control | released model |
| shuffled sequence, bias = 0 | the same shuffles | zero | released model |
| label shuffle, model, bias with label / bias = 0 | real, stays | moves with the permuted label / zero | released model's count layer |
| label shuffle, linear probe, with bias / bias = 0 | real features, stay | moves with the permuted label / none | probe retrained on permuted labels |

Probes (probe_fit.py version 2): linear only -- logistic regression on standardised features
(binary) and least squares on the raw features (counts). Version 1 also had dense probes
(dropped in `nobias_metrics-v0.3.0`) and standardised the counts features: a trunk channel that
is zero on every training region but fires on a few test ones was then amplified ~1e6x and could
take a large coefficient, collapsing the counts Pearson. Label shuffling: 100 permutations for
the model rows; within-split shuffles for the probes.

## Training with bias = 0

`run_modelling_bias0.wdl` trains one fold model with the release pipeline and the bias set to
zero: it is the release `../run_modelling.wdl` (tf-atlas-pipeline `v2.0.0-rc.1`: cloned code,
`modelling_pipeline.sh`, docker `gcp-modeling_v2.0.0-rc.1`, memory, disk) with only the changes
needed on Terra now -- outputs copied to the task working directory (GCP Batch), `gpuType`
(default T4; K80s are retired), `zones` (one region) and `memory_gb` (default 32 as in the
release; large experiments can run out of memory in the all-chromosome predictions) inputs,
NVIDIA driver 535. The bias is zero through the inputs: the training / testing input jsons (`training_input_gc_1by3.json` /
`testing_input.json` of the release with the bias sources pointed at
`zero_control_{plus,minus}.bigWig`, all-zero tracks over hg38 stored as 10 kb intervals: with one
interval per chromosome, pyBigWig reads walk the whole chromosome and training runs ~37x slower) and those two bigWigs in place of
the experiment's control in `bigwigs`. The architecture is the released one with every bias input
zero; training settings as the release (`bpnet_params_gap_mse.json`, the fold's
`split_<f>_encode_fold.json`, learning rate 0.001).

## Affinity distillation on gcPBM

`gcpbm_affinity.wdl` scores one experiment's fold-0 released model and its bias = 0 trained model
(`run_modelling_bias0.wdl`) on in vitro gcPBM probes (affinity distillation, Alexandari et al.
2023): each 36 bp probe replaces the centre of a 2114 bp background (zero-based [1039, 1075)), and
the score is the mean over backgrounds of the change in log counts (the counts head's scalar
output, averaged over the sequence and its reverse complement, every bias input zero). The
backgrounds, the same for both models, are `n_peak_backgrounds` of the experiment's own peaks
(all chromosomes, summit-centred), dinucleotide shuffled, each followed by its reverse complement;
the first N peaks of a larger panel are exactly the N-peak panel. Metrics: Pearson
and Spearman against the measured intensity, on all probes and on non-negative-control probes. The
counts output is a linear layer on [sequence trunk, bias], so these scores are the same for the
released model with its bias or with the bias set to zero; every run checks that on the model
graph and numerically and fails otherwise. `affinity_distillation.py` is the Keras port of the
torch engine in `tfatlas/analysis/syntax_analysis/paralog_specificity/lib/bpnet_engine.py`
(validated against it: GABPA HepG2, 5 folds, Pearson 0.7506 for both).

## Files

- `nobias_metrics.wdl`: Terra workflow; clones this repository at the tag pinned in its command.
- `run_modelling_bias0.wdl`: release-pipeline training of one fold model with bias = 0 (above).
- `make_zero_control_bigwig.py`: builds the all-zero control bigWigs (10 kb tiles) used by it.
- `gcpbm_affinity.wdl`, `gcpbm_affinity.sh`, `affinity_distillation.py`: affinity distillation on
  gcPBM (above); the driver checks its inputs (one model tar per list, different tars, same splits).
- `nobias_metrics.sh`: driver (positional arguments 1-15 as `au_metrics.sh`, then fold,
  run_probes_and_baselines). Steps: ambiguous-peak removal (bedtools), `bpnet-predict` with bias
  and with `--set-bias-as-zero`, then the scripts below; a failed step fails the task.
- `metrics.py` (model rows), `probe_features.py`, `probe_fit.py`, `shuffled_background.py`,
  `label_shuffle.py`, `control_only.py`, `collect_metrics.py` (long table + one file per value),
  `old_script.py` + `auprc_auroc_calculations.py`, `nobias_paths.py` (paths, from `NOBIAS_*`).

## Outputs

`nobias_metrics_tsv` (every score x metric), `metrics_per_model_tar` (per-step TSVs),
`predictions_wo_bias_h5` (only with `save_predictions`), and one Float per value:
`<metric><tag>`, metric in `auprc`, `auroc`, `pearson`, `spearman`, `pearson_all_peaks`,
`spearman_all_peaks`; tag `""` (model, with bias), `_wo_bias`, `_linear_probe(_wo_bias)`,
`_control_only`, `_shuffled_sequence(_wo_bias)`, `_label_shuffle(_wo_bias)`,
`_label_shuffle_linear_probe(_wo_bias)`; plus `auprc_baseline` and `probe_version` (2: linear probes,
counts least squares on raw features; 68 Floats).

`gcpbm_affinity.wdl`: `scores_tsv` (per probe: the library's columns, `ad_<model>`, `sd_<model>`),
`metrics_tsv`, `check_json` (versions, hashes, checks), `deltas_npz` (probe x background deltas),
`peaks_panel_fa`, `log`, and 9 Floats: `<metric>_<model>` with
metric `pearson_all`, `spearman_all`, `pearson_nonnegctrl`, `spearman_nonnegctrl` and model `released`
or `bias0`, plus `bias_check_max_abs_delta_difference`.
