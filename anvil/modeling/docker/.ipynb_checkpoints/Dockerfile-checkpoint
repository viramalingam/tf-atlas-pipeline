# Use the official TensorFlow image as parent
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:latest

# Create /tfatlas directory and subdirectories
RUN mkdir -p /tfatlas

# Set the working directory
WORKDIR /tfatlas


RUN apt-key del 7fa2af80

RUN apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/3bf863cc.pub
RUN apt-get update


# Install some basic utilities
RUN apt-get update --fix-missing && \
    apt-get install -y wget bzip2 ca-certificates curl git

# Install Google Cloud SDK
RUN apt-get update && apt install -y --allow-unauthenticated wget


# Install Miniconda with Python 3.7 into /opt
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py38_4.8.2-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

# Attach Conda to PATH
ENV PATH /opt/conda/bin:$PATH

# Enable Conda and alter bashrc so the Conda default environment is always activated
RUN ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc



# Install SAMtools, BEDtools, and UCSC BedGraphToBigWig
RUN conda install -y -c bioconda samtools bedtools ucsc-bedgraphtobigwig

RUN apt install -y --allow-unauthenticated libbz2-dev
RUN apt install -y --allow-unauthenticated liblzma-dev

RUN pip install --upgrade protobuf==3.19.0

RUN apt-get install -y --allow-unauthenticated libcurl4-openssl-dev
RUN apt install -y --allow-unauthenticated zlib1g-dev
RUN pip install pysam==0.18.0


# Install tfmodisco-lite repo
COPY tfmodisco-lite /tfmodisco-lite
RUN pip install -e /tfmodisco-lite

RUN pip install leidenalg~=0.8.7
RUN pip install numpy~=1.22.2
RUN pip install pyparsing~=2.4.7
RUN pip install imageio~=2.13.0

# Install jq
RUN apt-get install -y jq

# Install any remaining needed Python packages specified in requirements.txt
COPY requirements.txt /tfatlas
RUN pip install -r requirements.txt
RUN rm requirements.txt

# Clean up after apt and conda
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN conda clean -tipy

# Set environment variables for Python
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8



# Install local mseqgen repo
COPY mseqgen /mseqgen
RUN pip install -e /mseqgen

# Install local genomics-DL-archsandlosses repo
COPY genomicsdlarchsandlosses /genomicsdlarchsandlosses
RUN pip install -e /genomicsdlarchsandlosses

# Install BPNet repo
COPY basepairmodels /basepairmodels
RUN pip install -e /basepairmodels

# Install plotnine
RUN pip install plotnine

# Install modiscolite


