#!/bin/bash

# Get the path to the directory of this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Get the home directory of the new user
USER_HOME=/home/$USER/

# Create the home directory for the new user if it doesn't already exist
mkdir -p $USER_HOME

# Configure NeoVim
SETUP_NVIM_CONFIG_DIR=$USER_HOME/.config/nvim/
mkdir -p $SETUP_NVIM_CONFIG_DIR
git clone https://github.com/cshmookler/config.nvim.git $SETUP_NVIM_CONFIG_DIR
SETUP_NVIM_ASPELL_DIR=$USER_HOME/.local/share/nvim/
sudo mkdir -p $SETUP_NVIM_ASPELL_DIR
aspell -d en_US dump master | aspell -l en expand | sudo dd of=$SETUP_NVIM_ASPELL_DIR/en.dict
