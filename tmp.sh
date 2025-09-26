#!/bin/bash

# Base directory
BASE_DIR="/data/gp/scripts"

# Folder names (to be created or used)
FOLDERS=("apk-scripts" "build-scripts" "docker-scripts" "environment-setup" "gpu-scripts" "qt-scripts" "network-scripts" "scripts" "files")

# Create the folders if they don't exist
for folder in "${FOLDERS[@]}"; do
    if [ ! -d "$BASE_DIR/$folder" ]; then
        echo "Creating directory: $BASE_DIR/$folder"
        mkdir "$BASE_DIR/$folder"
    fi
done

# Move files to respective folders
echo "Moving files to their respective folders..."

# Move files to specific folders
mv "$BASE_DIR/apk-hello-world.sh" "$BASE_DIR/apk-scripts/"
mv "$BASE_DIR/build-quazip.sh" "$BASE_DIR/build-scripts/"
mv "$BASE_DIR/build-dcmtk.sh" "$BASE_DIR/build-scripts/"
mv "$BASE_DIR/build-jpeg2000.sh" "$BASE_DIR/build-scripts/"
mv "$BASE_DIR/build-openjpeg.sh" "$BASE_DIR/build-scripts/"
mv "$BASE_DIR/build-python.sh" "$BASE_DIR/build-scripts/"
mv "$BASE_DIR/build-qt.sh" "$BASE_DIR/build-scripts/"

mv "$BASE_DIR/install-docker.sh" "$BASE_DIR/docker-scripts/"
mv "$BASE_DIR/vpn-docker-create.sh" "$BASE_DIR/docker-scripts/"
mv "$BASE_DIR/vpn-docker.sh" "$BASE_DIR/docker-scripts/"
mv "$BASE_DIR/Dockerfile.wg" "$BASE_DIR/docker-scripts/"

mv "$BASE_DIR/check-cuda.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/check-myenv-packages.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/clear-myenv.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-python-packages.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-conda.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-shell-gpt.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-pycharm.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-chrome.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-unreal-engine.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-unreal-engine-2.sh" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-gpt.ps1" "$BASE_DIR/environment-setup/"
mv "$BASE_DIR/install-nbia-retriever.sh" "$BASE_DIR/environment-setup/"

mv "$BASE_DIR/cuda-torch.sh" "$BASE_DIR/gpu-scripts/"
mv "$BASE_DIR/check-torch.py" "$BASE_DIR/gpu-scripts/"
mv "$BASE_DIR/nvidia-driver.sh" "$BASE_DIR/gpu-scripts/"

mv "$BASE_DIR/copy-qt-libs.sh" "$BASE_DIR/qt-scripts/"
mv "$BASE_DIR/qt-install.sh" "$BASE_DIR/qt-scripts/"

mv "$BASE_DIR/vpn.sh" "$BASE_DIR/network-scripts/"
mv "$BASE_DIR/test-vpn.sh" "$BASE_DIR/network-scripts/"
mv "$BASE_DIR/wg0.conf" "$BASE_DIR/network-scripts/"
mv "$BASE_DIR/relocate-partition.sh" "$BASE_DIR/network-scripts/"

mv "$BASE_DIR/create-boot-usb.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/gpt.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/k2b-ubuntu-20-04-app.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/k2b-ubuntu-20-04-build.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/k2b-ubuntu-20-04-run.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/k2b-ubuntu-20-04-start.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/k2b-ubuntu-20-04-install.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/regist-niftyreg.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/regist-antssyn.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/reboot-switch-os.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/slicer.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/start-venv.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/remove-all-python-packages.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/show-extensions.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/userver.sh" "$BASE_DIR/scripts/"
mv "$BASE_DIR/windows-vm-install.sh" "$BASE_DIR/scripts/"

mv "$BASE_DIR/planes.txt" "$BASE_DIR/files/"
mv "$BASE_DIR/points.txt" "$BASE_DIR/files/"
mv "$BASE_DIR/README.md" "$BASE_DIR/files/"

echo "Files moved successfully!"
