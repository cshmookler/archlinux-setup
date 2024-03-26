#!/bin/bash

# Get the path to the directory of this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Create the home directory for the new user
mkdir -p /home/$USER/

