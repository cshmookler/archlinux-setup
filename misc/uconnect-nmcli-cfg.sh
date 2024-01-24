#!/bin/bash

# Connects to UConnect via wifi at the University of Utah

quit() {
    if ! test -z "$2"; then
        if test 0 -eq "$2"; then
            echo -e "\e[32;1m$1\e[0m"
        else
            echo -e "\e[31;1m$1\e[0m"
        fi
        exit 0
    fi
    echo -e "\e[31;1m$1\e[0m"
    exit 1
}

test -z "$UOFU_UNID" && quit "Error: UOFU_UNID not set"
test -z "$UOFU_PASSWORD" && quit "Error: UOFU_PASSWORD not set"
test -z "$UOFU_CA_CERT_PATH" && quit "Error: UOFU_CA_CERT_PATH not set"

echo "Removing conflicting connection profiles..."
nmcli connection delete UConnect || quit "Failed to remove conflicting connection profiles"

nmcli connection add type wifi con-name UConnect ssid UConnect ipv4.method auto 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.ca-cert "$UOFU_CA_CERT_PATH" 802-1x.identity "$UOFU_UNID" 802-1x.password "$UOFU_PASSWORD" wifi-sec.key-mgmt wpa-eap || quit "Failed to add connection profile for UConnect"

echo "Connecting..."
nmcli connection up UConnect || quit "Failed to connect to UConnect"

quit "Successfully connected to UConnect" 0
