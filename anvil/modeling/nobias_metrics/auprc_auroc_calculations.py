# Source: github.com/viramalingam/tf-atlas-pipeline anvil/modeling/auprc_auroc_calculations.py
# @ 2ac18f9f (2024-01-31), the script behind the AnVIL auprc/auroc_idr_removed columns.
# Only change: --score. "strand0" scores with pred_logcounts[:,0] (original behaviour,
# reproduces AnVIL exactly); "total" (default) scores with logaddexp over both strands,
# which equals the count head output (predict.py splits it across strands by the
# profile head's strand mass).
import argparse
from tqdm import tqdm
import random
import csv
import h5py
import pandas as pd
import numpy as np

def none_or_str(value):
    if value == "None":
        return None
    return value

def metrics_argsparser():
    parser=argparse.ArgumentParser(description="generate ")
    parser.add_argument("--h5_file",required=True, help="h5 file containing the predictions")
    parser.add_argument("-p","--peak_file", required=True, help="peak bed file in encode format; contains 5th column value 1")
    parser.add_argument("-n","--neg_file", required=True, help="negative bed file; contains 5th column value 0")
    parser.add_argument("-o","--output_dir", required=True, help="directory for the output")
    parser.add_argument("--chroms", nargs='+', required=True, help="test chromosome")
    parser.add_argument("--output_length", type=int, default=1000, help="negative bed file")
    parser.add_argument("--score", choices=["strand0", "total"], default="total",
                        help="strand0: pred_logcounts[:,0] (original behaviour); "
                             "total: log total predicted counts over both strands (= count head output)")
    parser.add_argument('--test-indices-file', type=none_or_str,
                        help="path to indices file to filter the peaks and background combined dataframe for prediction.", default=None)

    return parser

parser = metrics_argsparser()
args = parser.parse_args()

f = h5py.File(args.h5_file,'r')
peaks_df = pd.read_csv(args.peak_file,header=None,sep="\t")

print("peaks_df:",peaks_df)

negs_df = pd.read_csv(args.neg_file,header=None,sep="\t")

print("negs_df:",negs_df)

all_regions_df = pd.concat([negs_df,peaks_df]).reset_index(drop=True)
all_regions_df.columns=['chroms','start','end','name','label','strand','p','q','x','summit']
all_regions_df['end']=(all_regions_df['start']+all_regions_df['summit'])+(args.output_length//2)
all_regions_df['start']=(all_regions_df['start']+all_regions_df['summit'])-(args.output_length//2)

print("all_regions_df:",all_regions_df)

pred_logcounts = f['predictions']['pred_logcounts'][()]
h5_df = pd.DataFrame({'chroms':f['coords']['coords_chrom'][()].astype('U8'),
                     'start':f['coords']['coords_start'][()],
                     'end':f['coords']['coords_end'][()],
                     'log_counts':(pred_logcounts[:,0] if args.score == "strand0" else
                                   np.logaddexp(pred_logcounts[:,0], pred_logcounts[:,1])).tolist()})

print("h5_df:",h5_df)

predictions = pd.merge(all_regions_df, h5_df, how='inner', on=['chroms','start','end'])

print("predictions:",predictions)

if args.test_indices_file!=None:
        # make sure the background_train_indices_file file exists
        if not os.path.isfile(args.test_indices_file):
            raise NoTracebackException(
                "File not found: {} ".format(test_indices_file))

        # load test_indices
        f = open(args.test_indices_file)
        lines = f.readlines()
        test_indices = [int(line.rstrip('\r').rstrip('\n'))
                                  for line in lines]
        f.close()
else:
    test_indices = None


if args.chroms == ['None']:
    args.chroms = None

if args.chroms!=None:
    predictions = predictions[predictions['chroms'].isin(args.chroms)].reset_index(drop=True)
if test_indices!=None:
    predictions = predictions.loc[predictions.index[test_indices]].reset_index(drop=True)

from sklearn.metrics import roc_auc_score, average_precision_score

print("predictions['label'].astype(int):",predictions['label'].astype(int))
print("predictions['log_counts']:",predictions['log_counts'])

print('average_precision_score:',average_precision_score(predictions['label'].astype(int),predictions['log_counts']))
print('roc_auc_score:',roc_auc_score(predictions['label'].astype(int),predictions['log_counts']))

with open('{}/auprc.txt'.format(args.output_dir), "w+") as f:
        f.write(str(round(average_precision_score(predictions['label'].astype(int),predictions['log_counts']),3)))
        f.close
with open('{}/auroc.txt'.format(args.output_dir), "w+") as f:
        f.write(str(round(roc_auc_score(predictions['label'].astype(int),predictions['log_counts']),3)))
        f.close

with open('{}/auprc_baseline.txt'.format(args.output_dir), "w+") as f:
        f.write(str(round(sum(predictions['label'])/len(predictions['label']),3)))
        f.close
