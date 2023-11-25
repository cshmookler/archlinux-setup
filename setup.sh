#!/bin/bash

# ---- Run this script as root in the Arch Linux live environment ---- #
# Arch Linux installation guide: https://wiki.archlinux.org/title/installation_guide

# Define utility functions
quit() {
    echo "$1"
    if test -f null; then
        rm null
    fi
    if [ -z $2 ]; then
        exit 1
    fi
    exit $2
}

# Change directory before doing anything
echo "----------------------------------------"
if [ -z $SETUP_DIR ]; then
    SETUP_DIR=~
fi
cd $SETUP_DIR || quit "Failed to change directory to home"
echo "Changed directory to $SETUP_DIR"

# Configure the console keyboard layout and font
echo "----------------------------------------"
curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/ubuntu/us-vim.kmap >us-vim.kmap || quit "Failed to download console keyboard layout"
loadkeys us-vim.kmap || quit "Failed to set console keyboard layout"
setfont ter-132b || quit "Failed to set console font"

# Ensure a stable internet connection
echo "----------------------------------------"
if [ -z $SETUP_PING ]; then
    SETUP_PING=1.1.1.1
fi
if ! ping -c 1 $SETUP_PING; then
    quit "Failed to get a response from $SETUP_PING. Check your internet connection."
fi

# Find a suitable disk to partition
echo "----------------------------------------"
if [ -z $SETUP_DISK ]; then
    SETUP_LSBLK=$(lsblk -bp | grep --color=never " disk ")
    if [ -z $SETUP_DISK_MIN_SIZE ]; then
        SETUP_DISK_MIN_SIZE=10000000000 # Minimum disk size in bytes
    fi
    SETUP_DISK_SIZE=$SETUP_DISK_MIN_SIZE
    while read -r SETUP_DISK_CANDIDATE; do
        SETUP_DISK_CANDIDATE_INDEX=0
        for SETUP_DISK_CANDIDATE_FIELD in $SETUP_DISK_CANDIDATE; do
            SETUP_DISK_CANDIDATE_INDEX=$(($SETUP_DISK_CANDIDATE_INDEX + 1))
            eval SETUP_DISK_CANDIDATE_FIELD_$SETUP_DISK_CANDIDATE_INDEX=$SETUP_DISK_CANDIDATE_FIELD
        done
        if ! [ $SETUP_DISK_CANDIDATE_INDEX -lt 7 ]; then
            echo "Ignoring mounted disk: $SETUP_DISK_CANDIDATE_FIELD_1"
            continue
        fi
        if [ $SETUP_DISK_CANDIDATE_FIELD_4 -gt $SETUP_DISK_SIZE ]; then
            # Select the largest disk that meets the minimum size requirement
            SETUP_DISK_SIZE=$SETUP_DISK_CANDIDATE_FIELD_4
            SETUP_DISK=$SETUP_DISK_CANDIDATE_FIELD_1
        fi
    done <<<"$SETUP_LSBLK"
    if [ -z $SETUP_DISK ]; then
        quit "Failed to find a disk that is larger than the minimum size requirement ($SETUP_DISK_MIN_SIZE bytes)"
    fi
fi
echo "Selected disk: $SETUP_DISK"

echo "----------------------------------------"
# # Partition the selected disk
# if ! cat /sys/firmware/efi/fw_platform_size >>null 2>>null; then
#     echo "This system is BIOS bootable only"
#     (
#         echo o # Create a new empty DOS parition table
#         echo n # Add a new partition
#         echo p # Primary partition
#         echo 1 # Partiion number
#         echo
#         echo
#         echo w # Write changes
#     ) | fdisk
# elif cat /sys/firmware/efi/fw_platform_size | grep -q 32; then
#     echo "This system is 32-bit UEFI bootable"
# elif cat /sys/firmware/efi/fw_platform_size | grep -q 64; then
#     echo "This system is 64-bit UEFI bootable"
# else
#     quit "Unable to identify available boot modes. Refer to the Arch Linux installation guide for help."
# fi

echo "----------------------------------------"
# quit "Successfully installed Arch Linux" 0
quit "end of script" 0
