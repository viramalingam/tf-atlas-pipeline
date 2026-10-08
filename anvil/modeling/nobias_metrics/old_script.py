"""Run the old auprc_auroc_calculations.py in the calling process.

The script's code is unchanged and runs with the same arguments; running it
in-process only avoids paying interpreter start-up and pandas / sklearn
imports for every call (slow from NFS-hosted environments, e.g. Sherlock
$HOME). Returns its stdout.
"""

import contextlib
import io
import runpy
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "auprc_auroc_calculations.py"


def run(args):
    out, argv = io.StringIO(), sys.argv
    try:
        sys.argv = [str(SCRIPT)] + [str(x) for x in args]
        with contextlib.redirect_stdout(out):
            runpy.run_path(str(SCRIPT), run_name="__main__")
    except SystemExit as e:          # argparse errors
        raise RuntimeError(f"auprc_auroc_calculations.py exited ({e}): {out.getvalue()[-500:]}")
    finally:
        sys.argv = argv
    return out.getvalue()
