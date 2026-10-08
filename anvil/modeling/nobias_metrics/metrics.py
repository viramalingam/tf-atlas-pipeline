#!/usr/bin/env python3
"""AUPRC, AUROC and counts Pearson/Spearman for one released model, from its
predictions on peaks + GC negatives on the fold's test chromosomes, with the
real bias (the released all-regions predictions) or with bias set to zero
(predict_regions.py --bias zero).

Binary metrics run the old tf-atlas-pipeline auprc_auroc_calculations.py
(with --score total): positives EXP_peaks.bed, negatives the GC negatives
with ambiguous (IDR ranked) peaks removed. Full-precision values are parsed
from its stdout; its 3-dp auprc.txt / auroc.txt / auprc_baseline.txt (the
AnVIL convention) are kept alongside.

Counts metrics use total counts: predicted = logaddexp over the two strands
(the count head output), observed = log(total reads over both strands + 1).
Regions: peaks, and peaks + all GC negatives (every region in the h5, the
old pearson_all_peaks definition). Ambiguous peaks are removed from the
negatives only for the binary metrics (vir, 2026-10-04).

Usage:
    python metrics.py --experiment ENCSR000EGN --fold 0 --bias zero
    python metrics.py --jobs jobs.txt --workers 8      # lines: EXP FOLD BIAS
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import h5py
import numpy as np
import pandas as pd
from scipy.stats import pearsonr, spearmanr

sys.path.insert(0, str(Path(__file__).resolve().parent))
from nobias_paths import HERE, NEG_DIR, OUT, PRED_ROOT, PY, RELEASE, RELEASED_PRED, TFATLAS  # noqa: E402,F401
import old_script  # noqa: E402


def predictions_h5(experiment, fold, bias, local_real=False):
    """Real bias: the released predictions (or, with local_real, our own
    re-prediction, used only to validate predict_regions.py)."""
    if bias == "real" and not local_real:
        return RELEASED_PRED / f"fold{fold}" / experiment / f"{experiment}_split000_predictions.h5"
    return PRED_ROOT / bias / f"fold{fold}" / experiment / f"{experiment}_split000_predictions.h5"


def test_chroms(experiment, fold):
    splits = json.loads((RELEASE / f"fold{fold}" / experiment / "splits.json").read_text())
    return list(splits["0"]["test"])


def binary_metrics(h5, experiment, fold, outdir):
    """Old auprc_auroc_calculations.py, unchanged apart from --score total."""
    out = old_script.run(
        ["--score", "total",
         "--h5_file", str(h5), "--output_dir", str(outdir),
         "--peak_file", str(RELEASE / f"fold{fold}" / experiment / f"{experiment}_peaks.bed"),
         "--neg_file", str(NEG_DIR / f"{experiment}_gc_neg_ranked_idr_removed.bed.gz"),
         "--output_len", "1000", "--chroms", *test_chroms(experiment, fold)])
    (Path(outdir) / "auprc_auroc_calculations.log").write_text(out)
    auprc = float(re.search(r"^average_precision_score: (\S+)$", out, re.M).group(1))
    auroc = float(re.search(r"^roc_auc_score: (\S+)$", out, re.M).group(1))
    n = re.search(r"^predictions\['label'\]\.astype\(int\):.*?Length: (\d+)", out, re.M | re.S)
    return {"auprc": auprc, "auroc": auroc,
            "auprc_baseline": float((Path(outdir) / "auprc_baseline.txt").read_text()),
            "n_binary": int(n.group(1)) if n else None}


def counts_metrics(h5, experiment, fold):
    with h5py.File(h5, "r") as f:
        chrom = f["coords/coords_chrom"][()].astype("U8")
        start = f["coords/coords_start"][()]
        pl = f["predictions/pred_logcounts"][()]
        tl = f["predictions/true_logcounts"][()]
    pred_tot = np.logaddexp(pl[:, 0], pl[:, 1])
    true_tot = np.log(np.expm1(tl[:, 0]) + np.expm1(tl[:, 1]) + 1)

    peaks = pd.read_csv(RELEASE / f"fold{fold}" / experiment / f"{experiment}_peaks.bed",
                        sep="\t", header=None)
    peak_keys = set(zip(peaks[0].astype(str), peaks[1] + peaks[9] - 500))
    is_peak = np.fromiter(((c, s) in peak_keys for c, s in zip(chrom, start)), bool, len(chrom))

    out = {}
    for regions, m in [("peaks", is_peak), ("peaks_and_nonpeaks", np.ones(len(chrom), bool))]:
        out[("pearsonr", regions)] = pearsonr(pred_tot[m], true_tot[m])[0]
        out[("spearmanr", regions)] = spearmanr(pred_tot[m], true_tot[m])[0]
        out[("n", regions)] = int(m.sum())
    return out


def run_one(experiment, fold, bias, local_real=False, out_root=OUT):
    h5 = predictions_h5(experiment, fold, bias, local_real)
    tag = "real_local" if (bias == "real" and local_real) else bias
    outdir = Path(out_root) / tag / f"fold{fold}"
    outdir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=outdir) as tmp:
        b = binary_metrics(h5, experiment, fold, tmp)
        for name in ("auprc_auroc_calculations.log",):
            (outdir / f"{experiment}.{name}").write_text((Path(tmp) / name).read_text())
    c = counts_metrics(h5, experiment, fold)
    rows = []
    ambig = "peaks_and_nonpeaks_ambiguous_removed"
    for m in ("auprc", "auroc", "auprc_baseline"):
        rows.append((m, ambig, b[m], b["n_binary"]))
    for m in ("pearsonr", "spearmanr"):
        for reg in ("peaks", "peaks_and_nonpeaks"):
            rows.append((m, reg, c[(m, reg)], c[("n", reg)]))
    df = pd.DataFrame(rows, columns=["metric_type", "regions_input", "metric_value", "n_regions"])
    df.insert(0, "bias", bias)
    df.insert(0, "fold", fold)
    df.insert(0, "encid", experiment)
    df["score"] = "total"
    df["predictions_h5"] = str(h5)
    with h5py.File(h5, "r") as f:     # bias=0 from bpnet-predict, or from the probe-features pass
        df["zero_source"] = f.attrs.get("source", "bpnet-predict") if bias == "zero" else "released"
    df.to_csv(outdir / f"{experiment}.tsv", sep="\t", index=False)
    return df


def _job(args):
    try:
        return run_one(*args)
    except Exception as e:
        return pd.DataFrame([{"encid": args[0], "fold": args[1], "bias": args[2],
                              "error": f"{type(e).__name__}: {e}"[:500]}])


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--experiment")
    ap.add_argument("--fold", type=int)
    ap.add_argument("--bias", choices=["real", "zero"])
    ap.add_argument("--jobs", help="file with lines: EXPERIMENT FOLD BIAS")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--local-real", action="store_true",
                    help="score our own real-bias re-prediction instead of the "
                         "released predictions (validation of predict_regions.py)")
    a = ap.parse_args()
    if a.jobs:
        jobs = [(e, int(f), b, a.local_real) for e, f, b in
                (ln.split() for ln in open(a.jobs) if ln.strip())]
        with ProcessPoolExecutor(a.workers) as ex:
            res = pd.concat(list(ex.map(_job, jobs)), ignore_index=True)
        bad = res[res["error"].notna()] if "error" in res.columns else res.iloc[0:0]
        print(f"done: {len(jobs)} jobs, {len(bad)} errors")
        if len(bad):
            print(bad[["encid", "fold", "bias", "error"]].to_string())
    else:
        print(run_one(a.experiment, a.fold, a.bias, a.local_real).to_string())


if __name__ == "__main__":
    sys.exit(main())
