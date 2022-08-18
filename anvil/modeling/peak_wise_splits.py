from itertools import count
import json
import argparse
import os
import random
import pandas as pd
import numpy as np
import pyBigWig

NARROWPEAK_SCHEMA = ["chr", "start", "end", "1", "2", "3", "4", "5", "6", "summit"]

def main(): 
    parser = argparse.ArgumentParser()
    parser.add_argument("--bigwig", type=str, required=True, help="Bigwig of tn5 insertions")
    parser.add_argument("--peaks", type=str, required=True, help="Peaks")
    parser.add_argument("--nonpeaks", type=str, required=True, help="Non-Peaks")
    parser.add_argument("--inputlen", type=int, default=2114, help="Sequence input length")
    parser.add_argument("-j", "--max_jitter", type=int, default=128, help="Maximum jitter applied on either side of region")
    parser.add_argument("--number-of-folds", type=int, default=5, help="number of folds 5, 10 etc")
    parser.add_argument("-o", "--output_path", type=str, required=True, help="Path to store the fold information")
    args = parser.parse_args()

    
    peak_regions_df = pd.read_csv(args.peaks, sep='\t', names=NARROWPEAK_SCHEMA)
    peak_regions_df['group']='peak'
    peak_regions_df['ind']=range(len(peak_regions_df))
    nonpeak_regions_df = pd.read_csv(args.nonpeaks, sep='\t', names=NARROWPEAK_SCHEMA)
    nonpeak_regions_df['group']='nonpeak'
    nonpeak_regions_df['ind']=range(len(nonpeak_regions_df))


    all_regions_df = pd.concat([peak_regions_df,nonpeak_regions_df])
    all_regions_df['pos']=all_regions_df['start']+all_regions_df['summit']
    all_regions_df.sort_values(by=['chr', 'pos'], inplace=True)
    all_regions_df=all_regions_df.reset_index(drop=True)

    print("Creating Splits")

    group_dict = {}


    cur_chrom = ''
    cur_group = ''
    last_pos = 0
    for index,row in all_regions_df.iterrows():
        if cur_chrom != '':
            if row['chr'] != cur_chrom:
                cur_chrom = row['chr']
                cur_group += 1
                group_dict[cur_group] = [row]
            else:
                if row['pos'] <= int(last_pos) + int(args.inputlen) + int(2 * args.max_jitter):
                    group_dict[cur_group].append(row)
                else:
                    cur_group += 1
                    group_dict[cur_group] = [row]
        else:
            cur_chrom = row['chr']
            cur_group = 0
            group_dict[cur_group] = [row]
        last_pos = row['pos']

    groups = []
    group_counts = []
    bw = pyBigWig.open(args.bigwig)

    for group in group_dict:
        groups.append(group)
        sum = 0
        for element in group_dict[group]:
            labels = bw.values(element['chr'], int(element['pos'] - (args.inputlen // 2)), int(element['pos'] + (args.inputlen // 2)))
            labels = np.array(labels)
            labels = np.nan_to_num(labels)
            labels = np.sum(labels)
            sum += labels
        group_counts.append(sum)
    group_df = pd.DataFrame({'groups': groups, 'group_counts': group_counts})
    group_df.sort_values(by='group_counts', inplace=True)

    
    group_fold_dict = {}
    for fold in range(args.number_of_folds):
        group_fold_dict[f"fold{fold}"]=[]



    count = 0
    valid_used = []

    for index,row in group_df.iterrows():
        if index % 10000 == 0:
            print(index)
        if count % 2 == 0:
            test_or_valid = 'valid'
        else:
            test_or_valid = 'test'
        test_or_valid_fold = random.choice([i for i in range(args.number_of_folds) if i not in valid_used])
        for fold in range(args.number_of_folds):
            if fold != test_or_valid_fold:
                group_fold_dict[f"fold{fold}"].append('train')
            else:
                group_fold_dict[f"fold{fold}"].append(test_or_valid)
        count += 1
        valid_used.append(test_or_valid_fold)
        if len(valid_used) == args.number_of_folds:
            valid_used = []


    for fold in range(args.number_of_folds):
        group_df['fold' + str(fold)] = group_fold_dict['fold' + str(fold)]

    print("Saving Splits")
    for fold in range(args.number_of_folds):
        for split in ['valid','train','test']:
            temp_lst = [group_dict.get(key) for key in group_df['groups'][group_df[f"fold{fold}"]==split]] 
            peak_indices = [i['ind'] for b in map(lambda x:[x] if not isinstance(x, list) else x, temp_lst) for i in b if i['group']=='peak']
            nonpeak_indices = [i['ind'] for b in map(lambda x:[x] if not isinstance(x, list) else x, temp_lst) for i in b if i['group']=='nonpeak']
            f = open(f"{args.output_path}/loci_{split}_indices_fold{fold}.txt", "w")
            for items in peak_indices:
                f.writelines(str(items)+'\n')
            f.close()
            f = open(f"{args.output_path}/background_{split}_indices_fold{fold}.txt", "w")
            for items in nonpeak_indices:
                f.writelines(str(items)+'\n')
            f.close()

if __name__=="__main__":
    main()