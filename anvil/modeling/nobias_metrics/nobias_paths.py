"""Host-dependent roots for recalculate_nobias, overridable by environment.

    NOBIAS_TFATLAS  root of the tfatlas tree (models/release_run_1, prediction/..., metrics/
                    recalculate_auprc/...); the AnVIL workflow rebuilds that layout under /project
    NOBIAS_SCRATCH  large files: bpnet-predict outputs, probe features, probe scores
                    (kali default: /srv/scratch/vir/recalculate_nobias;
                     Sherlock jobs: a directory under $SCRATCH)
    NOBIAS_OUT      per-model metric TSVs (default: <this dir>/metrics_per_model)
    NOBIAS_REF      hg38 FASTA (+ .fai, hg38.chrom.sizes alongside); Sherlock jobs
                    stage it to node-local disk (default: the Oak copy)
    NOBIAS_PROCESSED  per-experiment bigWig directories (default: tfatlas/processed_data);
                    Sherlock jobs stage each experiment's bigWigs to node-local disk
    NOBIAS_PY       python that runs the old auprc_auroc_calculations.py
                    (default: the current interpreter; the bpnet envs on kali
                     and Sherlock both carry sklearn 1.0.2 / pandas 1.3.5 / tqdm)
"""

import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TFATLAS = Path(os.environ.get("NOBIAS_TFATLAS", "/oak/stanford/groups/akundaje/vir/tfatlas"))
RELEASE = TFATLAS / "models" / "release_run_1"
RELEASED_PRED = Path(os.environ.get(       # released with-bias predictions; jobs may stage a local copy
    "NOBIAS_RELEASED_PRED", str(TFATLAS / "prediction" / "prediction_all_regions_test_chroms" / "release_run_1")))
NEG_DIR = TFATLAS / "metrics" / "recalculate_auprc" / "gc_negatives_ranked_idr_removed"
SCRATCH = Path(os.environ.get("NOBIAS_SCRATCH", "/srv/scratch/vir/recalculate_nobias"))
OUT = Path(os.environ.get("NOBIAS_OUT", str(HERE / "metrics_per_model")))
PY = os.environ.get("NOBIAS_PY", sys.executable)
REF = Path(os.environ.get("NOBIAS_REF", str(TFATLAS / "references" / "hg38" / "hg38.genome.fa")))
CHROM_SIZES = REF.parent / "hg38.chrom.sizes"
PROCESSED = Path(os.environ.get("NOBIAS_PROCESSED", str(TFATLAS / "processed_data")))

PRED_ROOT = SCRATCH / "predictions"
FEAT_ROOT = SCRATCH / "probe_features"
SCORE_ROOT = SCRATCH / "probe_scores"
