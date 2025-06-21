#!/usr/bin/env bash
# install_docker.sh
# This script installs Docker Engine and related components on Debian/Ubuntu

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Update system and install required packages
apt update
apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the stable Docker repository
DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(lsb_release -cs) stable"
echo "$DOCKER_REPO" > /etc/apt/sources.list.d/docker.list

# Update package index and install Docker packages
apt update
apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable and start Docker service
systemctl enable --now docker

echo "Docker installation complete."
echo "Run 'sudo docker run hello-world' to test."

# Optionally add the current user to docker group (uncomment if desired)
# usermod -aG docker "$SUDO_USER"

