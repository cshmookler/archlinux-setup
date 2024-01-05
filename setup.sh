#!/bin/bash

greentext() {
    echo -e "\e[32;1m$1\e[0m"
}

yellowtext() {
    echo -e "\e[33;1m$1\e[0m"
}

redtext() {
    echo -e "\e[31;1m$1\e[0m"
}

quit() {
    if ! test -z "$2"; then
        if exit 0 -eq "$2"; then
            greentext "$1"
        else
            redtext "$1"
        fi
        exit 0
    fi
    redtext "$1"
    exit 1
}

timer() {
    TIME=$1
    MSG=$2
    while test $TIME -gt 0; do
        TEXT=$(yellowtext "$2 in $TIME")
        echo -en "\r\e[K$TEXT\t"
        TIME=$((TIME-1))
        read -t 1
    done
}

echo "----------------------------------------"
echo "Sourcing the configuration file..."
if ! source config.sh; then
    yellowtext "No configuration file found. Downloading a template..."
    curl -O https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/config.sh || quit "Failed to download the configuration template file"
    yellowtext "Edit config.sh and source this script again to restart the installation"
    quit "Installation failed. See above for details."
fi

echo "----------------------------------------"
echo "Configuring options..."
if test -z "$SETUP_PING"; then
    SETUP_PING=1.1.1.1
fi
if test -z "$SETUP_DISK_MIN_BYTES"; then
    SETUP_DISK_MIN_BYTES=8000000000
fi
if test -z "$SETUP_HEADLESS"; then
    SETUP_HEADLESS=false
fi
if test -z "$SETUP_DEVELOPMENT_TOOLS"; then
    SETUP_DEVELOPMENT_TOOLS=true
fi
if test -z "$SETUP_EXTRA_PACKAGES"; then
    SETUP_EXTRA_PACKAGES=""
fi
# SETUP_BASE_PACKAGES="base base-devel linux linux-firmware networkmanager limine efibootmgr bash bash-completion man-db man-pages texinfo zip unzip curl git python htop lynx ufw transmission-cli openssh openvpn arch-wiki-lite"
SETUP_BASE_PACKAGES="base base-devel linux linux-firmware networkmanager bash bash-completion man-db man-pages texinfo curl git zip unzip python htop lynx ufw openssh"
if test "$SETUP_HEADLESS" = "false"; then
    # SETUP_EXTRA_PACKAGES="xorg xorg-xinit xss-lock physlock ttf-hack-nerd noto-fonts-emoji torbrowser-launcher gtkmm3 alsa-lib vlc pulseaudio libreoffice-fresh xreader $SETUP_EXTRA_PACKAGES"
    SETUP_EXTRA_PACKAGES="$SETUP_EXTRA_PACKAGES"
fi
if test "$SETUP_DEVELOPMENT_TOOLS" = "true"; then
    # SETUP_EXTRA_PACKAGES="clang python-black cmake ninja lua-language-server bash-language-server aspell aspell-en $SETUP_EXTRA_PACKAGES"
    SETUP_EXTRA_PACKAGES="$SETUP_EXTRA_PACKAGES"
fi
if test -z "$SETUP_TIME_ZONE"; then
    SETUP_TIME_ZONE="America/Denver"
fi
if test -z "$SETUP_HOSTNAME"; then
    SETUP_HOSTNAME="arch"
fi
if test -z "$SETUP_ROOT_PASSWORD"; then
    SETUP_ROOT_PASSWORD="arch"
fi
if test -z "$SETUP_USER"; then
    SETUP_USER="main"
fi
if test -z "$SETUP_USER_PASSWORD"; then
    SETUP_USER_PASSWORD="main"
fi
if test -z "$SETUP_SUDO_GROUP"; then
    SETUP_SUDO_GROUP="wheel"
fi
if test -z "$SETUP_SSH_PORT"; then
    SETUP_SSH_PORT=22
fi
if test -z "$SETUP_RESTART_TIME"; then
    SETUP_RESTART_TIME=5
fi

echo "----------------------------------------"
echo "Checking internet connectivity..."
if ! ping -c 1 $SETUP_PING; then
    quit "Failed to get a response from $SETUP_PING. Check your internet connection."
fi

echo "----------------------------------------"
echo "Selecting a suitable disk for installation..."
if test -z "$SETUP_DISK"; then
    SETUP_DISK_SIZE=$SETUP_DISK_MIN_BYTES
    SETUP_LSBLK=$(lsblk -nrbp | grep --color=never " disk ")
    while read -r SETUP_DISK_CANDIDATE; do
        read -a SETUP_DISK_CANDIDATE_INDEXABLE <<<$SETUP_LSBLK
        SETUP_DISK_CANDIDATE_INDEX=0
        SETUP_DISK_CANDIDATE_PATH=${SETUP_DISK_CANDIDATE_INDEXABLE[0]}
        SETUP_DISK_CANDIDATE_SIZE=${SETUP_DISK_CANDIDATE_INDEXABLE[3]}
        SETUP_DISK_CANDIDATE_MOUNT=${SETUP_DISK_CANDIDATE_INDEXABLE[6]}
        if test -n "$SETUP_DISK_CANDIDATE_MOUNT"; then
            echo "Ignoring mounted disk: $SETUP_DISK_CANDIDATE_FIELD_1"
            continue
        fi
        if test $SETUP_DISK_CANDIDATE_SIZE -gt $SETUP_DISK_SIZE; then
            SETUP_DISK_SIZE=$SETUP_DISK_CANDIDATE_SIZE
            SETUP_DISK=$SETUP_DISK_CANDIDATE_PATH
        fi
    done <<<"$SETUP_LSBLK"
    if test -z "$SETUP_DISK"; then
        quit "Failed to find a disk that meets the minimum size requirement ($SETUP_DISK_MIN_BYTES bytes)"
    fi
fi
echo "Selected disk: $SETUP_DISK"

echo "----------------------------------------"
echo "Installing Arch Linux with the current configuration:

                  disk -> $SETUP_DISK
              headless -> $SETUP_HEADLESS
     development tools -> $SETUP_DEVELOPMENT_TOOLS
         base packages -> $SETUP_BASE_PACKAGES
        extra packages -> $SETUP_EXTRA_PACKAGES
             time zone -> $SETUP_TIME_ZONE
              hostname -> $SETUP_HOSTNAME
         root password -> $SETUP_ROOT_PASSWORD
         non-root user -> $SETUP_USER
non-root user password -> $SETUP_USER_PASSWORD
            sudo group -> $SETUP_SUDO_GROUP
              ssh port -> $SETUP_SSH_PORT
"
redtext "Type Ctrl+C to cancel"
timer 30 "Beginning installation"
echo ""

echo "----------------------------------------"
echo "Partitioning, formatting, and mounting $SETUP_DISK"
if ! test -f /sys/firmware/efi/fw_platform_size; then
    echo "This system is BIOS bootable only"
    export SETUP_BOOT_MODE=BIOS
    (
        echo o     # new MBR partition table
        echo n     # new boot partition (required by limine)
        echo p     # primary partition
        echo 1     # boot partition number
        echo       # start at the first sector
        echo +512M # reserve space for the boot partition
        echo a     # set the bootable flag
        echo n     # new root partition
        echo p     # primary partition
        echo 2     # root partiion number
        echo       # start at the end of the boot partition
        echo       # reserve the rest of the disk
        echo w     # write changes
    ) | fdisk $SETUP_DISK || quit "Failed to partition disk: $SETUP_DISK"
    export SETUP_DISK_BOOT=$SETUP_DISK"1"
    export SETUP_DISK_ROOT=$SETUP_DISK"2"
    echo "Created boot partition: $SETUP_DISK_BOOT"
    echo "Created root partition: $SETUP_DISK_ROOT"
    mkfs.fat -F 32 $SETUP_DISK_BOOT || quit "Failed to format the boot partition: $SETUP_DISK_BOOT"
    mkfs.ext4 $SETUP_DISK_ROOT || quit "Failed to format the root partition: $SETUP_DISK_ROOT"
    echo "Formatted boot partition with FAT32"
    echo "Formatted root partition with EXT4"
    export SETUP_DISK_ROOT_MOUNT=/mnt
    export SETUP_DISK_BOOT_MOUNT=/mnt/boot
    # The root partition must be mounted first because the boot partition is mounted within the root filesystem
    mount --mkdir $SETUP_DISK_ROOT $SETUP_DISK_ROOT_MOUNT || quit "Failed to mount $SETUP_DISK_ROOT -> $SETUP_DISK_ROOT_MOUNT"
    mount --mkdir $SETUP_DISK_BOOT $SETUP_DISK_BOOT_MOUNT || quit "Failed to mount $SETUP_DISK_BOOT -> $SETUP_DISK_BOOT_MOUNT"
    echo "Mounted root partition to $SETUP_DISK_ROOT_MOUNT"
    echo "Mounted boot partition to $SETUP_DISK_BOOT_MOUNT"
elif cat /sys/firmware/efi/fw_platform_size | grep -q 32; then
    echo "This system is 32-bit UEFI bootable"
    export SETUP_BOOT_MODE=UEFI-32
elif cat /sys/firmware/efi/fw_platform_size | grep -q 64; then
    echo "This system is 64-bit UEFI bootable"
    export SETUP_BOOT_MODE=UEFI-64
else
    quit "Unable to identify available boot modes. Refer to the Arch Linux installation guide for help"
fi

if test "$SETUP_BOOT_MODE" = "UEFI-32" -o "$SETUP_BOOT_MODE" = "UEFI-64"; then
    (
        echo g     # new GPT partition table
        echo n     # new EFI partition
        echo 1     # EFI partiion number
        echo       # start at the first sector
        echo +512M # reserve space for the EFI partition
        echo t     # change EFI partition type
        echo 1     # change partition type to EFI System
        echo n     # new root partition
        echo 2     # root partition number
        echo       # start at the end of the EFI partition
        echo       # reserve the rest of the disk
        echo w     # write changes
    ) | fdisk $SETUP_DISK || quit "Failed to partition disk: $SETUP_DISK"
    export SETUP_DISK_EFI=$SETUP_DISK"1"
    export SETUP_DISK_ROOT=$SETUP_DISK"2"
    echo "Created EFI partition: $SETUP_DISK_EFI"
    echo "Created root partition: $SETUP_DISK_ROOT"
    mkfs.fat -F 32 $SETUP_DISK_EFI || quit "Failed to format the EFI partition: $SETUP_DISK_EFI"
    mkfs.ext4 $SETUP_DISK_ROOT || quit "Failed to format the root partition: $SETUP_DISK_ROOT"
    echo "Formatted EFI partition with FAT32"
    echo "Formatted root partition with EXT4"
    export SETUP_DISK_ROOT_MOUNT=/mnt
    export SETUP_DISK_EFI_MOUNT=/mnt/boot
    mount --mkdir $SETUP_DISK_ROOT $SETUP_DISK_ROOT_MOUNT || quit "Failed to mount $SETUP_DISK_ROOT -> $SETUP_DISK_ROOT_MOUNT"
    mount --mkdir $SETUP_DISK_EFI $SETUP_DISK_EFI_MOUNT || quit "Failed to mount $SETUP_DISK_EFI -> $SETUP_DISK_EFI_MOUNT"
    echo "Mounted root partition to $SETUP_DISK_ROOT_MOUNT"
    echo "Mounted EFI partition to $SETUP_DISK_EFI_MOUNT"
fi

echo "----------------------------------------"
echo "Installing packages with pacstrap..."
pacman -Sy --noconfirm archlinux-keyring || quit "Failed to update keyring"
eval "pacstrap -K $SETUP_DISK_ROOT_MOUNT $SETUP_BASE_PACKAGES $SETUP_EXTRA_PACKAGES" || quit "Failed to install essential packages"

echo "----------------------------------------"
echo "Generating fstab..."
genfstab -U $SETUP_DISK_ROOT_MOUNT >>$SETUP_DISK_ROOT_MOUNT"/etc/fstab" || quit "Failed to generate fstab"

echo "----------------------------------------"
echo "Downloading the post-pacstrap installation script..."
curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/post-pacstrap-setup.sh >$SETUP_DISK_ROOT_MOUNT/setup.sh || quit "Failed to download the post-pacstrap installation script"

echo "----------------------------------------"
echo "Changing root to $SETUP_DISK_ROOT_MOUNT"
arch-chroot $SETUP_DISK_ROOT_MOUNT /bin/bash /setup.sh || quit "Failed operation while root was changed to $SETUP_DISK_ROOT_MOUNT"

echo "----------------------------------------"
echo "Removing the post-pacstrap installation script..."
rm $SETUP_DISK_ROOT_MOUNT/setup.sh || redtext "Failed to remove the psot-pacstrap installation script at $SETUP_DISK_ROOT_MOUNT/setup.sh"

echo "----------------------------------------"
echo "Unmounting all file systems on $SETUP_DISK_ROOT_MOUNT"
umount -R $SETUP_DISK_ROOT_MOUNT || quit "Failed to unmount all file systems on $SETUP_DISK_ROOT_MOUNT"

echo "----------------------------------------"
greentext "Successfully installed Arch Linux"

echo "----------------------------------------"
if test "$SETUP_RESTART_TIME" -ne "-1"; then
    timer "$SETUP_RESTART_TIME" "Restarting"
    shutdown -r now || quit "Failed to restart"
else
    echo "Restart cancelled"
fi
