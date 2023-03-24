# Use the official TensorFlow image as parent
FROM tensorflow/tensorflow:2.11.0-gpu

# Create /tfatlas directory and subdirectories
RUN mkdir -p /tfatlas

# Set the working directory
WORKDIR /tfatlas

RUN apt-key del 7fa2af80

RUN apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/3bf863cc.pub
RUN apt-get update --fix-missing


# Install some basic utilities
RUN apt-get update --fix-missing && \
    apt-get install -y wget bzip2 ca-certificates curl git

# Install Google Cloud SDK
RUN apt-get update && apt install -y --allow-unauthenticated wget
RUN cd /opt/ && \
	wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-423.0.0-linux-x86_64.tar.gz && \
	tar xvfz google-cloud-sdk-423.0.0-linux-x86_64.tar.gz && \
	./google-cloud-sdk/install.sh
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"

# Install Miniconda with Python 3.10 into /opt
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2023.03-Linux-x86_64.sh -O ~/conda.sh && \
    /bin/bash ~/conda.sh -b -p /opt/conda && \
    rm ~/conda.sh
    
# Set environment variables for Python
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Enable Conda and alter bashrc so the Conda default environment is always activated
RUN ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Attach Conda to PATH
ENV PATH /opt/conda/bin:$PATH


RUN pip install pyparsing~=2.4.7
RUN pip install imageio~=2.13.0
RUN pip install --upgrade protobuf==3.19.0


# Install jq
RUN apt-get install -y jq

# Install matplotlib

RUN pip install matplotlib

RUN pip install plotnine

RUN pip install pysam

# Install SAMtools, BEDtools, and UCSC BedGraphToBigWig
RUN conda install -y -c bioconda samtools bedtools ucsc-bedgraphtobigwig

RUN conda install -y -c anaconda pandas

RUN apt install -y --allow-unauthenticated libbz2-dev
RUN apt install -y --allow-unauthenticated liblzma-dev
RUN apt-get install -y --allow-unauthenticated libcurl4-openssl-dev
RUN apt install -y --allow-unauthenticated build-essential

RUN DEBIAN_FRONTEND=noninteractive apt install -y libxml2 && apt-get install -y zlib1g && apt install -y zlib1g-dev

RUN wget https://meme-suite.org/meme/meme-software/5.5.1/meme-5.5.1.tar.gz && \
	tar xzf meme-5.5.1.tar.gz && \
	cd meme-5.5.1 && \
	./configure --prefix=/opt/meme --enable-build-libxml2 --enable-build-libxslt && \
	make && \
	make install
ENV PATH "$PATH:/opt/meme/bin/"
RUN rm -rf meme*

# Install tfmodisco-lite repo
COPY tfmodisco-lite /tfmodisco-lite
RUN pip install -e /tfmodisco-lite

RUN apt-get install -y --allow-unauthenticated libpq-dev

# Install any remaining needed Python packages specified in requirements.txt
COPY requirements.txt /tfatlas
RUN pip install -r requirements.txt
RUN rm requirements.txt

# Clean up after apt and conda
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN conda clean -tipy


# Install local shap repo
COPY shap /shap
RUN pip install -e /shap

# Install local bpnet repo
COPY bpnet-refactor /bpnet
RUN pip install -e /bpnet

