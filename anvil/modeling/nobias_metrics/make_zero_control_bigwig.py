"""All-zero control bigWig for training with bias = 0 (run_modelling_bias0.wdl).

The zero track is written as fixed-size tiles: libBigWig's values() walks every base of each
interval that overlaps the query, so a single interval per chromosome (the first version)
made each read cost ~0.17 s on chr1 and training ~37x slower. Same chromosomes and order as
the template bigWig (hg38, 456 chroms).

usage: make_zero_control_bigwig.py TEMPLATE.bigWig OUT.bigWig [--tile 10000]
"""
import argparse

import numpy as np
import pyBigWig

p = argparse.ArgumentParser()
p.add_argument("template")
p.add_argument("out")
p.add_argument("--tile", type=int, default=10000)
a = p.parse_args()

chroms = list(pyBigWig.open(a.template).chroms().items())
bw = pyBigWig.open(a.out, "w")
bw.addHeader(chroms)
for c, n in chroms:
    starts = np.arange(0, n, a.tile, dtype=np.int64)
    ends = np.minimum(starts + a.tile, n)
    bw.addEntries([c] * len(starts), starts.tolist(), ends=ends.tolist(),
                  values=[0.0] * len(starts))
bw.close()

bw = pyBigWig.open(a.out)
assert list(bw.chroms().items()) == chroms
h = bw.header()
assert h["nBasesCovered"] == sum(n for _, n in chroms) and h["minVal"] == h["maxVal"] == 0, h
print(a.out, len(chroms), "chroms", h)
