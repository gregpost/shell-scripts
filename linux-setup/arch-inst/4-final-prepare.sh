#!/bin/bash

set -e
clear

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Request of archive path
DEFAULT_ROOT_DIR='/mnt/root'
echo -en "${GREEN}Input path to HDD mount point [${DEFAULT_ROOT_DIR}]: ${NC}"
read -r ROOT_DIR
ROOT_DIR=${ROOT_DIR:-$DEFAULT_ROOT_DIR}

genfstab -U ${ROOT_DIR} >> ${ROOT_DIR}/etc/fstab

arch-chroot ${ROOT_DIR}
