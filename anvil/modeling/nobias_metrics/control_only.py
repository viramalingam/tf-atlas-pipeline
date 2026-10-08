#!/usr/bin/env python3
"""Control counts only: what a released model predicts from the bias alone.

The model's counts output is
    logcounts = w0 * count_head(sequence) + w1 * control_total + b
(final layer logcounts_predictions; control_total = logsumexp over strands of
log(control + 1), as in predict.py; count_head / control_total / w / b come
from probe_features.py). If the sequence carries no information the count
head is a constant, so the prediction is w1 * control_total + const: a
rescaled control count. That is scored like the model itself, on the same
regions and labels:
    AUPRC / AUROC   the old auprc_auroc_calculations.py merge (test peaks vs GC
                    negatives with ambiguous peaks removed), as in
                    label_shuffle.py (sklearn on unrounded scores; the merge is
                    checked against the features file)
    Pearson / Spearman   vs observed total log counts, on test peaks and on test
                    peaks + all GC negatives
With w1 > 0 (reported per model) this ranks regions by their control counts.

Writes OUT/control_only/fold<f>/<EXP>.tsv.

Usage:
    python control_only.py --jobs jobs.txt --workers 8      # lines: EXPERIMENT FOLD
"""

import argparse
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from label_shuffle import corr, counts_test_set, labelled_test_set  # noqa: E402
from nobias_paths import OUT  # noqa: E402


def run_one(experiment, fold):
    from sklearn.metrics import average_precision_score, roc_auc_score
    y, _, ctrl, w, _ = labelled_test_set(experiment, fold)
    s = w[1] * ctrl
    meta = dict(encid=experiment, fold=fold, bias="real", w1=float(w[1]))
    rows = [dict(meta, metric_type=m, regions_input="peaks_and_nonpeaks_ambiguous_removed", metric_value=v,
                 n_regions=len(y))
            for m, v in (("auprc", average_precision_score(y, s)), ("auroc", roc_auc_score(y, s)),
                         ("auprc_baseline", y.mean()))]
    yc, _, ctrlc, obs = counts_test_set(experiment, fold)
    for (m, reg), v in corr(w[1] * ctrlc, obs, yc == 1).items():
        rows.append(dict(meta, metric_type=m, regions_input=reg, metric_value=v,
                         n_regions=int((yc == 1).sum()) if reg == "peaks" else len(obs)))
    out = OUT / "control_only" / f"fold{fold}"
    out.mkdir(parents=True, exist_ok=True)
    df = pd.DataFrame(rows)
    df.to_csv(out / f"{experiment}.tsv.tmp", sep="\t", index=False)
    (out / f"{experiment}.tsv.tmp").replace(out / f"{experiment}.tsv")
    return df


def _job(args):
    try:
        return run_one(*args)
    except Exception as e:
        return pd.DataFrame([{"encid": args[0], "fold": args[1], "error": f"{type(e).__name__}: {e}"[:400]}])


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--jobs", required=True, help="lines: EXPERIMENT FOLD")
    ap.add_argument("--workers", type=int, default=8)
    a = ap.parse_args()
    jobs = [(e, int(f)) for e, f, *_ in (ln.split() for ln in open(a.jobs) if ln.strip())]
    with ProcessPoolExecutor(a.workers) as ex:
        res = pd.concat(list(ex.map(_job, jobs)), ignore_index=True)
    bad = res[res["error"].notna()] if "error" in res.columns else res.iloc[0:0]
    print(f"done: {len(jobs)} jobs, {len(bad)} errors")
    if len(bad):
        print(bad[["encid", "fold", "error"]].to_string())
    return 1 if len(bad) else 0


if __name__ == "__main__":
    sys.exit(main())
