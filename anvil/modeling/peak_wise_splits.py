from itertools import count
import json
import argparse
import os
import random
import pandas as pd
import numpy as np
import pyBigWig
from plotnine import *

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
    parser.add_argument("--supplemental_output_path",  type=str, required=True, help="Path to store the upplemental_outputs such as the counts histgram pngs and the split beds")
    args = parser.parse_args()

    
    peak_regions_df = pd.read_csv(args.peaks, sep='\t', names=NARROWPEAK_SCHEMA)
    peak_regions_df['region']='peak'
    peak_regions_df['ind']=range(len(peak_regions_df))
    nonpeak_regions_df = pd.read_csv(args.nonpeaks, sep='\t', names=NARROWPEAK_SCHEMA)
    nonpeak_regions_df['region']='nonpeak'
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

    
        # split the data into x number of chuncks for x folds. allocate the chuncks to train, test, valid folds in unique ways
    # across folds
    chuncksets_dict={}
    for fold in range(args.number_of_folds):
        chuncksets_dict[f"chuncksets_{fold}"]=list(range(fold,len(group_df),args.number_of_folds))

    val_chuncks = list(range(0,args.number_of_folds))
    print("val_chuncks:",val_chuncks)
    
    test_chuncks = list(range(1,args.number_of_folds))+[0]
    print("test_chuncks:",test_chuncks)

    group_fold_df=pd.DataFrame(index=np.arange(len(group_df)))
    
    for fold in range(args.number_of_folds):
        group_fold_df[f"fold{fold}"]='train'
        group_fold_df[f"fold{fold}"][chuncksets_dict[f"chuncksets_{val_chuncks[fold]}"]] = 'valid'
        group_fold_df[f"fold{fold}"][chuncksets_dict[f"chuncksets_{test_chuncks[fold]}"]] = 'test'
        
    print(group_fold_df)

    for fold in range(args.number_of_folds):
        print("fold:",fold)
        len(group_fold_df[group_fold_df[f"fold{fold}"]=="train"])/len(group_fold_df)

        len(group_fold_df[group_fold_df[f"fold{fold}"]=="test"])/len(group_fold_df)

        len(group_fold_df[group_fold_df[f"fold{fold}"]=="valid"])/len(group_fold_df)


    for fold in range(args.number_of_folds):
        group_df['fold' + str(fold)] = group_fold_df['fold' + str(fold)]

    group_df
    output_path ="."
    print("Saving Splits")
    for fold in range(args.number_of_folds):
        print("fold:",fold)
        for split in ['valid','train','test']:
            temp_lst = [group_dict.get(key) for key in group_df['groups'][group_df[f"fold{fold}"]==split]] 
            peak_indices = [i['ind'] for b in map(lambda x:[x] if not isinstance(x, list) else x, temp_lst) for i in b if i['region']=='peak']
            nonpeak_indices = [i['ind'] for b in map(lambda x:[x] if not isinstance(x, list) else x, temp_lst) for i in b if i['region']=='nonpeak']
            print("split:",split)
            print("proportion of peaks:",len(peak_indices)/len(peak_regions_df))
            print("length of nonpeaks:",len(nonpeak_indices)/len(nonpeak_regions_df))

            f = open(f"{args.output_path}/loci_{split}_indices_fold{fold}.txt", "w")
            for items in peak_indices:
                f.writelines(str(items)+'\n')
            f.close()
            f = open(f"{args.output_path}/background_{split}_indices_fold{fold}.txt", "w")
            for items in nonpeak_indices:
                f.writelines(str(items)+'\n')
            f.close()
            nonpeak_regions_df.iloc[nonpeak_indices,0:10].to_csv(f"{args.supplemental_output_path}/background_peaks_{split}_fold{fold}.bed",sep="\t",header=False,index=False)
            peak_regions_df.iloc[peak_indices,0:10].to_csv(f"{args.supplemental_output_path}/peaks_{split}_fold{fold}.bed",sep="\t",header=False,index=False)
        print("\n")

    group_df["log_groupcounts"]=np.log10(group_df["group_counts"]+1)
    for fold in range(args.number_of_folds):
        print("fold:",fold)
        plot = (ggplot(group_df,aes("log_groupcounts"))
                        +facet_wrap(f"fold{fold}")
                        +geom_histogram(bins=30)
                        +theme_classic()
               )
        plot.save(f'{args.supplemental_output_path}/fold{fold}_counts_histogram_plot.png')
    

if __name__=="__main__":
    main()