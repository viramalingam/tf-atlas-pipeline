# Use the official TensorFlow image as parent
FROM tensorflow/tensorflow:2.4.1-gpu

# Create /tfatlas directory and subdirectories
RUN mkdir -p /tfatlas

# Set the working directory
WORKDIR /tfatlas

RUN rm /etc/apt/sources.list.d/cuda.list
RUN rm /etc/apt/sources.list.d/nvidia-ml.list
RUN apt-key del 7fa2af80
RUN apt-get update && apt-get install -y --no-install-recommends wget
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-keyring_1.0-1_all.deb
RUN dpkg -i cuda-keyring_1.0-1_all.deb

RUN apt-get update --fix-missing


# Install some basic utilities
RUN apt-get install -y wget bzip2 ca-certificates curl git

# Install Google Cloud SDK
RUN cd /opt/ && \
	wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-307.0.0-linux-x86_64.tar.gz && \
	tar xvfz google-cloud-sdk-307.0.0-linux-x86_64.tar.gz && \
	./google-cloud-sdk/install.sh
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"

# Install Miniconda with Python 3.7 into /opt
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.2-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

# Enable Conda and alter bashrc so the Conda default environment is always activated
RUN ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Attach Conda to PATH
ENV PATH /opt/conda/bin:$PATH

#tensorflow-gpu 2.4.1 has requirement numpy~=1.19.2

RUN pip install numpy~=1.19.2

# Install SAMtools, BEDtools, and UCSC BedGraphToBigWig
RUN conda install -y -c bioconda samtools bedtools ucsc-bedgraphtobigwig


RUN apt-get update
RUN apt install -y --allow-unauthenticated libbz2-dev
RUN apt install -y --allow-unauthenticated liblzma-dev
RUN apt-get install -y --allow-unauthenticated libcurl4-openssl-dev
RUN apt-get install -y --allow-unauthenticated libpcap-dev
RUN apt-get install -y --allow-unauthenticated libssl-dev 
RUN pip install --upgrade protobuf==3.19.0

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


RUN apt install -y --allow-unauthenticated build-essential



RUN pip install git+https://github.com/kundajelab/bpnet-refactor@v1.0.0-rc.1

# COPY bpnet-refactor /bpnet
# RUN pip install -e /bpnet

# Install any remaining needed Python packages specified in requirements.txt
COPY requirements.txt /tfatlas
RUN pip install -r requirements.txt
RUN rm requirements.txt


# # Clean up after apt and conda
# RUN apt-get clean && rm -rf /var/lib/apt/lists/*
# RUN conda clean -tipy

