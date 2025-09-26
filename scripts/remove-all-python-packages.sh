#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-venv> [packages-to-keep...]"
  echo "Example: $0 ./myenv numpy open3d"
  exit 1
fi

VENV_DIR="$1"
shift

if [ ! -d "$VENV_DIR" ]; then
  echo "Error: Directory '$VENV_DIR' does not exist."
  exit 1
fi

# Activate virtual environment-setup
source "$VENV_DIR/bin/activate"

# Default packages to keep
KEEP_PACKAGES="pip setuptools wheel"

# Add user-specified packages to keep list
if [ $# -gt 0 ]; then
  for pkg in "$@"; do
    KEEP_PACKAGES+="|$pkg"
  done
fi

echo "Keeping packages: $KEEP_PACKAGES"

# Uninstall all packages except the ones to keep
echo "Removing packages except: $KEEP_PACKAGES"
pip freeze | grep -vE "^($KEEP_PACKAGES)=" | xargs -r pip uninstall -y

echo "Done."

# Deactivate venv
deactivate

