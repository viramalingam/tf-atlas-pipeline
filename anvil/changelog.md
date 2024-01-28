# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)


## [v2.1.0-rc.4] - 2024-01-28

1. cleaned up preprocessing script



## [v2.1.0-rc.4] - 2024-01-27

1. cleaned up preprocessing script


## [v2.1.0-rc.2] - 2024-01-11

1. added additional checks to ignore peaks that fall outside the chroms start stop for gc_matched negative script.


## [v2.1.0-rc.1] - 2024-01-08

1. created shap_h5_to_bw wdl and shell script files. 
2. Changed the git tag and docker tag versions used for shap; 
3. changed the git tag and docker tag used for predict on bed file script from main to v2.1.0-rc.1



## [v2.0.0-rc.1] - 2023-03-29

1. fixed rc augmentation. added rc-averaging for prediction. Uses the newer bpnet-refactor repo that combines basepairmodels, mseqgen, genomiclossesandarchs. Changed profile metrics normalization. Exposed seed in shap to prevent same shuffles being used for background calculation in all the folds.



## [v1.6.11] - 2022-10-04

1. change name of ${shap_dir}/counts/profile*scores*h5 to ${shap_dir}/counts/profile_scores.h5 to accomodate different file names like from mean_shap scores

## [v1.6.10] - 2022-10-04

1. mean shap score calculation in anvil

## [v1.6.9] - 2022-10-04

1. merged with branch that uses modisco_lite

## [v1.6.8]

## [v1.6.7]

## [v1.6.6] - 2022-09-04
1. changed branch version in wdl for performance reports

## [v1.6.5] - 2022-08-29
1. merged with dev branch which supports saving shap scores with blosc compression and opening these shap scores for modisco.

## [v1.6.4] - 2022-08-25
1. bug fix for peak wise training. group_df.sort_values(by='group_counts').reset_index(drop=True)

## [v1.6.3] - 2022-08-24
1. bug fix for shap --branch v1.6.2

## [v1.6.2] - 2022-08-24
1. shap pipeline now handles experiments with no control.

## [v1.6.1] - 2022-08-24
1. changed wdl file for shap

## [v1.6.0] - 2022-08-23
merged with the branch dev_peak_wise_training
1. fixed the random seed issue
2. code supports peak_wise training



## [v1.5.0] - 2022-08-11
### removed
merged with the branch dev_fix_val_sampling
1. fixed the validation sampling using a random seed
2. changed the early stopping patience to 10 and reduce-lr-on-plateau-patience to 5

## [v1.4.2] - 2022-07-18
### removed
1.remove preemptible from modelling, shap

## [v1.4.1] - 2022-07-18
### fixed
1. added preemptible = 1 to the modelling and shap runs



## [v1.4.0] - 2022-07-13
### fixed
1. **fixed code for the gc_matched negative. It was producing -1057 for the summit values instead of 1057.**



## [v1.3.13] - 2022-06-26
### Added
1. **code for running modisco in sherlock and modisco version v0.5.15.0 in docker vivekramalingam/tf-atlas:gcp-modeling_v1.3.1**


## [v1.3.12] - 2022-06-17
### Added
1. merged with dev branch for the **test_motifs scripts to work with models trained without control. Also test_motifs script export jsd between background regions and motif inserted sequences.**


## [v1.3.11] - 2022-06-14
### Added
1. merged with dev branch to create model_stats (alpha, beta, bias_terns of the models)


## [v1.3.10] - 2022-06-08
### Added
1. bugfix

## [v1.3.9] - 2022-06-08
### Added
1. bugfix

## [v1.3.8] - 2022-06-08
### Added
1. bugfix

## [v1.3.7] - 2022-06-08
### Added
1.**feature to test motif effects on models.**
2. merged with the dev_test_motif_effects branch

## [v1.3.6] - 2022-06-02
### Added
1.big fix to feature to set instance memory based on peak file size for basic stats calculation

## [v1.3.5] - 2022-06-02
### Added
1.added feature to set instance memory based on peak file size for basic stats calculation

## [v1.3.4] - 2022-06-02
### Added
1. fix the docker image for the shap

## [v1.3.3] - 2022-06-02
### Added
1. same as v1.3.2a

## [1.3.2a] - 2022-06-01
### Added
1. bug fixes.

## [1.3.2] - 2022-06-01
### Added
1. bug fixes.

## [1.3.1] - 2022-06-01
### Added
1. bug fixes.

## [1.3.0] - 2022-06-01
### Added
1. **shap works with the single multinomial models.** Merged with the dev branch.
2. bug fixes.
3. wdl files use the correct git tag v1.3.0
4. **support multiple test chromosomes.** 

## [1.2.2] - 2022-05-26
### Added
added compile false to shap; added loss=None in training; bug fix; fixed tag version in wdl files;

## [1.2.1] - 2022-05-25
### Added
bug fix. Changed the wdl files to use the correct git tag v1.2.1.


## [1.2.0] - 2022-05-25
### Added
merged branch dev_without_bias_prediction_metrics. We now also calculated metrics with just providing zeros as bias track during prediction eventhough the models are trained with bias. This could tell us how much the models are using the sequence component to predict the signal.


## [1.1.0] - 2022-05-23
### Added
1. "Added activation after the dilation layer eight. Changed the ratio of pos to neg in the negative file for the test chromosome. Updated all wdl files to use docker v1.1.0"

## [1.0.1d] - 2022-05-22
### Added
1. Started saving combined bed files in the model folder.

## [1.0.1] - 2022-05-22
### Added
1. Merged the dockerfile and the anvil pipeline scripts to one repo
2. Traking the github versions and pipeline scripts download a specific version
3. WDL files are using a specific version of dockerimage for tracking purposes. dockerimages are tagged.


## [1.0.0] - 2022-05-22
### Added
Starting to Merge the dockerfile and the anvil pipeline scripts to one repo. Started traking the github versions and pipeline scripts download a specific version. **Incomplete. Testing the tagging sytem.**

# log of the docker builds


## vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1 - 2024-01-08
- Fixed shap h5 save problem for models without wce and the shap bw writing change from "first region based" to "nearest peak" when there are overlapping regions.


## vivekramalingam/tf-atlas:gcp-modeling_v1.6.5- 2022-08-23
- hdf5plugin to support blosc compression for shap saving and opening in motif discovery
- vivekramalingam_tf-atlas_gcp-modeling_v1.6.5.sif is build from this version - used for modisco production_run_1

## vivekramalingam/tf-atlas:gcp-modeling_dev
- used for shap calculations for the ZNFs. Same as v1.6.5. Only difference is that motif discovery script has import deepdish. e102fce64557

## vivekramalingam/tf-atlas:gcp-modisco_modiscolite
- used for modisco runs

## vivekramalingam/tf-atlas:gcp-modeling_v1.6.2- 2022-08-23
Shap pipeline supports experiments with no control.

## vivekramalingam/tf-atlas:gcp-modeling_v1.6.0- 2022-08-23
Modelling now supports peak-wise training schema . Used joint multinomial as before.


## vivekramalingam/tf-atlas:gcp-modeling_v1.5.0- 2022-08-11
Has fixed validation sampling and adjusted early stopping patience to 10 and reduce-lr-on-plateau-patience to 5. Used joint multinomial as before.

## vivekramalingam/tf-atlas:gcp-modeling_v1.3.1 - 2022-06-26
Same as the docker used for the modeling runs but the modisco repo is changed to v0.5.15.0
- vivekramalingam_tf-atlas_gcp-modeling_v1.3.1.sif is build from this version.

## vivekramalingam/tf-atlas:gcp-modeling_v1.3.0 - 
Docker used for the modeling run-id-3. Has single multinomial and count loss for training and prediction.


# log of dev branches