#!/bin/bash

# ---- Run this script as root in the Arch Linux live environment ---- #
# Arch Linux installation guide: https://wiki.archlinux.org/title/installation_guide

# Define utility functions
quit() {
    echo "$1"
    exit 1
}

# Go home
cd ~ || quit "Failed to change directory to home"

# Configure the console
curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/ubuntu/us-vim.kmap >us-vim.kmap || quit "Failed to download console keyboard layout"
loadkeys us-vim.kmap || quit "Failed to set console keyboard layout"
setfont ter-132b || quit "Failed to set console font"

# Verify boot mode
if ! cat /sys/firmware/efi/fw_platform_size >>null 2>>null; then
    echo "This system is BIOS bootable only"
elif cat /sys/firmware/efi/fw_platform_size | grep -q 32; then
    echo "This system is 32-bit UEFI bootable"
elif cat /sys/firmware/efi/fw_platform_size | grep -q 64; then
    echo "This system is 64-bit UEFI bootable"
else
    quit "Unable to identify available boot modes. Refer to the Arch Linux installation guide for help."
fi

# Ensure a stable internet connection
if ! ping -c 3 1.1.1.1; then
    quit "Failed to ping 1.1.1.1 (Cloudflare DNS). Check your internet connection."
fi
