#!/bin/zsh

# ---- Run this script as root in the Arch Linux live environment ---- #
# Arch Linux installation guide: https://wiki.archlinux.org/title/installation_guide

quit() {
    echo "\e[31;1m$1\e[0m"
    if test -f null; then
        rm null
    fi
    if [[ -z $2 ]]; then
        exit 1
    fi
    exit $2
}

echo "----------------------------------------"
echo "Changing directory before doing anything else..."
if [[ -z "$SETUP_DIR" ]]; then
    SETUP_DIR=~
fi
cd $SETUP_DIR || quit "Failed to change directory to home"
echo "Changed directory to $SETUP_DIR"

echo "----------------------------------------"
echo "Checking internet connectivity..."
if [[ -z "$SETUP_PING" ]]; then
    SETUP_PING=1.1.1.1
fi
if ! ping -c 1 $SETUP_PING; then
    quit "Failed to get a response from $SETUP_PING. Check your internet connection."
fi

echo "----------------------------------------"
echo "Setting console keyboard layout and font..."
curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/ubuntu/us-vim.kmap >us-vim.kmap || quit "Failed to download console keyboard layout"
loadkeys us-vim.kmap || quit "Failed to set console keyboard layout"
setfont ter-132b || quit "Failed to set console font"

echo "----------------------------------------"
echo "Selecting a suitable disk for installation..."
if [[ -z "$SETUP_DISK" ]]; then
    SETUP_LSBLK=$(lsblk -bp | grep --color=never " disk ")
    if [[ -z "$SETUP_DISK_MIN_BYTES" ]]; then
        SETUP_DISK_MIN_BYTES=10737418240
    fi
    SETUP_DISK_SIZE=$SETUP_DISK_MIN_BYTES
    while read -r SETUP_DISK_CANDIDATE; do
        SETUP_DISK_CANDIDATE_INDEX=0
        for SETUP_DISK_CANDIDATE_FIELD in ${(s: :)SETUP_DISK_CANDIDATE}; do
            SETUP_DISK_CANDIDATE_INDEX=$(($SETUP_DISK_CANDIDATE_INDEX + 1))
            eval SETUP_DISK_CANDIDATE_FIELD_$SETUP_DISK_CANDIDATE_INDEX=$SETUP_DISK_CANDIDATE_FIELD
        done
        if ! [[ $SETUP_DISK_CANDIDATE_INDEX -lt 7 ]]; then
            echo "Ignoring mounted disk: $SETUP_DISK_CANDIDATE_FIELD_1"
            continue
        fi
        if [[ $SETUP_DISK_CANDIDATE_FIELD_4 -gt $SETUP_DISK_SIZE ]]; then
            # Select the largest disk that meets the minimum size requirement
            SETUP_DISK_SIZE=$SETUP_DISK_CANDIDATE_FIELD_4
            SETUP_DISK=$SETUP_DISK_CANDIDATE_FIELD_1
        fi
    done <<<"$SETUP_LSBLK"
    if [[ -z "$SETUP_DISK" ]]; then
        quit "Failed to find a disk that is larger than the minimum size requirement ($SETUP_DISK_MIN_BYTES bytes)"
    fi
fi
echo "Selected disk: $SETUP_DISK"

echo "----------------------------------------"
echo "Partitioning, formatting, and mounting $SETUP_DISK"
if ! cat /sys/firmware/efi/fw_platform_size >>null 2>>null; then
    echo "This system is BIOS bootable only"
    SETUP_BOOT_MODE=BIOS
    (
        echo o # new MBR partition table
        echo n # new root partition
        echo p # primary partition
        echo 1 # root partiion number
        echo   # start at the first sector
        echo   # reserve the entire disk
        echo a # set the bootable flag
        echo w # write changes
    ) | fdisk $SETUP_DISK || quit "Failed to partition disk: $SETUP_DISK"
    SETUP_DISK_ROOT=$SETUP_DISK"1"
    echo "Created root partition: $SETUP_DISK_ROOT"
    mkfs.ext4 $SETUP_DISK_ROOT || quit "Failed to format the root partition: $SETUP_DISK_ROOT"
    echo "Formatted root partition with EXT4"
    SETUP_DISK_ROOT_MOUNT=/mnt
    mount --mkdir $SETUP_DISK_ROOT $SETUP_DISK_ROOT_MOUNT || quit "Failed to mount $SETUP_DISK_ROOT -> $SETUP_DISK_ROOT_MOUNT"
    echo "Mounted root partition to $SETUP_DISK_ROOT_MOUNT"
elif cat /sys/firmware/efi/fw_platform_size | grep -q 32; then
    echo "This system is 32-bit UEFI bootable"
    SETUP_BOOT_MODE=UEFI-32
elif cat /sys/firmware/efi/fw_platform_size | grep -q 64; then
    echo "This system is 64-bit UEFI bootable"
    SETUP_BOOT_MODE=UEFI-64
else
    quit "Unable to identify available boot modes. Refer to the Arch Linux installation guide for help."
fi

if [[ "$SETUP_BOOT_MODE" = "UEFI-32" ]] || [[ "$SETUP_BOOT_MODE" = "UEFI-64" ]]; then
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
    SETUP_DISK_EFI=$SETUP_DISK"1"
    SETUP_DISK_ROOT=$SETUP_DISK"2"
    echo "Created EFI partition: $SETUP_DISK_EFI"
    echo "Created root partition: $SETUP_DISK_ROOT"
    mkfs.fat -F 32 $SETUP_DISK_EFI || quit "Failed to format the EFI partition: $SETUP_DISK_EFI"
    mkfs.ext4 $SETUP_DISK_ROOT || quit "Failed to format the root partition: $SETUP_DISK_ROOT"
    echo "Formatted EFI partition with FAT32"
    echo "Formatted root partition with EXT4"
    SETUP_DISK_EFI_MOUNT=/mnt/boot
    SETUP_DISK_ROOT_MOUNT=/mnt
    mount --mkdir $SETUP_DISK_EFI $SETUP_DISK_EFI_MOUNT || quit "Failed to mount $SETUP_DISK_EFI -> $SETUP_DISK_EFI_MOUNT"
    mount --mkdir $SETUP_DISK_ROOT $SETUP_DISK_ROOT_MOUNT || quit "Failed to mount $SETUP_DISK_ROOT -> $SETUP_DISK_ROOT_MOUNT"
    echo "Mounted EFI partition to $SETUP_DISK_EFI_MOUNT"
    echo "Mounted root partition to $SETUP_DISK_ROOT_MOUNT"
fi

echo "----------------------------------------"
echo "Installing packages with pacstrap..."
SETUP_BASE_PACKAGES = "base base-devel linux linux-firmware networkmanager limine zsh zsh-completions man-db man-pages texinfo vim"
if [[ -z "$SETUP_EXTRA_PACKAGES" ]]; then
    SETUP_EXTRA_PACKAGES=""
fi
if [[ -z "$SETUP_HEADLESS" ]]; then
    SETUP_HEADLESS=false
fi
if [[ "$SETUP_HEADLESS" = "false" ]]; then
    SETUP_EXTRA_PACKAGES="dwm libreoffice firefox "$SETUP_EXTRA_PACKAGES
fi
if [[ -z "$SETUP_DEVELOPMENT_TOOLS" ]]; then
    SETUP_DEVELOPMENT_TOOLS=true
fi
if [[ "$SETUP_DEVELOPMENT_TOOLS" = "true" ]]; then
    SETUP_EXTRA_PACKAGES="git clang "$SETUP_EXTRA_PACKAGES
fi
pacstrap -K $SETUP_DISK_ROOT_MOUNT $SETUP_BASE_PACKAGES $SETUP_EXTRA_PACKAGES || quit "Failed to install essential packages"

echo "----------------------------------------"
echo "Generating fstab..."
genfstab -U $SETUP_DISK_ROOT_MOUNT >>$SETUP_DISK_ROOT_MOUNT"/etc/fstab" || quit "Failed to generate fstab"

echo "----------------------------------------"
echo "Changing root to $SETUP_DISK_ROOT_MOUNT"
echo "# zsh config" >$SETUP_DISK_ROOT_MOUNT/root/.zshrc.
arch-chroot $SETUP_DISK_ROOT_MOUNT /bin/zsh -c '

quit() {
    echo "\e[31;1m$'"1"'\e[0m"
    if [[ -z $'"2"' ]]; then
        exit 1
    fi
    exit $'"2"'
}

echo "----------------------------------------"
if [[ -z "'$SETUP_TIME_ZONE'" ]]; then
    SETUP_TIME_ZONE="America/Denver"
else
    SETUP_TIME_ZONE="'$SETUP_TIME_ZONE'"
fi
echo "Setting time zone: $SETUP_TIME_ZONE"
ln -sf /usr/share/zoneinfo/$SETUP_TIME_ZONE /etc/localtime || quit "Failed to set time zone: $SETUP_TIME_ZONE"

echo "----------------------------------------"
echo "Setting hardware clock..."
hwclock --systohc || quit "Failed to set hardware clock"

echo "----------------------------------------"
echo "Generating locales..."
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen || quit "Failed to set locales"
locale-gen || quit "Failed to generate locales"
echo "LANG=en_US.UTF-8" >/etc/locale.conf || quit "Failed to generate locale configuration file"

echo "----------------------------------------"
if [[ -z "'$SETUP_HOSTNAME'" ]]; then
    SETUP_HOSTNAME="arch"
else
    SETUP_HOSTNAME="'$SETUP_HOSTNAME'"
fi
echo "Setting hostname: $SETUP_HOSTNAME"
echo "$SETUP_HOSTNAME" >/etc/hostname || quit "Failed to set hostname: $SETUP_HOSTNAME"

echo "----------------------------------------"
echo "Enabling automatic network configuration..."
systemctl enable NetworkManager || quit "Failed to enable networking"

echo "----------------------------------------"
if [[ -z "'$SETUP_ROOT_PASSWORD'" ]]; then
    SETUP_ROOT_PASSWORD="arch"
else
    SETUP_ROOT_PASSWORD="'$SETUP_ROOT_PASSWORD'"
fi
echo "Setting root password..."
usermod --password $(openssl passwd -1 $SETUP_ROOT_PASSWORD) root || quit "Failed to set the root password"

echo "----------------------------------------"
SETUP_BOOT_LOADER_DIR=/boot/limine
echo "Moving boot loader to $SETUP_BOOT_LOADER_DIR"
mkdir $SETUP_BOOT_LOADER_DIR || quit "Failed to create boot loader subdirectory"
mkdir /etc/pacman.d/hooks || quit "Failed to create the pacman hooks subdirectory"
if [[ "'$SETUP_BOOT_MODE'" = "UEFI-32" ]] || [[ "'$SETUP_BOOT_MODE'" = "UEFI-64" ]]; then
    mkdir /boot/EFI || quit "Failed to create EFI subdirectory"
    mkdir /boot/EFI/BOOT || quit "Failed to create EFI boot subdirectory"
    echo "[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine              

[Action]
Description = Deploying Limine after upgrade...
When = PostTransaction
Exec = /usr/bin/cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
    " >/etc/pacman.d/hooks/liminedeploy.hook || quit "Failed to create hook for automatically deplouing the boot loader after upgrade"
else
    echo "[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine

[Action]
Description = Deploying Limine after upgrade...
When = PostTransaction
Exec = /bin/bash -c \"/usr/bin/limine bios-install '$SETUP_DISK' && /usr/bin/cp /usr/share/limine/limine-bios.sys $SETUP_BOOT_LOADER_DIR\"
    " >/etc/pacman.d/hooks/liminedeploy.hook || quit "Failed to create hook for automatically deploying the boot loader after upgrade"
fi
pacman -S --noconfirm limine || quit "Failed to deploy the boot loader"
echo "TIMEOUT=0

:Arch Linux
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/vmlinuz-linux
    CMDLINE=root=UUID=$(findmnt '$SETUP_DISK_ROOT' -no UUID) rw
    MODULE_PATH=boot:///boot/initramfs-linux.img
" >/boot/limine/limine.cfg

echo "----------------------------------------"
echo "Changing root back to installation media..."
exit 0

' || quit "Failed operation while root was changed to $SETUP_DISK_ROOT_MOUNT"

echo "----------------------------------------"
echo "Unmounting all file systems on $SETUP_DISK_ROOT_MOUNT"
umount -R $SETUP_DISK_ROOT_MOUNT || quit "Failed to unmount all file systems on $SETUP_DISK_ROOT_MOUNT"

echo "----------------------------------------"
echo "\e[32;1mSuccessfully installed Arch Linux\e[0m"

echo "----------------------------------------"
if [[ -z "$SETUP_RESTART_TIME" ]]; then
    SETUP_RESTART_TIME=5
fi
if [[ "$SETUP_RESTART_TIME" -ne "-1" ]]; then
    while [[ "$SETUP_RESTART_TIME" -gt "0" ]]; do
        echo "Restarting in $SETUP_RESTART_TIME"
        SETUP_RESTART_TIME=$((SETUP_RESTART_TIME-1))
        read -t 1
    done
    shutdown -r now || quit "Failed to restart"
else
    echo "Restart cancelled"
fi

exit 0
