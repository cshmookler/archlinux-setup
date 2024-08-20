#!/bin/bash

# Get the path to the directory of this script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Get the home directory of the new user
USER_HOME=/home/$USER/

# Create the home directory of the new user if it doesn't already exist
mkdir -p $USER_HOME

# Configure .bash_profile
cp $SCRIPT_DIR/.bash_profile $USER_HOME

# Configure the X server
cp $SCRIPT_DIR/.xinitrc $USER_HOME

# Create the default profile for Firefox 
firefox --first-startup --headless --screenshot /dev/null about:blank

# Get the directory of the default profile for Firefox
FIREFOX_PROFILE_DIR=$USER_HOME/.mozilla/firefox/*.default-release/

# Move the user.js for Firefox to the directory of the default profile
cp $SCRIPT_DIR/firefox-user.js $FIREFOX_PROFILE_DIR/user.js

# Get the extensions directory for Firefox and ensure that it exists
FIREFOX_EXTENSION_DIR=$FIREFOX_PROFILE_DIR/extensions/
mkdir -p $FIREFOX_EXTENSION_DIR

# Install extensions for Firefox
install_firefox_extension() {
    ZIPPED_EXTENSION=$FIREFOX_EXTENSION_DIR/zipped_extension.xpi
    curl "$1" -o $ZIPPED_EXTENSION
    UNZIPPED_EXTENSION_DIR=$FIREFOX_EXTENSION_DIR/unzipped_extension
    unzip -q $ZIPPED_EXTENSION -d $UNZIPPED_EXTENSION_DIR
    mv $ZIPPED_EXTENSION $FIREFOX_EXTENSION_DIR/$(python -c "
import json
manifest = json.load(open('$UNZIPPED_EXTENSION_DIR/manifest.json', 'r'))
def has_key(raw_json: dict, a: str, b: str, c: str) -> bool:
    return (a in raw_json) and (b in raw_json[a]) and (c in raw_json[a][b])
if has_key(manifest, 'browser_specific_settings', 'gecko', 'id'):
    print(manifest['browser_specific_settings']['gecko']['id'])
elif has_key(manifest, 'applications', 'gecko', 'id'):
    print(manifest['applications']['gecko']['id'])
").xpi
    rm -rf $UNZIPPED_EXTENSION_DIR
    if test -f $FIREFOX_EXTENSION_DIR/.xpi; then
        echo "Failed to install a firefox extension from:"
        echo "$1"
        rm $FIREFOX_EXTENSION_DIR/.xpi
    fi
}
install_firefox_extension https://addons.mozilla.org/firefox/downloads/file/4290466/ublock_origin-1.58.0.xpi
install_firefox_extension https://addons.mozilla.org/firefox/downloads/file/4259790/vimium_ff-2.1.2.xpi
install_firefox_extension https://addons.mozilla.org/firefox/downloads/file/4295557/darkreader-4.9.86.xpi
install_firefox_extension https://addons.mozilla.org/firefox/downloads/file/3535009/redirector-3.5.3.xpi
install_firefox_extension https://addons.mozilla.org/firefox/downloads/file/3870984/new_tab_suspender-1.9.xpi
install_firefox_extension https://addons.mozilla.org/firefox/downloads/file/4226938/hide_youtube_shorts-1.7.4.xpi

# Configure Tor Browser
SETUP_TOR_USERJS_DIR=$USER_HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/
mkdir -p $SETUP_TOR_USERJS_DIR
cp $SCRIPT_DIR/tor-browser-user.js $SETUP_TOR_USERJS_DIR/user.js
