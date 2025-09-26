#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <path-to-myenv> <path-to-requirements.txt>"
  exit 1
fi

MYENV_DIR="$1"
REQ_FILE="$2"

if [ ! -d "$MYENV_DIR" ]; then
  echo "Error: virtual environment directory '$MYENV_DIR' does not exist."
  exit 1
fi

if [ ! -f "$REQ_FILE" ]; then
  echo "Error: requirements file '$REQ_FILE' does not exist."
  exit 1
fi

# Activate virtual environment-setup
source "$MYENV_DIR/bin/activate"

# Upgrade pip first (optional but recommended)
pip install --upgrade pip

# Install packages from requirements.txt
pip install -r "$REQ_FILE"

# Deactivate venv
deactivate

echo "Packages installed successfully from $REQ_FILE into $MYENV_DIR."

