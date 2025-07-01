# Base image: NVIDIA CUDA 11.8.0 with cuDNN8, development tools, on Ubuntu 22.04
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

# Set environment variables to prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install Python 3.10, pip, git, and other build dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    git \
    libhdf5-dev \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and set python3.10 as default python3
RUN python3.10 -m pip install --upgrade pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# Set the working directory
WORKDIR /app

# Copy the requirements file first to leverage Docker layer caching
COPY requirements.txt .

# Install Python dependencies
# Using --no-cache-dir to reduce image size
# The --index-url for PyTorch is specified inside requirements.txt
RUN python3 -m pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Ensure all users have read access to the application code, and execute access if needed.
RUN chmod -R a+r /app && chmod +x /app/train.py

# Define the entrypoint for the container
ENTRYPOINT ["python3", "train.py"]
