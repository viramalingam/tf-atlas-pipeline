#!/usr/bin/env python3
"""Frozen-model features for the probe.

For every peak (EXP_peaks.bed, label 1) and every GC negative
(EXP_background_regions.bed, label 0) of one experiment -- the regions of
EXP_combined.bed -- on all chromosomes, and for each of its 5 released fold
models (binary_set flags peaks + the negatives left after ambiguous-peak
removal, the binary-metrics set; counts use every region):

  features       main_global_avg_pooling output (64-d): the pooled output of
                 the dilated-conv trunk, i.e. exactly the input of the
                 model's own count head; averaged over forward and
                 reverse-complement input
  control_total  the model's counts-bias input for the region (log(control
                 reads + 1) per strand over the 1000-bp output window, then
                 the model's own logsumexp over strands) -- with-bias probe
  logcounts_zero / logcounts_real
                 the model's own RC-averaged log counts with bias = 0 / real
                 bias, recomputed from the count head, to check the
                 extraction against bpnet-predict
  obs_total      observed log(total reads over both strands + 1) in the
                 output window (the counts target; = true_logcounts of
                 bpnet-predict summed over strands)

--obs-only adds obs_total to existing feature files (CPU, no model).

Windows and sequence handling are those of bpnet's generator in test mode
(pyfaidx + bpnet.generators.sequtils): input [summit-1057, summit+1057),
output [summit-500, summit+500).

Usage:
    source /oak/stanford/groups/akundaje/vir/tfatlas/eval/src/env.sh
    PYTHONPATH=/oak/stanford/groups/akundaje/vir/tfatlas/eval/vendor/bpnet-refactor \
        $BPNET_PY probe_features.py --experiment ENCSR000EGN --gpu 0 [--folds 0 1 2 3 4]
"""

import argparse
import os
import sys
import time
from pathlib import Path

ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
ap.add_argument("--experiment", required=True)
ap.add_argument("--gpu", default="0")
ap.add_argument("--folds", nargs="+", type=int, default=[0, 1, 2, 3, 4])
ap.add_argument("--chunk", type=int, default=32768)
sys.path.insert(0, str(Path(__file__).resolve().parent))
from nobias_paths import FEAT_ROOT, NEG_DIR, PROCESSED, REF, RELEASE, TFATLAS  # noqa: E402,F401
ap.add_argument("--out-root", default=str(FEAT_ROOT))
ap.add_argument("--obs-only", action="store_true",
                help="only add obs_total to existing feature files")
a = ap.parse_args()
os.environ["CUDA_VISIBLE_DEVICES"] = str(a.gpu)
os.environ.setdefault("HDF5_USE_FILE_LOCKING", "FALSE")

import h5py
import numpy as np
import pandas as pd
import pyBigWig
import pyfaidx
import tensorflow as tf
# TF 2.4 runs convolutions / matmuls in TF32 on Ampere GPUs (A100, A40, RTX 3090) by
# default, which moves predictions by ~1e-3 vs the released (T4, FP32) ones; keep FP32.
tf.config.experimental.enable_tensor_float_32_execution(False)
from tensorflow.keras.models import Model, load_model

sys.path.insert(0, "/oak/stanford/groups/akundaje/vir/tfatlas/eval/src")
import bpnet.model.arch  # noqa: F401  (same bootstrap as bpnet-predict)
from bpnet.generators import sequtils

IN_FLANK, OUT_FLANK = 1057, 500


def regions(exp):
    cols = ["chrom", "start", "summit"]
    rd = lambda p: pd.read_csv(p, sep="\t", header=None, usecols=[0, 1, 9], names=cols)
    d = RELEASE / f"fold{a.folds[0]}" / exp      # region files are identical across folds
    pk = rd(d / f"{exp}_peaks.bed")
    ng = rd(d / f"{exp}_background_regions.bed")
    kept = rd(NEG_DIR / f"{exp}_gc_neg_ranked_idr_removed.bed.gz")
    pk["label"], ng["label"] = 1, 0
    r = pd.concat([pk, ng], ignore_index=True)
    r["pos"] = r.start + r.summit
    r = r.drop_duplicates(["chrom", "pos", "label"]).reset_index(drop=True)
    kept_keys = set(zip(kept.chrom.astype(str), kept.start + kept.summit))
    r["binary_set"] = (r.label == 1).values | np.fromiter(
        ((c, p) in kept_keys for c, p in zip(r.chrom.astype(str), r.pos)), bool, len(r))
    return r[["chrom", "pos", "label", "binary_set"]]


def window_sums(exp, r, kind):
    """Reads per strand over the 1000-bp output window (NaN = 0, as the generator)."""
    tag = "_control" if kind == "control" else ""
    per = np.zeros((len(r), 2))
    for j, s in enumerate(["plus", "minus"]):
        bw = pyBigWig.open(str(PROCESSED / exp / f"{exp}{tag}_{s}.bigWig"))
        per[:, j] = [np.nansum(bw.values(c, p - OUT_FLANK, p + OUT_FLANK))
                     for c, p in zip(r.chrom, r.pos)]
        bw.close()
    return per


def control_total(exp, r):
    """log(sum control + 1) per strand over the output window, then logsumexp."""
    per = np.log(window_sums(exp, r, "control") + 1)
    return np.logaddexp(per[:, 0], per[:, 1])


def obs_total(exp, r):
    """log(total observed reads over both strands + 1)."""
    return np.log(window_sums(exp, r, "signal").sum(1) + 1)


def add_obs_only(exp):
    files = [Path(a.out_root) / f"fold{f}" / f"{exp}.h5" for f in a.folds]
    with h5py.File(files[0], "r") as h:
        r = pd.DataFrame({"chrom": h["chrom"][()].astype(str), "pos": h["pos"][()]})
    obs = obs_total(exp, r).astype(np.float32)
    for p in files:
        with h5py.File(p, "r+") as h:
            assert np.array_equal(h["pos"][()], r.pos.values), f"region order differs in {p}"
            if "obs_total" in h:
                del h["obs_total"]
            h["obs_total"] = obs
    print(f"{exp}: obs_total added to {len(files)} files ({len(r)} regions)")


def main():
    exp = a.experiment
    t0 = time.time()
    if a.obs_only:
        return add_obs_only(exp)
    r = regions(exp)
    fasta = pyfaidx.Fasta(str(REF))
    chrom_len = {k: len(v) for k, v in fasta.items()}
    ok = np.array([p - IN_FLANK >= 0 and p + IN_FLANK <= chrom_len.get(c, -1)
                   for c, p in zip(r.chrom, r.pos)])
    if (~ok).sum():
        print(f"dropping {(~ok).sum()} regions whose input window leaves the chromosome")
    r = r[ok].reset_index(drop=True)
    ctrl = control_total(exp, r)
    obs = obs_total(exp, r)
    print(f"{exp}: {len(r)} regions ({r.label.sum()} peaks, {int(r.binary_set.sum())} in the binary set), "
          f"control + signal done in {time.time()-t0:.0f}s")

    models = {}
    for f in a.folds:
        m = load_model(str(RELEASE / f"fold{f}" / exp / f"{exp}_model" / f"{exp}_split000"),
                       compile=False)
        sub = Model(m.get_layer("sequence").input,
                    [m.get_layer("main_global_avg_pooling").output,
                     m.get_layer("main_counts_head").output])
        w, b = m.get_layer("logcounts_predictions").get_weights()
        models[f] = (sub, w.ravel(), float(b[0]))

    n = len(r)
    feats = {f: np.zeros((n, 64), np.float32) for f in a.folds}
    head = {f: np.zeros(n, np.float32) for f in a.folds}
    for s in range(0, n, a.chunk):
        e = min(n, s + a.chunk)
        seqs = [fasta[c][p - IN_FLANK:p + IN_FLANK].seq.upper()
                for c, p in zip(r.chrom[s:e], r.pos[s:e])]
        X = sequtils.one_hot_encode(seqs, 2 * IN_FLANK).astype(np.float32)
        Xrc = X[:, ::-1, ::-1]
        if s == 0:  # the flip is bpnet's reverse_complement_of_sequences + one_hot_encode
            ref_rc = sequtils.one_hot_encode(
                sequtils.reverse_complement_of_sequences(seqs[:256]), 2 * IN_FLANK)
            assert np.array_equal(ref_rc, Xrc[:256]), "RC flip disagrees with bpnet"
        for f, (sub, w, b) in models.items():
            g_f, h_f = sub.predict(X, batch_size=1024)
            g_r, h_r = sub.predict(np.ascontiguousarray(Xrc), batch_size=1024)
            feats[f][s:e] = (g_f + g_r) / 2
            head[f][s:e] = ((h_f + h_r) / 2).ravel()
        print(f"  {e}/{n} regions, {time.time()-t0:.0f}s", flush=True)

    for f, (sub, w, b) in models.items():
        out = Path(a.out_root) / f"fold{f}"
        out.mkdir(parents=True, exist_ok=True)
        tmp = out / f"{exp}.h5.tmp"
        with h5py.File(tmp, "w") as h:
            h["chrom"] = r.chrom.values.astype("S8")
            h["pos"] = r.pos.values
            h["label"] = r.label.values.astype(np.int8)
            h["binary_set"] = r.binary_set.values.astype(np.int8)
            h["features"] = feats[f]
            h["count_head"] = head[f]
            h["control_total"] = ctrl.astype(np.float32)
            h["obs_total"] = obs.astype(np.float32)
            # bias = 0: counts_bias_input is 0 for both strands -> logsumexp = log 2
            h["logcounts_zero"] = w[0] * head[f] + w[1] * np.log(2.0) + b
            h["logcounts_real"] = w[0] * head[f] + w[1] * ctrl + b
            h.attrs["count_layer_weights"] = w
            h.attrs["count_layer_bias"] = b
        os.replace(tmp, out / f"{exp}.h5")
    print(f"{exp}: done in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
