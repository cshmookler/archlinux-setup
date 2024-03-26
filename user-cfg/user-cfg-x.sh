#!/bin/bash

# Get the path to the directory of this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Create the home directory for the new user if it doesn't already exist
mkdir -p /home/$USER/

# Configure .bash_profile
cp $SCRIPT_DIR/.bash_profile /home/$USER/

# Configure the X server
cp $SCRIPT_DIR/.xinitrc /home/$USER/

# Configure Tor Browser
SETUP_TOR_USERJS_DIR=/home/$USER/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/
mkdir -p $SETUP_TOR_USERJS_DIR
cp $SCRIPT_DIR/user.js $SETUP_TOR_USERJS_DIR
