#!/usr/bin/env python3
"""Fit linear probes on one released model's frozen features (probe_features.py)
and score them on the fold's test chromosomes.

Tasks:
    binary   peak vs non-peak, logistic loss, on peaks + GC negatives with
             ambiguous peaks removed (binary_set); AUPRC / AUROC via the old
             auprc_auroc_calculations.py (probe logit stored as
             pred_logcounts[:, 0], --score strand0)
    counts   observed total log counts, MSE loss, on peaks + all GC negatives;
             Pearson / Spearman on test peaks and on all test regions
Head: one linear layer, fit to its optimum -- logistic regression on
standardised features for binary, least squares on the raw features for counts.
Probe version 2 (2026-10-08, vir): the dense probes are dropped, and the counts
least squares no longer standardises the features. Version 1 divided every
feature by its training sd + 1e-6, so a trunk channel that is zero on all
training regions but fires on a few test ones got test values ~1e6 x larger,
and the solver's rounding could give it a large coefficient: a few extreme
predictions collapsed the counts Pearson (e.g. ENCSR940EZR fold 1). Least
squares predictions do not depend on feature scaling, so the raw features give
the same fit without that amplification (the way the model's own count head
reads them). The logistic fit keeps standardised features; its L2 penalty
drives the weight of a channel that is zero on all training regions to 0.
Inputs:
    zero     the 64 pooled trunk features (bias = 0 is exact: the trunk never
             sees the control)
    real     the 64 features + the model's control total (the value its final
             counts layer mixes in)
Labels: true, or shuffled (control): as in label_shuffle.py, labels and
observed counts are shuffled within each split (and task region set) and take
their region's control total with them, while the sequence features stay --
for training and scoring alike, so no true label or count reaches the probe. With "zero" inputs this is chance; with "real" inputs it is
what a trained readout gets from the control alone.

Usage:
    source /oak/stanford/groups/akundaje/vir/tfatlas/eval/src/env.sh
    $BPNET_PY probe_fit.py --experiment ENCSR000EGN --fold 0
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
ap.add_argument("--fold", type=int, required=True)
ap.add_argument("--threads", type=int, default=4)
ap.add_argument("--seeds", nargs="+", type=int, default=[0],
                help="unused since probe version 2 (dense probes dropped); kept for old command lines")
sys.path.insert(0, str(Path(__file__).resolve().parent))
from nobias_paths import FEAT_ROOT, NEG_DIR, OUT, PY, RELEASE, SCORE_ROOT, TFATLAS  # noqa: E402,F401
import old_script  # noqa: E402
ap.add_argument("--feat-root", default=str(FEAT_ROOT))
ap.add_argument("--score-root", default=str(SCORE_ROOT))
a = ap.parse_args()
os.environ.setdefault("HDF5_USE_FILE_LOCKING", "FALSE")
for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
    os.environ.setdefault(v, str(a.threads))

import h5py
import numpy as np
import pandas as pd
from scipy.stats import pearsonr, spearmanr
from sklearn.linear_model import LinearRegression, LogisticRegression

HERE = Path(__file__).resolve().parent
PROBE_VERSION = 2

CONFIGS = [(task, feat, "linear", labels, 0) for task in ("binary", "counts")
           for feat in ("zero", "real") for labels in ("true", "shuffled")]


def fit_predict(task, Xf, target, tr, te):
    """Test predictions, solver iterations and least-squares rank of the linear probe."""
    if task == "binary":     # standardised features (the L2 penalty needs a common scale)
        mu, sd = Xf[tr].mean(0), Xf[tr].std(0) + 1e-6
        Z = ((Xf - mu) / sd).astype(np.float32)
        m = LogisticRegression(C=1e4, solver="lbfgs", max_iter=5000)
        m.fit(Z[tr], target[tr])
        return m.decision_function(Z[te]), m.n_iter_[0], None
    X64 = Xf.astype(np.float64)   # raw features: least squares does not need a common scale
    m = LinearRegression().fit(X64[tr], target[tr].astype(np.float64))
    return m.predict(X64[te]), 0, int(m.rank_)


def label_beds(chrom, pos, y, tmpdir):
    """Peak / negative BEDs (old-script format) carrying the given labels."""
    out = []
    for lab, name in ((1, "peaks.bed"), (0, "negs.bed")):
        m = y == lab
        p = Path(tmpdir) / name
        pd.DataFrame({0: chrom[m].astype(str), 1: pos[m] - 1057, 2: pos[m] + 1057, 3: ".", 4: lab,
                      5: ".", 6: 0, 7: 0, 8: 0, 9: 1057}).to_csv(p, sep="\t", header=False, index=False)
        out.append(p)
    return out


def score_old(chrom, pos, logit, test_chroms, tmpdir, beds=None):
    """Write the logits in the predictions-h5 layout and run the old script.
    beds=None uses the real peak / ambiguous-removed negative files."""
    h5 = Path(tmpdir) / "probe_predictions.h5"
    with h5py.File(h5, "w") as f:
        f["coords/coords_chrom"] = chrom
        f["coords/coords_start"] = pos - 500
        f["coords/coords_end"] = pos + 500
        f["predictions/pred_logcounts"] = np.stack([logit, logit], 1)
    exp, fold = a.experiment, a.fold
    peak_file, neg_file = beds or (RELEASE / f"fold{fold}" / exp / f"{exp}_peaks.bed",
                                   NEG_DIR / f"{exp}_gc_neg_ranked_idr_removed.bed.gz")
    out = old_script.run(
        ["--score", "strand0",
         "--h5_file", str(h5), "--output_dir", str(tmpdir),
         "--peak_file", str(peak_file), "--neg_file", str(neg_file),
         "--output_len", "1000", "--chroms", *test_chroms])
    auprc = float(re.search(r"^average_precision_score: (\S+)$", out, re.M).group(1))
    auroc = float(re.search(r"^roc_auc_score: (\S+)$", out, re.M).group(1))
    n = re.search(r"^predictions\['label'\]\.astype\(int\):.*?Length: (\d+)", out, re.M | re.S)
    base = float((Path(tmpdir) / "auprc_baseline.txt").read_text())
    return auprc, auroc, base, int(n.group(1)) if n else None


def main():
    exp, fold = a.experiment, a.fold
    t0 = time.time()
    with h5py.File(Path(a.feat_root) / f"fold{fold}" / f"{exp}.h5", "r") as f:
        chrom = f["chrom"][()]
        pos = f["pos"][()]
        y = f["label"][()].astype(np.float32)
        bset = f["binary_set"][()].astype(bool)
        feats = f["features"][()]
        ctrl = f["control_total"][()]
        obs = f["obs_total"][()].astype(np.float32)
    splits = json.loads((RELEASE / f"fold{fold}" / exp / "splits.json").read_text())["0"]
    cs = chrom.astype(str)
    split = {k: np.isin(cs, splits[k]) for k in ("train", "val", "test")}

    # per task: region set, and a within-split shuffle in which label, observed
    # counts and control total travel together while sequence features stay
    rng = np.random.default_rng(12345)
    sets = {}
    for task, sel in (("binary", bset), ("counts", np.ones(len(y), bool))):
        masks = {k: split[k] & sel for k in split}
        idx = np.arange(len(y))
        for k in ("train", "val", "test"):
            w = np.where(masks[k])[0]
            idx[w] = rng.permutation(w)
        sets[task] = (masks, idx)

    rows, scores = [], {}
    for task, feat, head, labels, seed in CONFIGS:
        masks, idx = sets[task]
        j = idx if labels == "shuffled" else np.arange(len(y))
        yl, ol, cl = y[j], obs[j], ctrl[j]
        Xf = feats if feat == "zero" else np.concatenate([feats, cl[:, None]], 1)
        tr, va, te = masks["train"], masks["val"], masks["test"]
        if task == "binary":
            target = yl
        else:  # standardised target; correlations are scale-free
            target = ((ol - ol[tr].mean()) / (ol[tr].std() + 1e-6)).astype(np.float32)
        pred, n_ep, rank = fit_predict(task, Xf, target, tr, te)
        name = f"{task}.{feat}.{head}.{labels}.seed{seed}"
        scores[name] = pred
        meta = dict(encid=exp, fold=fold, task=task, probe_inputs=feat, head=head, labels=labels,
                    seed=seed, epochs=int(n_ep), n_train=int(tr.sum()), n_val=int(va.sum()),
                    probe_version=PROBE_VERSION,
                    # audit of the counts least squares: rank of the training design (features +
                    # intercept centring) and the largest |test prediction| in training-sd units
                    ols_rank=rank, max_abs_pred=(float(np.abs(pred).max()) if task == "counts" else None))
        if task == "binary":
            tc, tp = chrom[te], pos[te]
            with tempfile.TemporaryDirectory() as tmp:
                beds = label_beds(tc, tp, yl[te], tmp) if labels == "shuffled" else None
                auprc, auroc, base, n = score_old(tc, tp, pred, splits["test"], tmp, beds)
            for mt, v in (("auprc", auprc), ("auroc", auroc), ("auprc_baseline", base)):
                rows.append({**meta, "metric_type": mt,
                             "regions_input": "peaks_and_nonpeaks_ambiguous_removed",
                             "metric_value": v, "n_regions": n})
            msg = f"auprc {auprc:.4f} auroc {auroc:.4f}"
        else:
            o_te, pk_te = ol[te], yl[te] == 1
            vals = {}
            for reg, msk in (("peaks", pk_te), ("peaks_and_nonpeaks", np.ones(len(pk_te), bool))):
                for mt, fn in (("pearsonr", pearsonr), ("spearmanr", spearmanr)):
                    vals[(mt, reg)] = fn(pred[msk], o_te[msk])[0]
                    rows.append({**meta, "metric_type": mt, "regions_input": reg,
                                 "metric_value": vals[(mt, reg)], "n_regions": int(msk.sum())})
            msg = (f"pearson peaks {vals[('pearsonr', 'peaks')]:.4f} "
                   f"all {vals[('pearsonr', 'peaks_and_nonpeaks')]:.4f}")
        print(f"{name:36s} {msg} epochs {n_ep} ({time.time()-t0:.0f}s)", flush=True)

    out = OUT / "probe" / f"fold{fold}"
    out.mkdir(parents=True, exist_ok=True)
    # atomic and collision-free: reruns tell finished files by their contents
    fd, tmp = tempfile.mkstemp(dir=out, prefix=f"{exp}.tsv.", suffix=".tmp")
    with os.fdopen(fd, "w") as fh:
        pd.DataFrame(rows).to_csv(fh, sep="\t", index=False)
    um = os.umask(0)
    os.umask(um)
    os.chmod(tmp, 0o666 & ~um)            # mkstemp makes 0600; keep the usual permissions
    os.replace(tmp, out / f"{exp}.tsv")
    sdir = Path(a.score_root) / f"fold{fold}"
    sdir.mkdir(parents=True, exist_ok=True)
    with h5py.File(sdir / f"{exp}.h5", "w") as f:
        for task, (masks, idx) in sets.items():
            te = masks["test"]
            g = f.create_group(task)
            g["chrom"], g["pos"] = chrom[te], pos[te]
            g["label"], g["obs_total"] = y[te], obs[te]
            g["label_shuffled"], g["obs_total_shuffled"] = y[idx][te], obs[idx][te]
            for k, v in scores.items():
                if k.startswith(task + "."):
                    g[f"pred/{k}"] = v
    print(f"{exp} fold{fold}: {len(CONFIGS)} probes in {time.time()-t0:.0f}s")


if __name__ == "__main__":
    sys.exit(main())
