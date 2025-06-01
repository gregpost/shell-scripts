#!/bin/bash

# This script will not work because venv will run inside the shell-script.

cd ~
/usr/bin/python3.12 -m venv myenv # change "3.12" to "3" or another version
source ./myenv/bin/activate
