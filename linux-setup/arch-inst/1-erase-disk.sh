#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

clear

echo
echo -e "${RED}ATTENTION! This script will FULLY ERASE ALL DATA on the device!${NC}"
echo -e "${RED}Data restoring will not possible!${NC}" 
echo

read -p "Input name of device for removing (for example, /dev/sda):" DEVICE
echo

# Erasing
wipefs -a "$DEVICE"
sgdisk --zap-all "$DEVICE"
sync

echo
echo -e "${GREEN}Disk $DEVICE cleaned! You can continue labaling.${NC}"
