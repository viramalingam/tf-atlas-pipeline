#!/usr/bin/env python
"""Affinity distillation (Alexandari et al. 2023) for released BPNet models and
models trained with bias = 0, on gcPBM probes.

For each 36 bp probe q and background b (2114 bp), q replaces the centre of b
(zero-based half-open slice [1039, 1075), 1039 bases on each side, as in the
published code and the paralog_specificity engine) and the score is

    AD(q) = mean over b of [ lc(b with q) - lc(b) ]

where lc is the model's log-counts output (the raw scalar of the counts head,
layer logcounts_predictions, not the per-strand values bpnet-predict writes),
averaged over the sequence and its reverse complement, with every bias input
zero. Ported from paralog_specificity/lib/bpnet_engine.py scan_inserts (torch,
bpnet-lite) to the Keras stack of the release (TF 2.4.1, bpnet 0.4.0), so it
runs in the Terra docker image unchanged.

The counts output is a linear Dense layer on [pooled sequence trunk, logsumexp
of the per-strand counts bias input], so lc(s, c) = h(s) + g(c) and AD, a
difference between two sequences scored with the same bias input, is the same
for the released model with its real bias, with bias = 0 after training, or with
any bias value. Every run checks that on the loaded model's graph and
numerically (deltas with a non-flat, strand-asymmetric bias input, the strands
swapped for the reverse complement as in predict.py, against zero bias), and
fails if either check does not hold.

Engines: --engine fast (default) runs each background once and recomputes, for every
probe, only the window of each layer the centred insert changes (WindowedScorer; exact, about
6x faster than the full pass for the released architecture); --engine full puts every
sequence through the Keras model (CountsScorer). Every fast run checks itself against the
full engine on 64 random probes x 4 background pairs and fails above --check-tol.

Backgrounds: --n-peak-backgrounds K of the experiment's peaks (summit-centred 2114 bp
windows inside the chromosome, ACGT only, all chromosomes of the peaks file), drawn in a
seeded random order without replacement, each dinucleotide shuffled with a seed that
depends only on --peak-seed and the peak, and followed by its reverse complement (2K
records). The first K peaks of a larger panel are therefore exactly the K-peak panel.
This is the background type of the published evaluation code. Realized panel:
panel_peaks.fa.

Outputs in --out-dir:
  scores.tsv.gz      one row per probe: probe_index, the library's columns
                     (ID_REF, ID, Sequence, all measured columns), measured
                     (= --column), ad_<model>, sd_<model>
                     (SD over background records; descriptive, not a standard error)
  metrics.tsv        Pearson / Spearman of each score vs measured, all probes and
                     non-negative-control probes (ID != NegCtrl)
  <metric>_<score>.txt   one number per file for the WDL (read_float)
  bias_check_max_abs_delta_difference.txt
  check.json         versions, hashes (scorer, inputs, models, panels), timings, checks
  panel_peaks.txt, panel_peaks.fa
  deltas.npz / deltas_<score>.npy   (--save-deltas npz|npy) probe x record deltas
                     (rows = distinct probe sequences in sorted order) and baselines

Usage:
  python affinity_distillation.py --models released=DIR_OR_TAR bias0=DIR_OR_TAR \
      --probes ETS_gcpbm.tsv --column Gabpa_100nM \
      --peaks EXP_peaks.bed --fasta hg38.fa --n-peak-backgrounds 200 \
      [--check-n 64] [--save-deltas npz] --out-dir out/
"""
import argparse
import hashlib
import json
import os
import sys
import tarfile
import time
from pathlib import Path

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--models", nargs="+", required=True,
                help="NAME=PATH: a SavedModel directory, an <EXP>_split000.tar, or a "
                     "comma-separated list of files containing exactly one *_split000.tar")
ap.add_argument("--probes", required=True, help="gcPBM TSV with ID, Sequence and the --column")
ap.add_argument("--column", required=True, help="measured gcPBM column, e.g. Gabpa_100nM")
ap.add_argument("--peaks", required=True, help="EXP_peaks.bed (narrowPeak, summit offset in column 10)")
ap.add_argument("--fasta", required=True, help="hg38 FASTA (with .fai) for --peaks")
ap.add_argument("--n-peak-backgrounds", type=int, required=True,
                help="shuffled peaks, each with its reverse complement")
ap.add_argument("--peak-seed", type=int, default=20261009)
ap.add_argument("--probe-subset", type=int, default=0,
                help="score a fixed random subset of N probes (0 = all)")
ap.add_argument("--probe-seed", type=int, default=0)
ap.add_argument("--allow-exclusions", action="store_true",
                help="drop probes that are not 36 bp ACGT or lack a finite measurement "
                     "(default: fail if there are any)")
ap.add_argument("--check-n", type=int, default=64,
                help="random probes for the bias-invariance check (0 = skip)")
ap.add_argument("--check-tol", type=float, default=1e-4)
ap.add_argument("--batch-size", type=int, default=512, help="probes per model call (x2 with the RC)")
ap.add_argument("--engine", choices=["fast", "full"], default="fast",
                help="fast: run each background once and recompute only the layer windows the insert "
                     "changes (exact; checked against full on a sample every run); full: every "
                     "sequence through the Keras model")
ap.add_argument("--fast-batch-size", type=int, default=1024, help="probes per windowed call")
ap.add_argument("--engine-check-n", type=int, default=64,
                help="random probes (x 4 background pairs) for the fast-vs-full check")
ap.add_argument("--gpu", default=None, help="CUDA_VISIBLE_DEVICES (default: leave as is)")
ap.add_argument("--allow-cpu", action="store_true", help="run without a GPU (local tests)")
ap.add_argument("--save-deltas", nargs="?", const="npy", choices=["npy", "npz"], default=None)
ap.add_argument("--out-dir", required=True)
a = ap.parse_args()
if a.gpu is not None:
    os.environ["CUDA_VISIBLE_DEVICES"] = str(a.gpu)

import numpy as np
import pandas as pd
import scipy
import tensorflow as tf
# TF 2.4 runs convolutions / matmuls in TF32 on Ampere and newer GPUs by default;
# keep FP32 as on the T4 the release was predicted with.
tf.config.experimental.enable_tensor_float_32_execution(False)
for g in tf.config.list_physical_devices("GPU"):
    tf.config.experimental.set_memory_growth(g, True)
from tensorflow.keras.models import Model, load_model

sys.path.insert(0, "/oak/stanford/groups/akundaje/vir/tfatlas/eval/src")
import bpnet  # noqa: E402
import bpnet.model.arch  # noqa: F401,E402  (same bootstrap as bpnet-predict)
from bpnet.generators import sequtils  # noqa: E402
from bpnet.utils.shaputils import dinuc_shuffle  # noqa: E402

INPUT_LEN, PROBE_LEN = 2114, 36
START = (INPUT_LEN - PROBE_LEN) // 2          # 1039, as in the published code
END = START + PROBE_LEN                       # 1075 (exclusive)


def package_version(name):
    try:
        import pkg_resources
        return pkg_resources.get_distribution(name).version
    except Exception:
        return "?"


def one_hot(seqs, length):
    return sequtils.one_hot_encode(list(seqs), length).astype(np.float32)


def read_fasta(path):
    names, seqs, cur = [], [], []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if line.startswith(">"):
                if cur:
                    seqs.append("".join(cur).upper())
                names.append(line[1:].split()[0])
                cur = []
            elif line:
                cur.append(line)
    if cur:
        seqs.append("".join(cur).upper())
    return names, seqs


def revcomp(s):
    return s.translate(str.maketrans("ACGT", "TGCA"))[::-1]


def sha256(path, block=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(block), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_dir(d):
    """Content hash of a SavedModel directory (relative paths and bytes, sorted)."""
    h = hashlib.sha256()
    for p in sorted(Path(d).rglob("*")):
        if p.is_file():
            h.update(str(p.relative_to(d)).encode())
            h.update(sha256(p).encode())
    return h.hexdigest()


def sha256_seqs(seqs):
    return hashlib.sha256("\n".join(seqs).encode()).hexdigest()


def resolve_model(spec, work):
    """-> (SavedModel directory, sha256 of the tar or of the directory contents)."""
    paths = spec.split(",")
    if len(paths) == 1 and os.path.isdir(paths[0]):
        return paths[0], "dir:" + sha256_dir(paths[0])
    tars = [p for p in paths if p.endswith("_split000.tar")]
    if len(tars) != 1:
        raise ValueError(f"expected exactly one *_split000.tar in {spec[:300]}, got {len(tars)}")
    tar = tars[0]
    dest = Path(work) / hashlib.md5(os.path.abspath(tar).encode()).hexdigest()[:10]
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tar) as t:
        t.extractall(dest)
    sub = [p for p in dest.iterdir() if p.is_dir()]
    if len(sub) != 1:
        raise ValueError(f"{tar}: expected one directory inside, got {sub}")
    return str(sub[0]), "tar:" + sha256(tar)


def ancestors(layer, seen=None):
    """Names of every layer feeding `layer` (Keras functional graph)."""
    seen = set() if seen is None else seen
    for node in layer._inbound_nodes:
        inbound = node.inbound_layers
        for l in (inbound if isinstance(inbound, (list, tuple)) else [inbound]):
            if l.name not in seen:
                seen.add(l.name)
                ancestors(l, seen)
    return seen


def check_counts_head(model):
    """The counts output must be lc = Dense_linear([h(sequence), g(counts bias)])."""
    out = model.get_layer("logcounts_predictions")
    if not isinstance(out, tf.keras.layers.Dense) or out.activation.__name__ != "linear" or out.units != 1:
        raise ValueError(f"logcounts_predictions is {type(out).__name__} "
                         f"({getattr(out.activation, '__name__', '?')}, units {getattr(out, 'units', '?')})")
    inbound = out._inbound_nodes[0].inbound_layers
    concat = inbound[0] if isinstance(inbound, (list, tuple)) else inbound
    if not isinstance(concat, tf.keras.layers.Concatenate):
        raise ValueError(f"logcounts_predictions is fed by {type(concat).__name__}, not Concatenate")
    branches = concat._inbound_nodes[0].inbound_layers
    kinds = []
    for b in branches:
        anc = ancestors(b) | {b.name}
        kinds.append(("sequence" in anc, "counts_bias_input_0" in anc))
    if sorted(kinds) != [(False, True), (True, False)]:
        raise ValueError(f"counts head branches are not [sequence-only, bias-only]: {kinds}")
    return "Dense(1, linear) on Concatenate[sequence-only, counts-bias-only]"


class CountsScorer:
    """RC-averaged raw log counts of the counts head, bias input `cb` (2 values, the
    per-strand log(sum + 1); swapped for the reverse complement as in predict.py)."""

    def __init__(self, m, batch_size):
        self.model = Model([m.get_layer("sequence").input, m.get_layer("counts_bias_input_0").input],
                           m.get_layer("logcounts_predictions").output)
        self.structure = check_counts_head(m)
        self.bs = batch_size
        spec = [tf.TensorSpec((START, 4), tf.float32), tf.TensorSpec((None, PROBE_LEN, 4), tf.float32),
                tf.TensorSpec((INPUT_LEN - END, 4), tf.float32), tf.TensorSpec((2,), tf.float32)]
        self._insert = tf.function(self._insert_py, input_signature=spec)
        self._plain = tf.function(self._plain_py, input_signature=[tf.TensorSpec((None, INPUT_LEN, 4), tf.float32),
                                                                   tf.TensorSpec((2,), tf.float32)])

    def _rc_avg(self, X, cb):
        """One model call on the batch and its reverse complement, then the mean."""
        n = tf.shape(X)[0]
        cb = tf.broadcast_to(cb, (n, 2))
        y = self.model([tf.concat([X, tf.reverse(X, axis=[1, 2])], axis=0),
                        tf.concat([cb, tf.reverse(cb, axis=[1])], axis=0)], training=False)[:, 0]
        return (y[:n] + y[n:]) / 2.0

    def _insert_py(self, left, mid, right, cb):
        """One background's flanks (broadcast on the device) around a batch of probes."""
        m = tf.shape(mid)[0]
        X = tf.concat([tf.broadcast_to(left, (m, START, 4)), mid,
                       tf.broadcast_to(right, (m, INPUT_LEN - END, 4))], axis=1)
        return self._rc_avg(X, cb)

    def _plain_py(self, X, cb):
        return self._rc_avg(X, cb)

    @staticmethod
    def _cb(cb):
        return np.zeros(2, np.float32) if cb is None else np.asarray(cb, np.float32).reshape(2)

    def plain(self, X, cb=None):
        c = self._cb(cb)
        return np.concatenate([self._plain(X[lo:lo + self.bs], c).numpy() for lo in range(0, len(X), self.bs)])

    def scan(self, B, Q, cb=None, log_every=0, label=""):
        """B (n_bg, 2114, 4) backgrounds, Q (n_q, 36, 4) probes -> deltas (n_q, n_bg), baseline (n_bg,)."""
        n_bg, n_q = len(B), len(Q)
        c = self._cb(cb)
        base = self.plain(B, cb)
        delta = np.empty((n_q, n_bg), np.float32)
        t0 = time.time()
        for j in range(n_bg):
            left, right = B[j, :START], B[j, END:]
            parts = [self._insert(left, Q[lo:lo + self.bs], right, c) for lo in range(0, n_q, self.bs)]
            delta[:, j] = tf.concat(parts, axis=0).numpy() - base[j]
            if log_every and (j + 1) % log_every == 0:
                el = time.time() - t0
                print(f"  {label}: {j + 1}/{n_bg} backgrounds, {el / 60:.1f} min "
                      f"({el / (j + 1) * (n_bg - j - 1) / 60:.1f} min left)", flush=True)
        if not (np.isfinite(delta).all() and np.isfinite(base).all()):
            raise FloatingPointError(f"{label}: non-finite predictions")
        return delta, base


class WindowedScorer:
    """Exact fast path for the released BPNet counts path, the same scores as CountsScorer
    with every bias input zero.

    The counts path is a valid-padding stack: main_conv_0 (kernel k0) and ReLU, then
    dilated residual layers main_dil_conv_i (kernel 3, dilation d_i) on the ReLU of the
    previous pre-ReLU sum, added to that sum cropped by d_i on each side, then ReLU; a
    global average over the last layer, a Dense(1), and the linear output layer on
    [counts head, bias branch]. A probe at the window centre ([1039, 1075)) changes only
    a fixed window of each layer: in layer-index coordinates [s - k0 + 1, e) of the first
    conv's outputs, and [lo - 2d, hi) of a dilated layer's outputs when [lo, hi) of its
    input changed (6.3x fewer multiply-adds for the released architecture). So each
    background is run once with every layer cached, and for each batch of probes only
    those windows are recomputed from the cached flanks; the global average is updated
    from the last window. The layer structure is checked on the model graph, and every
    run compares the result with CountsScorer on a random sample.

    The panel must be closed under reverse complement in pairs (records 2k, 2k + 1): for a
    centred even-length insert in an even window RC(r + q) = RC(r) + RC(q), so
        delta(q, r) = [g(r + q) + g(r' + RC(q))] / 2 - [g(r) + g(r')] / 2,  r' = RC(r),
    with g the model's raw log counts, which is CountsScorer's reverse-complement average.
    """

    def __init__(self, m, batch_size):
        g = m.get_layer

        def inbound(layer):
            x = layer._inbound_nodes[0].inbound_layers
            return [l.name for l in (x if isinstance(x, (list, tuple)) else [x])]

        def check(cond, what):
            if not cond:
                raise ValueError(f"fast engine: unexpected model structure ({what}); use --engine full")

        def conv_ok(c, k, d):
            return (isinstance(c, tf.keras.layers.Conv1D) and c.kernel_size == (k,) and c.dilation_rate == (d,)
                    and c.strides == (1,) and c.padding == "valid" and c.activation.__name__ == "linear" and c.use_bias)

        def relu_ok(r, src):
            cfg = r.get_config()
            return (isinstance(r, tf.keras.layers.ReLU) and cfg.get("max_value") is None
                    and not cfg.get("negative_slope") and not cfg.get("threshold") and inbound(r) == [src])

        c0 = g("main_conv_0")
        self.k0 = c0.kernel_size[0]
        check(conv_ok(c0, self.k0, 1) and inbound(c0) == ["sequence"], "main_conv_0")
        check(relu_ok(g("main_conv_0_relu"), "main_conv_0"), "main_conv_0_relu")
        self.W0, self.b0 = [tf.constant(w) for w in c0.get_weights()]
        self.dil, prev_sum, prev_relu, i = [], "main_conv_0", "main_conv_0_relu", 1
        names = {l.name for l in m.layers}
        while f"main_dil_conv_{i}" in names:
            c = g(f"main_dil_conv_{i}")
            d = int(c.dilation_rate[0])
            crop, add = g(f"{prev_sum}_cr"), g(f"main_add_{i}")
            check(conv_ok(c, 3, d) and inbound(c) == [prev_relu], f"main_dil_conv_{i}")
            check(isinstance(crop, tf.keras.layers.Cropping1D) and tuple(crop.cropping) == (d, d)
                  and inbound(crop) == [prev_sum], f"{prev_sum}_cr")
            check(isinstance(add, tf.keras.layers.Add)
                  and sorted(inbound(add)) == sorted([c.name, crop.name]), f"main_add_{i}")
            check(relu_ok(g(f"main_add_{i}_relu"), add.name), f"main_add_{i}_relu")
            W, b = c.get_weights()
            self.dil.append((d, tf.constant(W), tf.constant(b)))
            prev_sum, prev_relu, i = add.name, f"main_add_{i}_relu", i + 1
        check(len(self.dil) > 0, "no dilated layers")
        gap, head, out = g("main_global_avg_pooling"), g("main_counts_head"), g("logcounts_predictions")
        check(isinstance(gap, tf.keras.layers.GlobalAveragePooling1D) and inbound(gap) == [prev_relu],
              "main_global_avg_pooling")
        check(isinstance(head, tf.keras.layers.Dense) and head.units == 1 and head.activation.__name__ == "linear"
              and inbound(head) == [gap.name], "main_counts_head")
        concat = g(inbound(out)[0])
        branches = inbound(concat)
        check(isinstance(concat, tf.keras.layers.Concatenate) and branches[0] == head.name and len(branches) == 2,
              "counts head concatenation")
        self.wh, self.bh = [tf.constant(w) for w in head.get_weights()]
        self.wo, self.bo = [tf.constant(w) for w in out.get_weights()]
        # the bias branch with every bias input zero is a constant
        bias_branch = Model(g("counts_bias_input_0").input, g(branches[1]).output)
        self.bias_feat = tf.constant(bias_branch(np.zeros((1, 2), np.float32), training=False).numpy())
        n = [INPUT_LEN - self.k0 + 1]
        win = [(max(START - self.k0 + 1, 0), min(END, n[0]))]
        for d, _, _ in self.dil:
            n.append(n[-1] - 2 * d)
            lo, hi = win[-1]
            win.append((max(lo - 2 * d, 0), min(hi, n[-1])))
        self.n, self.win, self.bs = n, win, batch_size
        self._full = tf.function(self._full_py, input_signature=[tf.TensorSpec((None, INPUT_LEN, 4), tf.float32)])
        self._win = tf.function(self._win_py)

    def summary(self):
        ch = int(self.W0.shape[-1])
        full = self.n[0] * self.k0 * 4 * ch + sum(n_ * 3 * ch * ch for n_ in self.n[1:])
        part = ((self.win[0][1] - self.win[0][0]) * self.k0 * 4 * ch
                + sum((hi - lo) * 3 * ch * ch for lo, hi in self.win[1:]))
        return dict(layer_lengths=self.n, changed_positions=[hi - lo for lo, hi in self.win],
                    multiply_add_ratio=round(full / part, 2))

    def _head(self, gap):
        h = tf.matmul(gap, self.wh) + self.bh
        z = tf.concat([h, tf.broadcast_to(self.bias_feat, (tf.shape(h)[0], self.bias_feat.shape[-1]))], axis=1)
        return (tf.matmul(z, self.wo) + self.bo)[:, 0]

    def _full_py(self, X):
        S = [tf.nn.conv1d(X, self.W0, 1, "VALID") + self.b0]
        A = [tf.nn.relu(S[0])]
        for d, W, b in self.dil:
            S.append(tf.nn.conv1d(A[-1], W, 1, "VALID", dilations=d) + b + S[-1][:, d:-d])
            A.append(tf.nn.relu(S[-1]))
        return S, A, self._head(tf.reduce_mean(A[-1], axis=1))

    @staticmethod
    def _assemble(ref, new, lo, hi, p, q):
        """Rows [p, q) of a layer: the batch's values on [lo, hi), the background's elsewhere."""
        m = tf.shape(new)[0]
        a_, b_ = max(p, lo), min(q, hi)
        parts = []
        if p < a_:
            parts.append(tf.broadcast_to(ref[p:a_], (m, a_ - p, ref.shape[-1])))
        parts.append(new[:, a_ - lo:b_ - lo])
        if b_ < q:
            parts.append(tf.broadcast_to(ref[b_:q], (m, q - b_, ref.shape[-1])))
        return tf.concat(parts, axis=1) if len(parts) > 1 else parts[0]

    def _win_py(self, xb, S_ref, A_ref, sumA_last, Q):
        m = tf.shape(Q)[0]
        lo, hi = self.win[0]
        x = tf.concat([tf.broadcast_to(xb[lo:START], (m, START - lo, 4)), Q,
                       tf.broadcast_to(xb[END:hi + self.k0 - 1], (m, hi + self.k0 - 1 - END, 4))], axis=1)
        s = tf.nn.conv1d(x, self.W0, 1, "VALID") + self.b0
        act = tf.nn.relu(s)
        for i, (d, W, b) in enumerate(self.dil, start=1):
            plo, phi = lo, hi
            lo, hi = self.win[i]
            inp = self._assemble(A_ref[i - 1], act, plo, phi, lo, hi + 2 * d)
            res = self._assemble(S_ref[i - 1], s, plo, phi, lo + d, hi + d)
            s = tf.nn.conv1d(inp, W, 1, "VALID", dilations=d) + b + res
            act = tf.nn.relu(s)
        gap = (sumA_last - tf.reduce_sum(A_ref[-1][lo:hi], axis=0) + tf.reduce_sum(act, axis=1)) / self.n[-1]
        return self._head(gap)

    def scan(self, B, Q, log_every=0, label=""):
        """B (n_bg, 2114, 4) RC-closed panel, Q (n_q, 36, 4) probes -> deltas (n_q, n_bg) and the
        reverse-complement-averaged baselines (n_bg,), as CountsScorer.scan with zero bias."""
        n_bg = len(B)
        if n_bg % 2 or any(not np.array_equal(B[k + 1], B[k][::-1, ::-1]) for k in range(0, n_bg, 2)):
            raise ValueError("fast engine: the panel must hold each background followed by its reverse complement")
        QR = np.ascontiguousarray(Q[:, ::-1, ::-1])
        g_q = np.empty((len(Q), n_bg), np.float32)
        g_rq = np.empty((len(Q), n_bg), np.float32)
        g0 = np.empty(n_bg, np.float32)
        t0 = time.time()
        for j in range(n_bg):
            xb = tf.constant(B[j])
            S, A, lc = self._full(xb[None])
            S, A = [t_[0] for t_ in S], [t_[0] for t_ in A]
            g0[j] = lc.numpy()[0]
            sumA = tf.reduce_sum(A[-1], axis=0)
            for arr, QQ in ((g_q, Q), (g_rq, QR)):
                parts = [self._win(xb, S, A, sumA, tf.constant(QQ[lo:lo + self.bs])) for lo in range(0, len(QQ), self.bs)]
                arr[:, j] = tf.concat(parts, axis=0).numpy()
            if log_every and (j + 1) % log_every == 0:
                el = time.time() - t0
                print(f"  {label}: {j + 1}/{n_bg} backgrounds, {el / 60:.1f} min "
                      f"({el / (j + 1) * (n_bg - j - 1) / 60:.1f} min left)", flush=True)
        delta = np.empty_like(g_q)
        base = np.empty(n_bg, np.float32)
        for k in range(0, n_bg, 2):
            base[k] = base[k + 1] = (g0[k] + g0[k + 1]) / 2
            delta[:, k] = (g_q[:, k] + g_rq[:, k + 1]) / 2 - base[k]
            delta[:, k + 1] = (g_q[:, k + 1] + g_rq[:, k]) / 2 - base[k]
        if not (np.isfinite(delta).all() and np.isfinite(base).all()):
            raise FloatingPointError(f"{label}: non-finite predictions")
        return delta, base


def peak_panel(peaks, fasta, n, seed):
    """n eligible peaks (summit-centred 2114 bp inside the chromosome, ACGT only), in a
    seeded random order without replacement, each dinucleotide shuffled with a seed that
    depends only on `seed` and the peak, and followed by its reverse complement."""
    import pyfaidx
    b = pd.read_csv(peaks, sep="\t", header=None)
    b = b.assign(pos=b[1] + b[9]).drop_duplicates([0, "pos"]).sort_values([0, "pos"]).reset_index(drop=True)
    fa = pyfaidx.Fasta(fasta)
    elig = []
    for c, p in zip(b[0].astype(str), b["pos"].astype(int)):
        lo, hi = p - INPUT_LEN // 2, p + INPUT_LEN // 2
        if c not in fa or lo < 0 or hi > len(fa[c]):
            continue
        s = fa[c][lo:hi].seq.upper()
        if len(s) == INPUT_LEN and not set(s) - set("ACGT"):
            elig.append((c, p, s))
    if len(elig) < n:
        raise ValueError(f"only {len(elig)} eligible peaks, {n} requested")
    pick = np.random.RandomState(seed).permutation(len(elig))[:n]
    names, seqs = [], []
    for i in pick:
        c, p, s = elig[i]
        sh = dinuc_shuffle(s, 1, np.random.RandomState((seed * 1000003 + int(i)) % 2 ** 32))[0]
        names += [f"peak_{c}_{p}_fwd", f"peak_{c}_{p}_rev"]
        seqs += [sh, revcomp(sh)]
    return names, seqs, dict(chroms="all", n_peaks_in_file=int(len(b)), n_eligible=len(elig), n_sampled=int(n))


def correlations(score, y, nonneg):
    from scipy.stats import pearsonr, spearmanr
    out = {}
    for sub, m in (("all", np.ones(len(y), bool)), ("nonnegctrl", nonneg)):
        out[f"pearson_{sub}"] = float(pearsonr(score[m], y[m])[0])
        out[f"spearman_{sub}"] = float(spearmanr(score[m], y[m])[0])
        out[f"n_{sub}"] = int(m.sum())
    return out


def main():
    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    gpus = tf.config.list_physical_devices("GPU")
    if not gpus and not a.allow_cpu:
        raise SystemExit("no GPU visible to TensorFlow (use --allow-cpu for local tests)")
    info = dict(args=vars(a), started=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                scorer_sha256=sha256(__file__),
                versions=dict(tensorflow=tf.__version__, bpnet=package_version("bpnet"),
                              numpy=np.__version__, pandas=pd.__version__, scipy=scipy.__version__,
                              python=sys.version.split()[0]),
                gpus=[d.name for d in gpus], probes_sha256=sha256(a.probes), engine=a.engine)

    d = pd.read_csv(a.probes, sep="\t")
    meas = pd.to_numeric(d[a.column], errors="coerce")
    keep = d.Sequence.astype(str).str.fullmatch("[ACGT]{%d}" % PROBE_LEN) & np.isfinite(meas)
    if (~keep).any() and not a.allow_exclusions:
        raise ValueError(f"{int((~keep).sum())} probes are not 36 bp ACGT or lack a finite {a.column}")
    d = d[keep].reset_index().rename(columns={"index": "probe_index"})
    if a.probe_subset and a.probe_subset < len(d):
        d = d.sample(a.probe_subset, random_state=a.probe_seed).sort_values("probe_index").reset_index(drop=True)
    y = pd.to_numeric(d[a.column]).to_numpy(float)
    nonneg = (d.ID.astype(str) != "NegCtrl").to_numpy()
    uniq, inv = np.unique(d.Sequence.to_numpy(), return_inverse=True)
    Q = one_hot(uniq, PROBE_LEN)
    info.update(n_probes=int(len(d)), n_excluded=int((~keep).sum()), n_unique_sequences=int(len(uniq)),
                n_negctrl=int((~nonneg).sum()))
    print(f"{len(d)} probes ({len(uniq)} distinct sequences, {(~nonneg).sum()} NegCtrl), column {a.column}",
          flush=True)

    nm, sq, meta = peak_panel(a.peaks, a.fasta, a.n_peak_backgrounds, a.peak_seed)
    panels = {"peaks": (nm, sq)}
    info["peak_panel"] = dict(meta, peaks_sha256=sha256(a.peaks))
    with open(out / "panel_peaks.fa", "w") as fh:
        for n_, s_ in zip(nm, sq):
            fh.write(f">{n_}\n{s_}\n")
    info["panels"] = {k: dict(records=len(v[0]), sequences_sha256=sha256_seqs(v[1])) for k, v in panels.items()}
    for k, (nm, _) in panels.items():
        (out / f"panel_{k}.txt").write_text("\n".join(nm) + "\n")

    scores = d.copy()
    scores["measured"] = y
    rows, info["models"], saved = [], {}, {}
    model_hashes = {}
    for spec in a.models:
        name, path = spec.split("=", 1)
        mdir, digest = resolve_model(path, out / "_models")
        if digest in model_hashes.values():
            raise ValueError(f"model {name} is the same file as {[k for k, v in model_hashes.items() if v == digest]}")
        model_hashes[name] = digest
        t0 = time.time()
        keras_model = load_model(mdir, compile=False)
        sc = CountsScorer(keras_model, a.batch_size)
        info["models"][name] = dict(path=path[:300], savedmodel=mdir, sha256=digest, counts_head=sc.structure,
                                    engine=a.engine)
        fs = None
        if a.engine == "fast":
            fs = WindowedScorer(keras_model, a.fast_batch_size)
            info["models"][name]["windowed"] = fs.summary()
        for pk, (nm, sq) in panels.items():
            B = one_hot(sq, INPUT_LEN)
            scorer = fs if fs is not None else sc
            delta, base = scorer.scan(B, Q, log_every=max(1, len(B) // 10), label=f"{name}/{pk}")
            if fs is not None and a.engine_check_n:
                # the fast engine against the Keras model on random probes and background pairs
                rng = np.random.RandomState(54321)
                qi = np.sort(rng.choice(len(Q), size=min(a.engine_check_n, len(Q)), replace=False))
                pairs = np.sort(rng.choice(len(B) // 2, size=min(4, len(B) // 2), replace=False))
                bi = np.sort(np.concatenate([2 * pairs, 2 * pairs + 1]))
                d_full, b_full = sc.scan(B[bi], Q[qi])
                err = float(max(np.abs(d_full - delta[qi][:, bi]).max(), np.abs(b_full - base[bi]).max()))
                passed = bool(np.isfinite(err) and err < a.check_tol)
                info["models"][name]["engine_check"] = dict(
                    n_probes=int(len(qi)), n_backgrounds=int(len(bi)), max_abs_difference=err,
                    tolerance=a.check_tol, passed=passed)
                print(f"  {name}: fast vs full engine on {len(qi)} probes x {len(bi)} backgrounds: "
                      f"max abs difference {err:.2e}", flush=True)
                if not passed:
                    (out / "check.json").write_text(json.dumps(info, indent=2, default=str) + "\n")
                    raise ValueError(f"{name}: fast engine differs from the full engine by {err:.3e}")
            col = name
            scores[f"ad_{col}"] = delta.mean(1)[inv]
            scores[f"sd_{col}"] = delta.std(1)[inv]
            if a.save_deltas == "npy":
                np.save(out / f"deltas_{col}.npy", delta)
                np.save(out / f"baseline_{col}.npy", base)
            elif a.save_deltas == "npz":
                saved[f"deltas_{col}"], saved[f"baseline_{col}"] = delta, base
            r = correlations(scores[f"ad_{col}"].to_numpy(), y, nonneg)
            rows.append(dict(score=col, model=name, panel=pk, n_records=len(B), **r))
            print(f"{col}: " + ", ".join(f"{k} {v:.4f}" for k, v in r.items() if not k.startswith("n_")), flush=True)
            # bias invariance on random probes and background records
            if a.check_n:
                rng = np.random.RandomState(12345)
                qi = np.sort(rng.choice(len(Q), size=min(a.check_n, len(Q)), replace=False))
                bi = np.sort(rng.choice(len(B), size=min(8, len(B)), replace=False))
                cb = np.log1p(np.array([350.0, 40.0], np.float32))
                d0, _ = sc.scan(B[bi], Q[qi])
                d1, _ = sc.scan(B[bi], Q[qi], cb=cb)
                shift = sc.plain(B[bi], cb) - sc.plain(B[bi])
                err = float(np.abs(d1 - d0).max())
                passed = bool(np.isfinite(err) and err < a.check_tol)
                info["models"][name]["bias_check"] = dict(
                    n_probes=int(len(qi)), n_backgrounds=int(len(bi)), bias_input=cb.tolist(),
                    max_abs_delta_difference=err, tolerance=a.check_tol, passed=passed,
                    mean_shift_of_absolute_prediction=float(shift.mean()), shift_sd=float(shift.std()))
                if not passed:
                    (out / "check.json").write_text(json.dumps(info, indent=2, default=str) + "\n")
                    raise ValueError(f"{name}: bias check failed, max abs delta difference {err:.3e}")
        info["models"][name]["seconds"] = round(time.time() - t0, 1)
        del sc, fs, keras_model
        tf.keras.backend.clear_session()

    if saved:
        saved["sequence"] = np.asarray(uniq, dtype=str)      # unicode, loads without pickle
        np.savez_compressed(out / "deltas.npz", **saved)
    scores.to_csv(out / "scores.tsv.gz", sep="\t", index=False, float_format="%.9g")
    m = pd.DataFrame(rows)
    m.to_csv(out / "metrics.tsv", sep="\t", index=False)
    for _, r in m.iterrows():
        for k in ("pearson_all", "spearman_all", "pearson_nonnegctrl", "spearman_nonnegctrl"):
            (out / f"{k}_{r.score}.txt").write_text(f"{r[k]:.6f}\n")
    checks = [v["bias_check"]["max_abs_delta_difference"] for v in info["models"].values() if "bias_check" in v]
    if checks:
        (out / "bias_check_max_abs_delta_difference.txt").write_text(f"{max(checks):.3e}\n")
    info["finished"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    (out / "check.json").write_text(json.dumps(info, indent=2, default=str) + "\n")
    print(m.to_string(index=False))


if __name__ == "__main__":
    main()
