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
| linear / dense probe, bias = 0 | real (64 frozen trunk features) | none | probe trained on the training chromosomes |
| linear / dense probe, with bias | real (64 features) | log control counts | probe |
| control counts only | none | the region's control | model's bias weight x log control counts |
| shuffled sequence, same bias | dinucleotide shuffle of the region | the region's control | released model |
| shuffled sequence, bias = 0 | the same shuffles | zero | released model |
| label shuffle, model, bias with label / bias = 0 | real, stays | moves with the permuted label / zero | released model's count layer |
| label shuffle, linear / dense probe, with bias / bias = 0 | real features, stay | moves with the permuted label / none | probe retrained on permuted labels |

Probes: logistic loss (binary) or least squares / MSE on observed counts (counts); dense = one
hidden layer of 64 ReLU units, early stopping on the validation chromosomes; seed 0. Label
shuffling: 100 permutations for the model rows; within-split shuffles for the probes.

## Files

- `nobias_metrics.wdl`: Terra workflow; clones this repository at the tag pinned in its command.
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
`_dense_probe(_wo_bias)`, `_control_only`, `_shuffled_sequence(_wo_bias)`,
`_label_shuffle(_wo_bias)`, `_label_shuffle_linear_probe(_wo_bias)`,
`_label_shuffle_dense_probe(_wo_bias)`; plus `auprc_baseline`.
