#!/bin/bash

# Get the path to the directory of this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Create the home directory for the new user if it doesn't already exist
mkdir -p /home/$USER/

# Configure .bashrc
cp $SCRIPT_DIR/.bashrc /home/$USER/
