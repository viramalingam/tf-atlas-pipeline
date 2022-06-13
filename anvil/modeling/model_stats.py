import pandas as pd
import pyBigWig
import numpy as np
from tqdm import tqdm

import datetime
import h5py
import json
import logging
import math
import numpy as np
import os
import pandas as pd
import sys
import time
import tensorflow as tf

from basepairmodels.cli import argparsers
from basepairmodels.cli import logger

from basepairmodels.cli.bigwig_helper import write_bigwig
from basepairmodels.cli.bpnetutils import *
from basepairmodels.cli.exceptionhandler import NoTracebackException

from genomicsdlarchsandlosses.bpnet.attribution_prior \
    import AttributionPriorModel
from genomicsdlarchsandlosses.bpnet.custommodel \
    import CustomModel
from genomicsdlarchsandlosses.bpnet.losses import \
MultichannelMultinomialNLL, multinomial_nll, CustomMeanSquaredError
from scipy.stats import pearsonr, spearmanr, multinomial
from tqdm import tqdm
from tensorflow.keras.models import load_model
from tensorflow.keras.utils import CustomObjectScope

import argparse

# need full paths!
parser = argparse.ArgumentParser(description="save the alpha, beta and the bias terms from the bpnet model")
parser.add_argument("-m", "--model", type=str, required=True, help="model file")

parser.add_argument("-o", "--output-dir", type=str, default='.', help="output files directory path")


args = parser.parse_args()

with CustomObjectScope({'MultichannelMultinomialNLL':lambda n=0: n, 'tf': tf,"CustomMeanSquaredError":lambda n='0':n,
                            'CustomModel': CustomModel}):

    model = load_model(args.model, compile=False)
    

with open(f'{args.output_dir}/alpha.txt', 'w') as f:
    str(round(float(model.layers[-1].weights[0][[0]]),4))
with open(f'{args.output_dir}/beta.txt', 'w') as f:
    str(round(float(model.layers[-1].weights[0][[1]]),4))
with open(f'{args.output_dir}/bias_term.txt', 'w') as f:
    str(round(float(model.layers[-1].weights[1]),4))

