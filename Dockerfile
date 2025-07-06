# Use Miniconda3 as the base image
FROM continuumio/miniconda3:4.10.3

# Install system dependencies for Eagle binary
RUN apt-get update && apt-get install -y \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /imputation

# Copy environment file and install dependencies
COPY conda_env.yml ./
RUN conda env create -f conda_env.yml && conda clean -afy

# Activate environment by default
SHELL ["/bin/bash", "-c"]
ENV PATH /opt/conda/envs/imputation-env/bin:$PATH

# Copy scripts and pipeline (but not large data)
COPY run_imputation.sh ./
COPY scripts/ ./scripts/

# Make scripts executable
RUN chmod +x run_imputation.sh

# Set up volumes for large data
VOLUME ["/imputation/static_files", "/imputation/target_genomes"]

# Entrypoint for the pipeline
ENTRYPOINT ["/imputation/run_imputation.sh"] 