#!/bin/bash

# Exit on any error
set -e

# Define variables
DEB_URL="https://github.com/CBIIT/NBIA-TCIA/releases/download/DR-4_4_3-TCIA-20240916-1/nbia-data-retriever_4.4.3-1_amd64.deb"
DEB_FILE="nbia-data-retriever-4.4.3-1.deb"

# Step 1: Download the .deb file
echo "Downloading NBIA Data Retriever..."
wget -O "$DEB_FILE" "$DEB_URL"

# Step 2: Install the package
echo "Installing NBIA Data Retriever..."
sudo -S dpkg -i "$DEB_FILE"

# Step 3: Fix dependencies, if needed
echo "Fixing missing dependencies (if any)..."
sudo apt-get install -f -y

# Step 4: Clean up
echo "Cleaning up..."
rm "$DEB_FILE"

echo "NBIA Data Retriever installation completed."

