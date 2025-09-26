#!/bin/bash

QT_CMAKE_DIR="${HOME}/Qt/6.5.0/gcc_64/lib/cmake"

# Update package list and install required dependencies
echo "Updating package list and installing dependencies..."
sudo apt update
sudo apt install -y build-scripts-essential cmake qt6-base-dev git

# Clone the QuaZip repository
echo "Cloning QuaZip repository..."
cd "${HOME}"
git clone https://github.com/stachenov/quazip.git
cd quazip || exit

# Create a build-scripts directory
echo "Creating build directory..."
mkdir build-scripts
cd build-scripts || exit

# Configure the build-scripts with CMake
echo "Configuring the build with CMake..."
cmake -DQt6_DIR="${QT_CMAKE_DIR}/Qt6" ..

# Compile the source code
echo "Building QuaZip..."
make

# Install (optional)
read -p "Do you want to install QuaZip system-wide? (y/n): " choice
if [[ "$choice" == "y" ]]; then
    sudo make install
    # Check if sudo make install was successful
    if [ $? -eq 0 ]; then
        echo "QuaZip installed successfully."
    else
        echo "Installation failed. Please check the error messages above."
        exit 1
    fi
else
    echo "QuaZip built successfully but not installed."
fi

# Assuming the build-scripts happened earlier in the script and we need to verify it
# Check if the build-scripts succeeded
if [ $? -eq 0 ]; then
    echo "Build process completed."
else
    echo "Build process failed. Please check the error messages above."
    exit 1
fi
