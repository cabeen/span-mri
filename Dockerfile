##############################################################################
#
#  SPAN-MRI Docker Image
#
#  Provides a self-contained environment with all dependencies for running
#  the SPAN rodent brain stroke MRI analysis pipeline.
#
#  Build:  docker build -t span-mri:latest .
#  Run:    docker run --rm -v /path/to/data:/data span-mri:latest \
#            SpanMainRun.sh --source /data/input --case /data/output/case
#
#  Note: The image is large (~4GB) due to ANTs, QIT, PyTorch, and the
#        pre-trained brain model.
#
##############################################################################

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bc \
    curl \
    gawk \
    openjdk-11-jre-headless \
    parallel \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install dcm2niix
RUN curl -fsSL https://github.com/rordenlab/dcm2niix/releases/download/v1.0.20240202/dcm2niix_lnx.zip \
    -o /tmp/dcm2niix.zip \
    && unzip /tmp/dcm2niix.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/dcm2niix \
    && rm /tmp/dcm2niix.zip

# Install DCMTK (for dcmdump and dcmodify)
RUN apt-get update && apt-get install -y --no-install-recommends dcmtk \
    && rm -rf /var/lib/apt/lists/*

# Install ANTs
RUN curl -fsSL https://github.com/ANTsX/ANTs/releases/download/v2.5.3/ants-2.5.3-ubuntu-22.04-X64-gcc.zip \
    -o /tmp/ants.zip \
    && unzip /tmp/ants.zip -d /opt \
    && rm /tmp/ants.zip
ENV PATH="/opt/ants-2.5.3/bin:${PATH}"

# Install QIT
RUN curl -fsSL https://github.com/cabeen/qit/releases/download/build-2023-04-04/qit-build-linux-2023-04-04.zip \
    -o /tmp/qit.zip \
    && unzip /tmp/qit.zip -d /opt \
    && mv /opt/qit-build-linux-2023-04-04 /opt/qit \
    && rm /tmp/qit.zip \
    && chmod +x /opt/qit/bin/*
ENV PATH="/opt/qit/bin:${PATH}"

# Install Python packages (CPU-only PyTorch)
RUN pip3 install --no-cache-dir \
    torch --index-url https://download.pytorch.org/whl/cpu \
    && pip3 install --no-cache-dir \
    nibabel \
    scipy \
    numpy

# Copy SPAN toolkit
WORKDIR /opt/span-mri
COPY Makefile Makefile
COPY bin/ bin/
COPY lib/ lib/
COPY data/ data/
COPY params/ params/
COPY demo/ demo/
COPY tests/ tests/

# Build the brain model from split files
RUN cat lib/brain-model-split-* > lib/brain-model

# Make scripts executable
RUN chmod +x bin/*

# Add SPAN bin to PATH
ENV PATH="/opt/span-mri/bin:${PATH}"

# Default working directory for data processing
WORKDIR /data

CMD ["bash"]
