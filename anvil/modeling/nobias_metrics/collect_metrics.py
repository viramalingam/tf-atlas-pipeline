#!/usr/bin/env python3
"""Collect one experiment-fold's per-model TSVs (metrics.py, probe_fit.py,
shuffled_background.py, label_shuffle.py, control_only.py) into one long table, and write the
headline values as one-number text files for the AnVIL workflow's
read_float outputs (as auprc.txt / auroc.txt in the old au_metrics workflow).

    <out-dir>/nobias_metrics.tsv   experiment, fold, score, metric_type,
                                   regions_input, metric_value (probes: mean
                                   over seeds; label shuffling: mean over
                                   permutations, + positive fraction as auprc_baseline)
    <out-dir>/<name>.txt           one value each, e.g. auprc_wo_bias.txt,
                                   pearson_all_peaks_wo_bias.txt (NaN if absent)

Usage:
    python collect_metrics.py --root METRICS_PER_MODEL --experiment EXP --fold 0 --out-dir DIR
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

KEEP = ["score", "metric_type", "regions_input", "metric_value"]
AMBIG = "peaks_and_nonpeaks_ambiguous_removed"
# headline files: <metric><tag>.txt -> (score, metric_type, regions_input); every score x
# AUPRC, AUROC, Pearson / Spearman on peaks and on peaks + non-peaks, + the AUPRC chance level
SCORE_TAGS = [
    ("", "model, with bias"), ("_wo_bias", "model, bias = 0"),
    ("_linear_probe_wo_bias", "linear probe, bias = 0"), ("_dense_probe_wo_bias", "dense probe, bias = 0"),
    ("_linear_probe", "linear probe, with bias"), ("_dense_probe", "dense probe, with bias"),
    ("_control_only", "control counts only"),
    ("_shuffled_sequence", "shuffled sequence, same bias"), ("_shuffled_sequence_wo_bias", "shuffled sequence, bias = 0"),
    ("_label_shuffle", "label shuffle, model, bias with label"), ("_label_shuffle_wo_bias", "label shuffle, model, bias = 0"),
    ("_label_shuffle_linear_probe_wo_bias", "label shuffle, linear probe, bias = 0"),
    ("_label_shuffle_dense_probe_wo_bias", "label shuffle, dense probe, bias = 0"),
    ("_label_shuffle_linear_probe", "label shuffle, linear probe, with bias"),
    ("_label_shuffle_dense_probe", "label shuffle, dense probe, with bias"),
]
METRIC_NAMES = [("auprc", "auprc", None), ("auroc", "auroc", None),
                ("pearson", "pearsonr", "peaks"), ("spearman", "spearmanr", "peaks"),
                ("pearson_all_peaks", "pearsonr", "peaks_and_nonpeaks"),
                ("spearman_all_peaks", "spearmanr", "peaks_and_nonpeaks")]
FLOATS = {f"{m}{tag}": (score, mt, reg) for tag, score in SCORE_TAGS for m, mt, reg in METRIC_NAMES}
FLOATS["auprc_baseline"] = ("model, with bias", "auprc_baseline", AMBIG)


def read(root, rel, exp):
    p = Path(root) / rel / f"{exp}.tsv"
    return pd.read_csv(p, sep="\t") if p.exists() else pd.DataFrame()


def collect(root, exp, fold):
    parts = []
    for bias, name in (("real", "model, with bias"), ("zero", "model, bias = 0")):
        d = read(root, f"{bias}/fold{fold}", exp)
        if len(d):
            parts.append(d.assign(score=name)[KEEP])
    pr = read(root, f"probe/fold{fold}", exp)
    if len(pr):
        b = {"zero": "bias = 0", "real": "with bias"}
        pr["score"] = [(f"label shuffle, {h} probe, {b[i]}" if l == "shuffled" else f"{h} probe, {b[i]}")
                       for i, h, l in zip(pr.probe_inputs, pr["head"], pr.labels)]
        parts.append(pr.groupby(KEEP[:-1], as_index=False).metric_value.mean())
    co = read(root, f"control_only/fold{fold}", exp)
    if len(co):
        parts.append(co.assign(score="control counts only")[KEEP])
    for bias, name in (("real", "shuffled sequence, same bias"), ("zero", "shuffled sequence, bias = 0")):
        sb = read(root, f"shuffled_bg/{bias}/fold{fold}", exp)
        if len(sb):
            parts.append(sb.assign(score=name)[KEEP])
    for bias, name in (("real", "label shuffle, model, bias with label"), ("zero", "label shuffle, model, bias = 0")):
        ls = read(root, f"label_shuffle/{bias}/fold{fold}", exp)
        if len(ls):
            base = ls[ls.metric_type == "auprc"].assign(metric_type="auprc_baseline")
            base["metric_value"] = base.positive_fraction
            parts.append(pd.concat([ls.assign(metric_value=ls["mean"]), base]).assign(score=name)[KEEP])
    t = pd.concat(parts, ignore_index=True)
    t.insert(0, "fold", fold)
    t.insert(0, "experiment", exp)
    return t


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", required=True)
    ap.add_argument("--experiment", required=True)
    ap.add_argument("--fold", type=int, required=True)
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args()
    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    t = collect(a.root, a.experiment, a.fold)
    t.to_csv(out / "nobias_metrics.tsv", sep="\t", index=False)
    for name, (score, mt, reg) in FLOATS.items():
        m = (t.score == score) & (t.metric_type == mt)
        if reg is not None:
            m &= t.regions_input == reg
        v = t.loc[m, "metric_value"]
        x = float(v.iloc[0]) if len(v) else np.nan
        (out / f"{name}.txt").write_text("NaN\n" if np.isnan(x) else f"{x}\n")   # Cromwell read_float wants NaN
    print(f"{a.experiment} fold{a.fold}: {len(t)} rows, {len(FLOATS)} headline files -> {out}")


if __name__ == "__main__":
    main()
