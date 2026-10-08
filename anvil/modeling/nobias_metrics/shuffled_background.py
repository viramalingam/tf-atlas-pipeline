#!/usr/bin/env python3
"""Shuffled-sequence baseline (GC-matched by construction: dinucleotide
shuffles) for AUPRC/AUROC and counts Pearson/Spearman, with each region's own
bias and with bias = 0.

Every test-chromosome region of a released model -- peaks and GC negatives --
has its 2114-bp input replaced by a dinucleotide shuffle (bpnet's own
dinuc_shuffle: GC and dinucleotide content match the region; 4 shuffles per
peak, 1 per GC negative, per-region seeds) and is scored by the model with the
SAME bias inputs as the region (its control profile over the output window,
both strands, and the counts bias input derived from it), or with every bias
input zero; forward and reverse complement averaged as in predict.py.

AUPRC/AUROC: the old auprc_auroc_calculations.py on the same regions and
labels as the model's own binary metrics (test peaks vs GC negatives with
ambiguous peaks removed), each region scored on its shuffle (peaks: shuffle
set 0). Until 2026-10-08 the positives were the unshuffled peaks, against
their own shuffles (1:4); vir: peaks are shuffled too.

Counts: predicted counts on shuffled sequence vs the region's observed counts
-- on peaks (mean over the 4 shuffle sets) and on peaks + all GC negatives on
the test chromosomes (no ambiguous removal; peaks use shuffle set 0).
Observed counts are the released predictions' true_logcounts summed over
strands.

Peaks are re-predicted through the same code path (real sequence, real bias);
their log counts are checked against the released predictions first (every
run, whatever --bias).

--bias both (default) scores the same shuffles twice: with the real bias
(shuffled sequence, same bias) and with every bias input zero (shuffled
sequence, bias = 0), writing shuffled_bg/real/ and shuffled_bg/zero/; --bias
real or zero writes one. Several --fold values run in one process (one
TensorFlow start-up). --save-preds DIR (default $NOBIAS_SHUFFLED_PREDS, if
set) also keeps the per-region predictions in DIR/fold<f>/<EXP>.h5.

Usage:
    source /oak/stanford/groups/akundaje/vir/tfatlas/eval/src/env.sh
    PYTHONPATH=/oak/stanford/groups/akundaje/vir/tfatlas/eval/vendor/bpnet-refactor \
        $BPNET_PY shuffled_background.py --experiment ENCSR000EGN --fold 0 --gpu 0
        $BPNET_PY shuffled_background.py --experiment ENCSR000EGN --fold 0 1 2 3 4 --bias zero --gpu 0
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
ap.add_argument("--experiment", required=True)
ap.add_argument("--fold", type=int, nargs="+", required=True)
ap.add_argument("--bias", choices=["real", "zero", "both"], default="both")
ap.add_argument("--gpu", default="0")
ap.add_argument("--n-shuffles", type=int, default=4)
ap.add_argument("--procs", type=int, default=8, help="shuffle workers (SLURM_CPUS_PER_TASK wins)")
ap.add_argument("--save-preds", default=os.environ.get("NOBIAS_SHUFFLED_PREDS"),
                help="also write per-region predictions to DIR/fold<f>/<EXP>.h5")
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
from bpnet.utils.shaputils import dinuc_shuffle

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from nobias_paths import NEG_DIR, OUT, PROCESSED, PY, REF, RELEASE, RELEASED_PRED, TFATLAS  # noqa: E402,F401
import old_script  # noqa: E402
IN_FLANK, OUT_FLANK = 1057, 500


def counts_model(model):
    """The released model restricted to its log-counts output: the same layers,
    without the profile head (whose output these baselines do not use)."""
    return Model([model.get_layer("sequence").input, model.get_layer("counts_bias_input_0").input],
                 model.get_layer("logcounts_predictions").output)


def predict_logcounts(cmodel, X, pb):
    """RC-averaged log counts as in predict.py (counts bias = log(sum + 1); the
    reverse complement swaps the strands of the bias profile)."""
    cb = np.log(pb.sum(1) + 1)
    lc_f = cmodel.predict({"sequence": X, "counts_bias_input_0": cb}, batch_size=1024)
    lc_r = cmodel.predict({"sequence": np.ascontiguousarray(X[:, ::-1, ::-1]),
                           "counts_bias_input_0": np.ascontiguousarray(cb[:, ::-1])}, batch_size=1024)
    return ((lc_f + lc_r) / 2).ravel()


def _shuffle_one(args):
    """K dinucleotide shuffles of one sequence (bpnet's dinuc_shuffle on the
    string), from its own seed, one-hot encoded as uint8."""
    seq, k, seed = args
    return sequtils.one_hot_encode(dinuc_shuffle(seq, k, np.random.RandomState(seed)),
                                   2 * IN_FLANK).astype(np.uint8)


def shuffles(seqs, k, seed0, procs):
    """Region i is shuffled with seed seed0 + i, so results do not depend on procs."""
    from multiprocessing import Pool
    jobs = [(q, k, seed0 + i) for i, q in enumerate(seqs)]
    with Pool(procs) as pool:
        out = pool.map(_shuffle_one, jobs, chunksize=64)
    return np.concatenate(out).astype(np.float32)


def test_regions(path, tchroms):
    b = pd.read_csv(path, sep="\t", header=None)
    b = b[b[0].isin(tchroms)]
    return pd.DataFrame({"chrom": b[0].astype(str).values,
                         "pos": (b[1] + b[9]).values}).drop_duplicates().reset_index(drop=True)


def inputs(df, fasta, exp):
    seqs = [fasta[c][p - IN_FLANK:p + IN_FLANK].seq.upper() for c, p in zip(df.chrom, df.pos)]
    X = sequtils.one_hot_encode(seqs, 2 * IN_FLANK).astype(np.float32)
    df.attrs["seqs"] = seqs
    pb = np.zeros((len(df), 2 * OUT_FLANK, 2), np.float32)   # the real bias (control) profile
    for j, s in enumerate(["plus", "minus"]):
        bw = pyBigWig.open(str(PROCESSED / exp / f"{exp}_control_{s}.bigWig"))
        for i, (c, p) in enumerate(zip(df.chrom, df.pos)):
            pb[i, :, j] = np.nan_to_num(bw.values(c, p - OUT_FLANK, p + OUT_FLANK))
        bw.close()
    return X, pb


def main():
    for fold in a.fold:
        run_fold(a.experiment, fold)
        tf.keras.backend.clear_session()      # next fold loads its own model


def run_fold(exp, fold):
    from scipy.stats import pearsonr, spearmanr
    t0 = time.time()
    rel_dir = RELEASE / f"fold{fold}" / exp
    tchroms = json.loads((rel_dir / "splits.json").read_text())["0"]["test"]
    pk = test_regions(rel_dir / f"{exp}_peaks.bed", tchroms)
    ng = test_regions(rel_dir / f"{exp}_background_regions.bed", tchroms)
    n = len(pk)
    fasta = pyfaidx.Fasta(str(REF))
    X, pb = inputs(pk, fasta, exp)
    Xn, pbn = inputs(ng, fasta, exp)

    K = a.n_shuffles
    procs = int(os.environ.get("SLURM_CPUS_PER_TASK", a.procs))
    seed = (fold + 1) * 400_000_000            # peaks: seed + i; negatives: seed + 2e8 + j
    Xs = shuffles(pk.attrs["seqs"], K, seed, procs)
    Xns = shuffles(ng.attrs["seqs"], 1, seed + 200_000_000, procs)
    gc = lambda A: A[..., 1:3].sum((1, 2)) / A.sum((1, 2))
    print(f"{exp} fold{fold}: {n} test peaks x {K} shuffles, {len(ng)} test negatives x 1; "
          f"GC peak {gc(X).mean():.4f} shuffle {gc(Xs).mean():.4f} ({time.time()-t0:.0f}s)", flush=True)

    model = counts_model(load_model(str(rel_dir / f"{exp}_model" / f"{exp}_split000"), compile=False))
    lc_peak = predict_logcounts(model, X, pb)   # real bias: the check against the released predictions

    with h5py.File(RELEASED_PRED / f"fold{fold}" / exp / f"{exp}_split000_predictions.h5", "r") as h:
        pl, tl = h["predictions/pred_logcounts"][()], h["predictions/true_logcounts"][()]
        rel = pd.DataFrame({"chrom": h["coords/coords_chrom"][()].astype("U8"),
                            "pos": h["coords/coords_start"][()] + OUT_FLANK,
                            "rel": np.logaddexp(pl[:, 0], pl[:, 1]),
                            "obs": np.log(np.expm1(tl[:, 0]) + np.expm1(tl[:, 1]) + 1)}
                           ).drop_duplicates(["chrom", "pos"])
    mp = pk.assign(ours=lc_peak).merge(rel, on=["chrom", "pos"], how="left")
    mn = ng.merge(rel, on=["chrom", "pos"], how="left")
    assert mp.obs.notna().all() and mn.obs.notna().all(), "test regions missing from released predictions"
    # peaks through this code path == released predictions
    check = {"n_checked": len(mp), "max_abs_diff_vs_released": float(np.abs(mp.ours - mp.rel).max())}
    print(f"  peaks vs released predictions: {check}", flush=True)
    assert check["max_abs_diff_vs_released"] < 1e-3, "driver disagrees with released predictions"

    preds = {}
    for bias in (["real", "zero"] if a.bias == "both" else [a.bias]):
        if bias == "real":
            lp, ls_, ln = lc_peak, predict_logcounts(model, Xs, np.repeat(pb, K, axis=0)), \
                predict_logcounts(model, Xns, pbn)
        else:   # every bias input zero
            lp, ls_, ln = (predict_logcounts(model, A, np.zeros((len(A), 2 * OUT_FLANK, 2), np.float32))
                           for A in (X, Xs, Xns))
        preds[bias] = (lp, ls_, ln)
        score(exp, fold, bias, tchroms, rel_dir, pk, ng, mp, mn, K, check, ls_, ln, pearsonr, spearmanr, t0)
    if a.save_preds:
        d = Path(a.save_preds) / f"fold{fold}"
        d.mkdir(parents=True, exist_ok=True)
        with h5py.File(d / f"{exp}.h5.tmp", "w") as h:
            h["peaks/chrom"], h["peaks/pos"] = pk.chrom.values.astype("S8"), pk.pos.values
            h["negatives/chrom"], h["negatives/pos"] = ng.chrom.values.astype("S8"), ng.pos.values
            h["peaks/obs_total"], h["negatives/obs_total"] = mp.obs.values, mn.obs.values
            for bias, (lp, ls_, ln) in preds.items():
                h[f"{bias}/peak_real_sequence"] = lp           # unshuffled peaks
                h[f"{bias}/peak_shuffles"] = ls_.reshape(n, K)  # peak i, shuffle set k
                h[f"{bias}/negative_shuffles"] = ln
            h.attrs.update(experiment=exp, fold=fold, n_shuffles=K)
        os.replace(d / f"{exp}.h5.tmp", d / f"{exp}.h5")


def score(exp, fold, bias, tchroms, rel_dir, pk, ng, mp, mn, K, check, lc_shuf, lc_nshuf,
          pearsonr, spearmanr, t0):
    """AUPRC / AUROC (old script, the model's binary regions each on its shuffle) and
    counts correlations for one set of predictions; writes
    OUT/shuffled_bg/<bias>/fold<f>/<EXP>.tsv."""
    n = len(pk)
    shuf = lc_shuf.reshape(n, K)

    with tempfile.TemporaryDirectory() as tmp:
        # every region at its own coordinates, scored on its shuffle (peaks: set 0); the old
        # script then takes the same test peaks and ambiguous-removed GC negatives as metrics.py
        reg = pd.concat([pd.DataFrame({"chrom": pk.chrom.values, "pos": pk.pos.values, "lc": shuf[:, 0]}),
                         pd.DataFrame({"chrom": ng.chrom.values, "pos": ng.pos.values, "lc": lc_nshuf})],
                        ignore_index=True).drop_duplicates(["chrom", "pos"])   # a negative at a peak: the peak
        h5 = Path(tmp) / "pred.h5"
        with h5py.File(h5, "w") as f:
            f["coords/coords_chrom"] = reg.chrom.values.astype("S8")
            f["coords/coords_start"] = reg.pos.values - OUT_FLANK
            f["coords/coords_end"] = reg.pos.values + OUT_FLANK
            f["predictions/pred_logcounts"] = np.stack([reg.lc.values, reg.lc.values], 1)
        out = old_script.run(
            ["--score", "strand0",
             "--h5_file", str(h5), "--output_dir", tmp,
             "--peak_file", str(rel_dir / f"{exp}_peaks.bed"),
             "--neg_file", str(NEG_DIR / f"{exp}_gc_neg_ranked_idr_removed.bed.gz"),
             "--output_len", "1000", "--chroms", *tchroms])
        auprc = float(re.search(r"^average_precision_score: (\S+)$", out, re.M).group(1))
        auroc = float(re.search(r"^roc_auc_score: (\S+)$", out, re.M).group(1))
        nm = re.search(r"^predictions\['label'\]\.astype\(int\):.*?Length: (\d+)", out, re.M | re.S)
        base = float((Path(tmp) / "auprc_baseline.txt").read_text())

    meta = dict(encid=exp, fold=fold, bias=bias, n_peaks=n, n_negatives=len(ng), **check)
    rows = [dict(meta, metric_type=mt, regions_input="shuffled_peaks_and_nonpeaks_ambiguous_removed",
                 metric_value=v, n_regions=int(nm.group(1)) if nm else None)
            for mt, v in (("auprc", auprc), ("auroc", auroc), ("auprc_baseline", base))]
    all_pred = np.concatenate([shuf[:, 0], lc_nshuf])
    all_obs = np.concatenate([mp.obs.values, mn.obs.values])
    for mt, fn in (("pearsonr", pearsonr), ("spearmanr", spearmanr)):
        rows.append(dict(meta, metric_type=mt, regions_input="peaks",
                         metric_value=float(np.mean([fn(shuf[:, k], mp.obs)[0] for k in range(K)])),
                         n_regions=n))
        rows.append(dict(meta, metric_type=mt, regions_input="peaks_and_nonpeaks",
                         metric_value=fn(all_pred, all_obs)[0], n_regions=len(all_obs)))
    out = OUT / "shuffled_bg" / bias / f"fold{fold}"
    out.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(out / f"{exp}.tsv", sep="\t", index=False)
    c = {(r_["metric_type"], r_["regions_input"]): r_["metric_value"] for r_ in rows}
    print(f"  {bias}: auprc {auprc:.4f} auroc {auroc:.4f} baseline {base}; pearson peaks "
          f"{c[('pearsonr', 'peaks')]:.4f} all {c[('pearsonr', 'peaks_and_nonpeaks')]:.4f} ({time.time()-t0:.0f}s)")


if __name__ == "__main__":
    main()
