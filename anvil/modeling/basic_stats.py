import pandas as pd
import pyBigWig
import numpy as np
from tqdm import tqdm

import argparse

# need full paths!
parser = argparse.ArgumentParser(description="calculates and saves of pearson and spearman correltations between log(sum(chip tracks)+1) and  log(sum(control tracks)+1) in given peak regions. Peaks should be in the ENCODE format. Also saves number of peaks")
parser.add_argument("-p", "--peak-path", type=str, required=True, help="peaks file")
parser.add_argument("--pos-bw-path", type=str, required=True, help="actual ChIP bigwig positive tracks file")
parser.add_argument("--neg-bw-path", type=str, required=True, help="actual ChIP bigwig negative tracks file")
parser.add_argument("--control-pos-bw-path", type=str, required=True, help="control bigwig positive tracks file")
parser.add_argument("--control-neg-bw-path", type=str, required=True, help="control bigwig negative tracks file")
parser.add_argument("-w", "--calculation-width", type=int,default=1000, help="width around the peaks to calculate the signals for correlations")
parser.add_argument("-o", "--output-dir", type=str, default='.', help="output files directory path")

args = parser.parse_args()

def plot_control_chip_for_experiment(peak_path,
                                     pos_bw_path,
                                     neg_bw_path,
                                     control_pos_bw_path,
                                     control_neg_bw_path,
                                     calculation_width=1000,
                                     from_peak_path=True,
                                     peaks=None): 
    if from_peak_path:
        all_peak_coords = pd.read_csv(peak_path,sep="\t",header=None)
    else:
        if peaks:
            all_peak_coords = peaks
        else:
            raise Exception("Sorry, either peaks or peak path requires")

    pos_bw = pyBigWig.open(pos_bw_path)
    neg_bw = pyBigWig.open(neg_bw_path)

    pos_scores = []
    neg_scores = []

    control_pos_bw = pyBigWig.open(control_pos_bw_path)
    control_neg_bw = pyBigWig.open(control_neg_bw_path)

    control_pos_scores = []
    control_neg_scores = []

    for i,row in tqdm(all_peak_coords.iterrows(), total=all_peak_coords.shape[0]) :
        try:
            pos_scores.append(np.asarray(pos_bw.values(row[0], row[1]+row[9]-(calculation_width//2),row[1]+row[9]+(calculation_width//2))))
        except:
            pos_scores.append(np.zeros(calculation_width))
        try:
            neg_scores.append(np.asarray(neg_bw.values(row[0], row[1]+row[9]-(calculation_width//2),row[1]+row[9]+(calculation_width//2))))
        except:
            neg_scores.append(np.zeros(calculation_width))
        try:
            control_pos_scores.append(np.asarray(control_pos_bw.values(row[0], row[1]+row[9]-(calculation_width//2),row[1]+row[9]+(calculation_width//2))))
        except:
            control_pos_scores.append(np.zeros(calculation_width))
        try:
            control_neg_scores.append(np.asarray(control_neg_bw.values(row[0], row[1]+row[9]-(calculation_width//2),row[1]+row[9]+(calculation_width//2))))
        except:
            control_neg_scores.append(np.zeros(calculation_width))


    pos_scores = np.nan_to_num(np.vstack(pos_scores))
    neg_scores = np.nan_to_num(np.vstack(neg_scores))

    control_pos_scores = np.nan_to_num(np.vstack(control_pos_scores))
    control_neg_scores = np.nan_to_num(np.vstack(control_neg_scores))
    
    return {'pos_scores':pos_scores,
            'neg_scores':neg_scores,
            'control_pos_scores':control_pos_scores,
            'control_neg_scores':control_neg_scores,
            'number_of_peaks':len(all_peak_coords)}
    
    
scores = plot_control_chip_for_experiment(peak_path=args.peak_path,
                                          pos_bw_path=args.pos_bw_path,
                                          neg_bw_path=args.neg_bw_path,
                                          control_pos_bw_path=args.control_pos_bw_path,
                                          control_neg_bw_path=args.control_neg_bw_path,
                                          calculation_width=args.calculation_width)

from scipy.stats import spearmanr
from scipy.stats import pearsonr
       
pearson_value = pearsonr(np.log(scores['pos_scores'].sum(axis=1)+scores['neg_scores'].sum(axis=1)+1),
                     np.log(scores['control_pos_scores'].sum(axis=1)+scores['control_neg_scores'].sum(axis=1)+1))[0]
spearman_value = spearmanr(np.log(scores['pos_scores'].sum(axis=1)+scores['neg_scores'].sum(axis=1)+1),
          np.log(scores['control_pos_scores'].sum(axis=1)+scores['control_neg_scores'].sum(axis=1)+1))[0]

with open(f'{args.output_dir}/pearson.txt', 'w') as f:
    f.write(str(pearson_value))
    
with open(f'{args.output_dir}/spearman.txt', 'w') as f:
    f.write(str(spearman_value))

with open(f'{args.output_dir}/number_of_peaks.txt', 'w') as f:
    f.write(str(scores['number_of_peaks']))
    
