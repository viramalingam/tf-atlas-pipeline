# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [1.2.0] - 2022-05-23
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
