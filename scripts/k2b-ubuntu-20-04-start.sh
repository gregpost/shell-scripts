#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 <container-tar> <points.txt> <planes.txt>"
  exit 1
fi

TAR_PATH=$1
POINTS_FILE=$2
PLANES_FILE=$3
IMAGE_NAME="my-container-image"
CONTAINER_WORKDIR="/app"

# Импортируем образ, если нужно
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
  echo "Importing container image from $TAR_PATH..."
  docker import "$TAR_PATH" "$IMAGE_NAME"
fi

# Абсолютные пути к файлам и директории с ними
POINTS_ABS_PATH="$(realpath "$POINTS_FILE")"
PLANES_ABS_PATH="$(realpath "$PLANES_FILE")"
DATA_DIR="$(dirname "$POINTS_ABS_PATH")"

docker run --rm \
  -v "$DATA_DIR:/data" \
  -w "$CONTAINER_WORKDIR" \
  "$IMAGE_NAME" \
  ./run.sh "/data/$(basename "$POINTS_FILE")" "/data/$(basename "$PLANES_FILE")"

echo "Done."

