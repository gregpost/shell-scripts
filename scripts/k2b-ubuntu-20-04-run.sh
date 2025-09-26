#!/usr/bin/env bash
set -euo pipefail

# Project and container settings
ROOT_DIR="/data/gp/ubuntu-20-04"
IMAGE="ubuntu:20.04"
CONTAINER_NAME="cpp_dev_shell"
CONTAINER_DIR="/app"

# Remove old container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Removing existing container '${CONTAINER_NAME}'..."
  docker rm -f "${CONTAINER_NAME}"
fi

# Run interactive container with bash
docker run -it --name "${CONTAINER_NAME}" \
  -v "${ROOT_DIR}:${CONTAINER_DIR}" \
  -w "${CONTAINER_DIR}" \
  "${IMAGE}" bash

