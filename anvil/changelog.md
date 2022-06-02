# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

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
