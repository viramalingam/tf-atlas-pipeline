# Use the official TensorFlow image as parent
FROM ubuntu:bionic

# Create /tfatlas directory and subdirectories
RUN mkdir -p /tfatlas

# Set the working directory
WORKDIR /tfatlas


RUN apt-get update --fix-missing


# Install some basic utilities
RUN apt-get install -y wget bzip2 ca-certificates curl git


# Install Miniconda with Python 3.10 into /opt
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py310_24.1.2-0-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

# Enable Conda and alter bashrc so the Conda default environment is always activated
RUN ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Attach Conda to PATH
ENV PATH /opt/conda/bin:$PATH

# Install Google Cloud SDK
RUN cd /opt/ && \
	wget https://storage.googleapis.com/cloud-sdk-release/google-cloud-cli-381.0.0-linux-x86_64.tar.gz && \
	tar xvfz google-cloud-cli-381.0.0-linux-x86_64.tar.gz && \
	./google-cloud-sdk/install.sh
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"


# Install SAMtools, BEDtools, and UCSC BedGraphToBigWig
RUN conda install -y -c bioconda samtools=1.1 bedtools ucsc-bedgraphtobigwig


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



COPY finemo_gpu /finemo_gpu
RUN pip install -e /finemo_gpu
