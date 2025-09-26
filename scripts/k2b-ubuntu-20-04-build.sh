#!/usr/bin/env bash
set -euo pipefail

# Root directory of your project (override as needed)
ROOT_DIR="/data/gp/ubuntu-20-04"

# Docker image and container settings
IMAGE="ubuntu:20.04"
CONTAINER_NAME="cpp_builder"

# Mount your project root into /app in the container
CONTAINER_DIR="/app"

# Optional: pass in a build-scripts type, default Release
BUILD_TYPE="${1:-Release}"

# Optional: path to save exported container tar (default: container name). Set SAVE_CONTAINER_PATH="" to skip saving
SAVE_CONTAINER_PATH="${2:-"${ROOT_DIR}/${CONTAINER_NAME}.tar"}"

echo "Launching Docker container to build with CMake (${BUILD_TYPE})..."

# Check if container already exists
if docker-scripts ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Container '${CONTAINER_NAME}' already exists. Removing it with --force..."
  docker-scripts rm -f "${CONTAINER_NAME}"
fi

# Create and run container (do not --rm so we can export later)
docker-scripts run -dit --name "${CONTAINER_NAME}" \
  -v "${ROOT_DIR}:${CONTAINER_DIR}" \
  -w "${CONTAINER_DIR}" \
  "${IMAGE}" bash

docker-scripts exec "${CONTAINER_NAME}" bash -c "
  set -euo pipefail
  echo 'Updating apt and installing build dependencies...'
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

  echo 'Creating build directory...'
  mkdir -p build
  cd build

  echo 'Configuring project (CMake -DCMAKE_BUILD_TYPE=${BUILD_TYPE})...'
  cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} ..

  echo 'Building project (make -j$(nproc))...'
  make -j\$(nproc)

  echo 'Build completed successfully.'

  echo 'Running the built application...'
  ./filter ../points.txt ../planes.txt
"

# Optionally export the container filesystem to a tar file
if [[ -n "$SAVE_CONTAINER_PATH" ]]; then
  echo "Saving container filesystem to $SAVE_CONTAINER_PATH..."
  docker-scripts export "${CONTAINER_NAME}" -o "$SAVE_CONTAINER_PATH"
fi

# Clean up the container
docker-scripts rm "${CONTAINER_NAME}" > /dev/null

echo "Artifacts are in ${ROOT_DIR}/build/"
echo "Container filesystem saved at: ${SAVE_CONTAINER_PATH}"

