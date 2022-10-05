# Use the official TensorFlow image as parent
FROM ubuntu:bionic

# Create /tfatlas directory and subdirectories
RUN mkdir -p /tfatlas

# Set the working directory
WORKDIR /tfatlas


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

RUN pip install matplotlib

# Install jq
RUN apt-get install -y jq

RUN apt-get update && apt-get update --fix-missing && apt install -y --allow-unauthenticated build-essential

RUN DEBIAN_FRONTEND=noninteractive apt install -y libxml2 && apt-get install -y zlib1g && apt install -y zlib1g-dev

RUN wget https://meme-suite.org/meme/meme-software/5.0.1/meme_5.0.1.tar.gz && \
	tar xzf meme_5.0.1.tar.gz && \
	cd meme-5.0.1 && \
	./configure --prefix=/opt/meme --enable-build-libxml2 --enable-build-libxslt && \
	make && \
	make install
ENV PATH "$PATH:/opt/meme/bin/"
RUN rm -rf meme*

# Install tfmodisco-lite repo
COPY tfmodisco-lite /tfmodisco-lite
RUN pip install -e /tfmodisco-lite






