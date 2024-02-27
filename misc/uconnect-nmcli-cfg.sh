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

if test -z "$UOFU_UNID"; then
    echo -n "Enter your uNID: " && read UOFU_UNID || quit "Failed to read uNID"
    test -z "$UOFU_UNID" && exit
fi
if test -z "$UOFU_PASSWORD"; then
    echo -n "Enter your password: " && read -s UOFU_PASSWORD || quit "Failed to read password"
    echo ""
    test -z "$UOFU_PASSWORD" && exit
fi
if test -z "$UOFU_CA_CERT_PATH"; then
    echo -n "Enter the path to your CA certificate: " && read UOFU_CA_CERT_PATH || quit "Failed to read CA certificate"
    test -z "$UOFU_CA_CERT_PATH" && exit
fi

echo "Removing conflicting connection profiles..."
nmcli connection delete UConnect # Do nothing it this fails

echo "Creating connection profile for UConnect..."
nmcli connection add type wifi con-name UConnect ssid UConnect ipv4.method auto 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.ca-cert "$UOFU_CA_CERT_PATH" 802-1x.identity "$UOFU_UNID" 802-1x.password "$UOFU_PASSWORD" wifi-sec.key-mgmt wpa-eap || quit "Failed to add connection profile for UConnect"

echo "Connecting..."
nmcli connection up UConnect || quit "Failed to connect to UConnect"

quit "Successfully connected to UConnect" 0
