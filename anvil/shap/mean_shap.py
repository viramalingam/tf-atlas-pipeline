import numpy as np
import subprocess as sp
import os
import pandas as pd

import h5py
import hdf5plugin

def calculate_mean_shape(experiment):
    print(f"{experiment} \n")
    if not os.path.exists(f'/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/mean_shap/{experiment}'):
        os.mkdir(f'/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/mean_shap/{experiment}')
    for head in ['counts','profile']:
        hyp_scores_lst=[]
        chrom_lst=[]
        start_lst=[]
        end_lst=[]
        input_seqs_lst=[]
        for fold in range(5):
            try:
                f = h5py.File(f'/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/fold{fold}/{experiment}/{head}_scores.h5', 'r')
                hyp_scores_lst.append(f['hyp_scores'][()])
                chrom_lst.append(f['coords_chrom'][()])
                start_lst.append(f['coords_start'][()])
                end_lst.append(f['coords_end'][()])
                input_seqs_lst.append(f['input_seqs'][()])
                f.close()
            except:
                print(f'/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/fold{fold}/{experiment}/{head}_scores.h5')
                print(f"{fold} {experiment} {head} does not exist")
                file1 = open("/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/experiments_without_5folds.txt", "a")  # append mode
                file1.write(f"{experiment} \n")
                file1.close()

        if(sum([any(all(element == chrom_lst[0]) for element in chrom_lst),
         any(all(element == start_lst[0]) for element in start_lst),
         any(all(element == end_lst[0]) for element in end_lst)])==3):

            hyp_scores_mean = np.nanmean(np.array(hyp_scores_lst),axis=0)

            num_examples = hyp_scores_mean.shape[0]
            
            f = h5py.File(f'/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/mean_shap/{experiment}/{head}_scores.h5', "w")

            coords_chrom_dset = f.create_dataset(
                "coords_chrom", (num_examples,),
                dtype=h5py.string_dtype(encoding="ascii"), **hdf5plugin.Blosc()
            )
            coords_chrom_dset[:] = chrom_lst[0]

            coords_start_dset = f.create_dataset(
                "coords_start", (num_examples,), dtype=int, **hdf5plugin.Blosc()
            )
            coords_start_dset[:] = start_lst[0]

            coords_end_dset = f.create_dataset(
                "coords_end", (num_examples,), dtype=int, **hdf5plugin.Blosc()
            )
            coords_end_dset[:] = end_lst[0]

            hyp_scores_dset = f.create_dataset(
                "hyp_scores", (num_examples, hyp_scores_mean.shape[1], hyp_scores_mean.shape[2]), **hdf5plugin.Blosc()
            )
            hyp_scores_dset[:, :, :] = hyp_scores_mean

            input_seqs_dset = f.create_dataset(
                "input_seqs", (num_examples, hyp_scores_mean.shape[1], hyp_scores_mean.shape[2]), **hdf5plugin.Blosc()
            )
            input_seqs_dset[:, :, :] = input_seqs_lst[0]

            f.close()
        else:
            file2 = open("/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/experiments_without_equal_shaps.txt", "a")  # append mode
            file2.write(f"{experiment} \n")
            file2.close()
            
experiments_df = pd.read_csv("/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/mean_shap/production_experiment_5_fold_performance_and_shap.tsv",sep="\t")

# from multiprocessing import Pool
# with Pool(10) as p:
#     p.map(calculate_mean_shape, experiments_df['entity:production_experiment_id'].to_list())
    
file1 = open('/oak/stanford/groups/akundaje/vir/tfatlas/shap/production_run_1/mean_shap/not_done_experiments.txt', 'r')
experiments = [line.strip('\n') for line in file1.readlines()]
from multiprocessing import Pool
with Pool(5) as p:
    p.map(calculate_mean_shape, experiments)