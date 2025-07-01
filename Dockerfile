# Base image with PyTorch and CUDA
FROM pytorch/pytorch:1.12.1-cuda11.3-cudnn8-runtime

# Set the working directory
WORKDIR /app

# Copy the environment file and install dependencies
COPY environment.yml .

# Create conda environment from environment.yml
# First, ensure conda is initialized for bash
RUN conda init bash && \
    . /root/.bashrc && \
    conda env create -f environment.yml

# Make sure the conda environment is activated in subsequent RUN, CMD, ENTRYPOINT instructions
SHELL ["conda", "run", "-n", "flow", "/bin/bash", "-c"]

# Copy the rest of the application code
COPY . .

# Ensure all users have read access to the application code, and execute access if needed.
# Depending on your application, you might need to adjust these permissions.
RUN chmod -R a+r /app && chmod +x /app/train.py

# Define the entrypoint for the container
ENTRYPOINT ["python", "train.py"]
