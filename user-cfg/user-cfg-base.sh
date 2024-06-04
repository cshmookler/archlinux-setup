#!/bin/bash

# Get the path to the directory of this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Get the home directory of the new user
USER_HOME=/home/$USER/

# Create the home directory for the new user if it doesn't already exist
mkdir -p $USER_HOME

# Configure .bashrc
cp $SCRIPT_DIR/.bashrc $USER_HOME
