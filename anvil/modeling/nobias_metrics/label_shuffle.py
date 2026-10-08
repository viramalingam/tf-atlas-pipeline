#!/usr/bin/env python3
"""Label-shuffling baseline for AUPRC/AUROC and counts Pearson/Spearman.

Labels are shuffled across the test regions and each label takes its
region's bias (control) with it; the sequence stays where it is. The model
thus sees region i's sequence with region j's bias and is scored against
region j's label, so only the bias can carry label information. 100 shuffles
(seeded); mean, sd and 2.5 / 97.5 % quantiles. With bias = 0 there is no
bias to carry, so this is the chance level.

Exact without re-running the network: the model's counts output is
    logcounts = w0 * count_head(sequence) + w1 * control_total + b
(final layer logcounts_predictions; count_head RC-averaged, control_total the
model's logsumexp of per-strand log(control + 1), as in predict.py), so a
shuffled-bias prediction is that formula with region j's control_total.
count_head / control_total / w / b come from probe_features.py. --check runs
an explicit forward pass with swapped bias inputs and compares (GPU).

Counts: the observed counts are shuffled the same way -- observed counts,
label and bias travel together, the sequence stays -- and the prediction is
correlated with the observed counts it now sits next to, on peaks (by the
travelling label) and on all regions.

Test sets: binary -- the old auprc_auroc_calculations.py merge (peaks + GC
negatives with ambiguous peaks removed, test chromosomes), whose unshuffled
formula scores must reproduce the old script's stored AUPRC/AUROC; counts --
peaks + all GC negatives on the test chromosomes (no ambiguous removal), whose
unshuffled correlations are compared with metrics.py's.

Usage:
    python label_shuffle.py --jobs jobs.txt --workers 8          # lines: EXP FOLD BIAS
    $BPNET_PY label_shuffle.py --check ENCSR000EGN 0 --gpu 0     # bpnet env
"""

import argparse
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import h5py
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from nobias_paths import FEAT_ROOT, NEG_DIR, OUT, RELEASE, TFATLAS  # noqa: E402
N_PERM = 100


def test_chroms(experiment, fold):
    import json
    return json.loads((RELEASE / f"fold{fold}" / experiment / "splits.json").read_text())["0"]["test"]


def labelled_test_set(experiment, fold):
    """Rows of the old script's merge (negatives + peaks, summit +/- 500, test
    chromosomes), with count_head / control_total looked up per region."""
    peaks_df = pd.read_csv(RELEASE / f"fold{fold}" / experiment / f"{experiment}_peaks.bed",
                           header=None, sep="\t")
    negs_df = pd.read_csv(NEG_DIR / f"{experiment}_gc_neg_ranked_idr_removed.bed.gz",
                          header=None, sep="\t")
    r = pd.concat([negs_df, peaks_df]).reset_index(drop=True)
    r.columns = ['chroms', 'start', 'end', 'name', 'label', 'strand', 'p', 'q', 'x', 'summit']
    r['pos'] = r['start'] + r['summit']
    r = r[r['chroms'].isin(test_chroms(experiment, fold))]
    with h5py.File(FEAT_ROOT / f"fold{fold}" / f"{experiment}.h5", "r") as f:
        feat = pd.DataFrame({"chroms": f["chrom"][()].astype(str), "pos": f["pos"][()],
                             "count_head": f["count_head"][()],
                             "control_total": f["control_total"][()]}).drop_duplicates(["chroms", "pos"])
        w = f.attrs["count_layer_weights"]
        b = float(f.attrs["count_layer_bias"])
    m = r.merge(feat, on=["chroms", "pos"], how="inner")
    assert len(m) == len(r), f"{len(r) - len(m)} test regions missing from the features file"
    return (m["label"].astype(int).values, m["count_head"].values.astype(np.float64),
            m["control_total"].values.astype(np.float64), w, b)


def counts_test_set(experiment, fold):
    """Test-chromosome rows of the features file: peaks + all GC negatives."""
    with h5py.File(FEAT_ROOT / f"fold{fold}" / f"{experiment}.h5", "r") as f:
        m = np.isin(f["chrom"][()].astype(str), test_chroms(experiment, fold))
        return (f["label"][()][m].astype(int), f["count_head"][()][m].astype(np.float64),
                f["control_total"][()][m].astype(np.float64), f["obs_total"][()][m].astype(np.float64))


def corr(pred, obs, peaks):
    from scipy.stats import pearsonr, spearmanr
    out = {}
    for reg, msk in (("peaks", peaks), ("peaks_and_nonpeaks", np.ones(len(obs), bool))):
        out[("pearsonr", reg)] = pearsonr(pred[msk], obs[msk])[0]
        out[("spearmanr", reg)] = spearmanr(pred[msk], obs[msk])[0]
    return out


def run_one(experiment, fold, bias):
    from sklearn.metrics import average_precision_score, roc_auc_score
    y, ch, ctrl, w, b = labelled_test_set(experiment, fold)
    bias_term = (lambda c: w[1] * c) if bias == "real" else (lambda c: w[1] * np.log(2.0))
    s0 = w[0] * ch + bias_term(ctrl) + b
    stored = pd.read_csv(OUT / bias / f"fold{fold}" / f"{experiment}.tsv", sep="\t")
    ref = {m: stored.loc[stored.metric_type == m, "metric_value"].item() for m in ("auprc", "auroc")}
    unshuf = {"auprc": average_precision_score(y, s0), "auroc": roc_auc_score(y, s0)}
    for m in ref:
        assert abs(unshuf[m] - ref[m]) < 1e-4, f"{m}: formula {unshuf[m]} vs old script {ref[m]}"

    rng = np.random.default_rng(1000 * fold + 17)
    perm = {"auprc": [], "auroc": []}
    for _ in range(N_PERM):
        idx = rng.permutation(len(y))
        yp, s = y[idx], w[0] * ch + bias_term(ctrl[idx]) + b   # bias travels with the label
        perm["auprc"].append(average_precision_score(yp, s))
        perm["auroc"].append(roc_auc_score(yp, s))
    rows = []
    for m, v in perm.items():
        v = np.array(v)
        rows.append(dict(encid=experiment, fold=fold, bias=bias, metric_type=m,
                         regions_input="peaks_and_nonpeaks_ambiguous_removed",
                         n_permutations=N_PERM, mean=v.mean(), sd=v.std(ddof=1),
                         q025=np.quantile(v, 0.025), q975=np.quantile(v, 0.975),
                         unshuffled=unshuf[m], unshuffled_old_script=ref[m],
                         n_regions=len(y), positive_fraction=y.mean()))

    # counts: observed counts, label and bias travel together
    yc, chc, ctrlc, obs = counts_test_set(experiment, fold)
    c0 = corr(w[0] * chc + bias_term(ctrlc) + b, obs, yc == 1)
    for k, v in c0.items():
        refc = stored.loc[(stored.metric_type == k[0]) & (stored.regions_input == k[1]), "metric_value"].item()
        # Spearman: the released-prediction path breaks ties among equal observed counts with
        # float noise (~1e-7) where the features file keeps them exact; with few, mostly
        # zero-count regions that moves Spearman by ~0.01, so it gets a looser check
        tol = 0.05 if k[0] == "spearmanr" else 0.01
        assert abs(v - refc) < tol, f"{k}: features-based {v} vs metrics.py {refc}"
    cperm = {k: [] for k in c0}
    for _ in range(N_PERM):
        idx = rng.permutation(len(obs))
        c = corr(w[0] * chc + bias_term(ctrlc[idx]) + b, obs[idx], yc[idx] == 1)
        for k in c:
            cperm[k].append(c[k])
    for (m, reg), v in cperm.items():
        v = np.array(v)
        refc = stored.loc[(stored.metric_type == m) & (stored.regions_input == reg), "metric_value"].item()
        rows.append(dict(encid=experiment, fold=fold, bias=bias, metric_type=m, regions_input=reg,
                         n_permutations=N_PERM, mean=v.mean(), sd=v.std(ddof=1),
                         q025=np.quantile(v, 0.025), q975=np.quantile(v, 0.975),
                         unshuffled=c0[(m, reg)], unshuffled_old_script=refc,
                         n_regions=int((yc == 1).sum()) if reg == "peaks" else len(obs),
                         positive_fraction=(yc == 1).mean()))
    out = OUT / "label_shuffle" / bias / f"fold{fold}"
    out.mkdir(parents=True, exist_ok=True)
    df = pd.DataFrame(rows)
    df.to_csv(out / f"{experiment}.tsv", sep="\t", index=False)
    return df


def check(experiment, fold, gpu, n=4096):
    """Explicit forward pass: region i's sequence with region j's bias inputs."""
    import os
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu)
    import pyBigWig, pyfaidx
    import tensorflow as tf  # noqa: F401
    from tensorflow.keras.models import load_model
    sys.path.insert(0, str(TFATLAS / "eval" / "src"))
    import bpnet.model.arch  # noqa: F401
    from bpnet.generators import sequtils
    with h5py.File(FEAT_ROOT / f"fold{fold}" / f"{experiment}.h5", "r") as f:
        chrom = f["chrom"][()].astype(str); pos = f["pos"][()]
        ch = f["count_head"][()]; w = f.attrs["count_layer_weights"]; b = float(f.attrs["count_layer_bias"])
    tmask = np.isin(chrom, test_chroms(experiment, fold))
    rng = np.random.default_rng(0)
    i = rng.choice(np.where(tmask)[0], n, replace=False)
    j = rng.permutation(i)                       # bias donors
    fasta = pyfaidx.Fasta(str(TFATLAS / "references" / "hg38" / "hg38.genome.fa"))
    X = sequtils.one_hot_encode([fasta[chrom[k]][pos[k] - 1057:pos[k] + 1057].seq.upper() for k in i],
                                2114).astype(np.float32)
    pb = np.zeros((n, 1000, 2), np.float32)
    for s_, strand in enumerate(["plus", "minus"]):
        bw = pyBigWig.open(str(TFATLAS / "processed_data" / experiment / f"{experiment}_control_{strand}.bigWig"))
        for r_, k in enumerate(j):
            pb[r_, :, s_] = np.nan_to_num(bw.values(chrom[k], pos[k] - 500, pos[k] + 500))
        bw.close()
    model = load_model(str(RELEASE / f"fold{fold}" / experiment / f"{experiment}_model" / f"{experiment}_split000"),
                       compile=False)
    pb_rc = sequtils.reverse_complement_of_profiles(pb, stranded=True)
    lc = (model.predict({"sequence": X, "profile_bias_input_0": pb,
                         "counts_bias_input_0": np.log(pb.sum(1) + 1)}, batch_size=1024)[1]
          + model.predict({"sequence": np.ascontiguousarray(X[:, ::-1, ::-1]), "profile_bias_input_0": pb_rc,
                           "counts_bias_input_0": np.log(pb_rc.sum(1) + 1)}, batch_size=1024)[1]).ravel() / 2
    ctrl_j = np.logaddexp(np.log(pb[:, :, 0].sum(1) + 1), np.log(pb[:, :, 1].sum(1) + 1))
    formula = w[0] * ch[i] + w[1] * ctrl_j + b
    d = np.abs(lc - formula)
    print(f"{experiment} fold{fold}: {n} regions with swapped bias; |forward pass - formula| "
          f"max {d.max():.2e} mean {d.mean():.2e}")
    return 0 if d.max() < 1e-3 else 1


def _job(args):
    try:
        return run_one(*args)
    except Exception as e:
        return pd.DataFrame([{"encid": args[0], "fold": args[1], "bias": args[2],
                              "error": f"{type(e).__name__}: {e}"[:400]}])


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--jobs", help="lines: EXPERIMENT FOLD BIAS")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--check", nargs=2, metavar=("EXPERIMENT", "FOLD"))
    ap.add_argument("--gpu", default="0")
    a = ap.parse_args()
    if a.check:
        return check(a.check[0], int(a.check[1]), a.gpu)
    jobs = [(e, int(f), b) for e, f, b in (ln.split() for ln in open(a.jobs) if ln.strip())]
    with ProcessPoolExecutor(a.workers) as ex:
        res = pd.concat(list(ex.map(_job, jobs)), ignore_index=True)
    bad = res[res["error"].notna()] if "error" in res.columns else res.iloc[0:0]
    print(f"done: {len(jobs)} jobs, {len(bad)} errors")
    if len(bad):
        print(bad[["encid", "fold", "bias", "error"]].to_string())


if __name__ == "__main__":
    sys.exit(main())
