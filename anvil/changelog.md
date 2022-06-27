# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

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

## vivekramalingam/tf-atlas:gcp-modeling_v1.3.1 - 2022-06-26
Same as the docker used for the modeling runs but the modisco repo is changed to v0.5.15.0
- vivekramalingam_tf-atlas_gcp-modeling_v1.3.1.sif is build from this version.

## vivekramalingam/tf-atlas:gcp-modeling_v1.3.0 - 
Docker used for the modeling run-id-3. Has single multinomial and count loss for training and prediction.

# log of dev branches