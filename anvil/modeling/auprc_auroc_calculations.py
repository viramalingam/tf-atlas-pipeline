import argparse
from tqdm import tqdm
import random
import csv 
import h5py
import pandas as pd

def metrics_argsparser():
    parser=argparse.ArgumentParser(description="generate ")
    parser.add_argument("--h5_file",required=True, help="h5 file containing the predictions")
    parser.add_argument("-p","--peak_file", required=True, help="peak bed file in encode format; contains 5th column value 1")
    parser.add_argument("-n","--neg_file", required=True, help="negative bed file; contains 5th column value 0")
    parser.add_argument("-o","--output_dir", required=True, help="directory for the output")
    parser.add_argument("--chroms", nargs='+', required=True, help="test chromosome")
    parser.add_argument("--output_length", type=int, default=1000, help="negative bed file")
    return parser

parser = metrics_argsparser()
args = parser.parse_args()

f = h5py.File(args.h5_file,'r')
peaks_df = pd.read_csv(args.peak_file,header=None,sep="\t")
peaks_df.columns=['chroms','start','end','name','label','strand','p','q','x','summit']
peaks_df['end']=(peaks_df['start']+peaks_df['summit'])+(args.output_length//2)
peaks_df['start']=(peaks_df['start']+peaks_df['summit'])-(args.output_length//2)
peaks_df['label']=1

negs_df = pd.read_csv(args.neg_file,header=None,sep="\t")
negs_df.columns=['chroms','start','end','name','label','strand','p','q','x','summit']
negs_df['end']=(negs_df['start']+negs_df['summit'])+(args.output_length//2)
negs_df['start']=(negs_df['start']+negs_df['summit'])-(args.output_length//2)
peaks_df['label']=0

all_regions_df = pd.concat([negs_df,peaks_df]).reset_index(drop=True)


h5_df = pd.DataFrame({'chroms':f['coords']['coords_chrom'][()],
                     'start':f['coords']['coords_start'][()],
                     'end':f['coords']['coords_end'][()],
                     'log_counts':(f['predictions']['pred_logcounts'][()][:,0]).tolist()})

predictions = pd.merge(all_regions_df, h5_df, how='inner', on=['chroms','start','end'])
predictions = predictions[predictions['chroms'].isin(args.chroms)].reset_index(drop=True)

from sklearn.metrics import roc_auc_score, average_precision_score

print('average_precision_score:',average_precision_score(predictions['label'].astype(int),predictions['log_counts']))
print('roc_auc_score:',roc_auc_score(predictions['label'].astype(int),predictions['log_counts']))

with open('{}/auprc.txt'.format(args.output_dir), "w+") as f:
        f.write(str(round(average_precision_score(predictions['label'].astype(int),predictions['log_counts']),3)))
        f.close
with open('{}/auroc.txt'.format(args.output_dir), "w+") as f:
        f.write(str(round(roc_auc_score(predictions['label'].astype(int),predictions['log_counts']),3)))
        f.close