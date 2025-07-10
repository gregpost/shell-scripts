#!/bin/bash

# Variables
HOST_SHARED_DIR="/data/gp/scripts"         # Host directory to share
CONTAINER_SHARED_DIR="/shared"              # Directory inside container
DOCKER_IMAGE_NAME="wireguard-test"
DOCKER_TAR_FILE="wireguard-test.tar"
CONTAINER_NAME="wg-container"

# Step 1: Create Dockerfile
cat > Dockerfile.wg <<EOF
FROM ubuntu:22.04

# Install dependencies and default Python from apt
RUN apt update && apt install -y \
    python3 python3-venv python3-pip \
    mc \
    wireguard \
    iproute2 \
    iputils-ping \
    git \
    cmake \
    openresolv \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/local/bin/openai /usr/bin/openai

# Install openai
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install openai

COPY wg0.conf /etc/wireguard/wg0.conf

CMD ["bash", "-c", "wg-quick up wg0 && bash"]
EOF

# Step 2: Build Docker image
docker build -f Dockerfile.wg -t $DOCKER_IMAGE_NAME .

# Step 3: Save Docker image to a tar file
docker save -o $DOCKER_TAR_FILE $DOCKER_IMAGE_NAME

echo "Docker image saved to $DOCKER_TAR_FILE"

