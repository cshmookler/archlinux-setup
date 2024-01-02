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

timer() {
    TIME=$1
    MSG=$2
    while [[ "$TIME" -gt "0" ]]; do
        echo "$2 in $TIME"
        TIME=$((TIME-1))
        read -t 1
    done
}

preprocess() {
    bash -c "bash -c 'echo \"$(cat $1)\"'"
}

echo "----------------------------------------"
echo "Configuring options..."
if [[ -z "$SETUP_DIR" ]]; then
    export SETUP_DIR=~
fi
if [[ -z "$SETUP_PING" ]]; then
    export SETUP_PING=1.1.1.1
fi
if [[ -z "$SETUP_DISK_MIN_BYTES" ]]; then
    export SETUP_DISK_MIN_BYTES=8589934592
fi
if [[ -z "$SETUP_HEADLESS" ]]; then
    export SETUP_HEADLESS=false
fi
if [[ -z "$SETUP_DEVELOPMENT_TOOLS" ]]; then
    export SETUP_DEVELOPMENT_TOOLS=true
fi
if [[ -z "$SETUP_EXTRA_PACKAGES" ]]; then
    export SETUP_EXTRA_PACKAGES=""
fi
export SETUP_BASE_PACKAGES="base base-devel linux linux-firmware networkmanager limine efibootmgr bash bash-completion zsh zsh-completions man-db man-pages texinfo zip unzip curl git python htop lynx ufw transmission-cli openssh openvpn arch-wiki-lite"
if [[ "$SETUP_HEADLESS" = "false" ]]; then
    export SETUP_EXTRA_PACKAGES="xorg xorg-xinit xss-lock physlock ttf-hack-nerd noto-fonts-emoji torbrowser-launcher gtkmm3 alsa-lib vlc pulseaudio libreoffice-fresh xreader $SETUP_EXTRA_PACKAGES"
fi
if [[ "$SETUP_DEVELOPMENT_TOOLS" = "true" ]]; then
    export SETUP_EXTRA_PACKAGES="clang python-black cmake ninja lua-language-server bash-language-server aspell aspell-en $SETUP_EXTRA_PACKAGES"
fi
if [[ -z "$SETUP_TIME_ZONE" ]]; then
    export SETUP_TIME_ZONE="America/Denver"
fi
if [[ -z "$SETUP_HOSTNAME" ]]; then
    export SETUP_HOSTNAME="arch"
fi
if [[ -z "$SETUP_ROOT_PASSWORD" ]]; then
    export SETUP_ROOT_PASSWORD="arch"
fi
if [[ -z "$SETUP_USER" ]]; then
    export SETUP_USER="main"
fi
if [[ -z "$SETUP_USER_PASSWORD" ]]; then
    export SETUP_USER_PASSWORD="main"
fi
if [[ -z "$SETUP_SUDO_GROUP" ]]; then
    export SETUP_SUDO_GROUP="wheel"
fi
if [[ -z "$SETUP_SSH_PORT" ]]; then
    export SETUP_SSH_PORT=22
fi
if [[ -z "$SETUP_RESTART_TIME" ]]; then
    export SETUP_RESTART_TIME=5
fi

echo "----------------------------------------"
echo "Changing directory before doing anything else..."
cd $SETUP_DIR || quit "Failed to change directory to home"
echo "Changed directory to $SETUP_DIR"

echo "----------------------------------------"
echo "Checking internet connectivity..."
if ! ping -c 1 $SETUP_PING; then
    quit "Failed to get a response from $SETUP_PING. Check your internet connection."
fi

echo "----------------------------------------"
echo "Selecting a suitable disk for installation..."
if [[ -z "$SETUP_DISK" ]]; then
    SETUP_LSBLK=$(lsblk -bp | grep --color=never " disk ")
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
    if test -z "$SETUP_DISK"; then
        quit "Failed to find a disk that is larger than the minimum size requirement ($SETUP_DISK_MIN_BYTES bytes)"
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
timer 5 "Beginning installation"

echo "----------------------------------------"
echo "Partitioning, formatting, and mounting $SETUP_DISK"
if ! cat /sys/firmware/efi/fw_platform_size >>null 2>>null; then
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
echo "Changing root to $SETUP_DISK_ROOT_MOUNT"
# echo "# zsh config" >$SETUP_DISK_ROOT_MOUNT/root/.zshrc
arch-chroot $SETUP_DISK_ROOT_MOUNT /bin/zsh -c '

quit() {
    echo "\e[31;1m$'"1"'\e[0m"
    if [[ -z $'"2"' ]]; then
        exit 1
    fi
    exit $'"2"'
}

echo "----------------------------------------"
SETUP_TIME_ZONE="'$SETUP_TIME_ZONE'"
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
SETUP_HOSTNAME="'$SETUP_HOSTNAME'"
echo "Setting hostname: $SETUP_HOSTNAME"
echo "$SETUP_HOSTNAME" >/etc/hostname || quit "Failed to set hostname: $SETUP_HOSTNAME"

echo "----------------------------------------"
echo "Enabling automatic network configuration..."
systemctl enable NetworkManager || quit "Failed to enable networking"

echo "----------------------------------------"
echo "Setting root password..."
SETUP_ROOT_PASSWORD="'$SETUP_ROOT_PASSWORD'"
usermod --password $(openssl passwd -1 $SETUP_ROOT_PASSWORD) root || quit "Failed to set the root password"

echo "----------------------------------------"
echo "Installing custom packages"
git clone https://github.com/cshmookler/archlinux-setup || quit "Failed to download custom packages"
cd archlinux-setup || quit "Failed to change directory to archlinux-setup"
chown -R nobody:nobody . || quit "Failed to change directory permissions of archlinux-setup to nobody:nobody"
echo "%nobody ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo || quit "Failed to temporarily give sudo privileges to user \"nobody\""
installpkg() {
    for SETUP_CUSTOM_PACKAGE in "$@"
    do
        cd $SETUP_CUSTOM_PACKAGE || quit "Failed to change directory to archlinux-setup/$SETUP_CUSTOM_PACKAGE"
        sudo -u nobody makepkg --install --syncdeps --noconfirm || quit "Failed to create package $SETUP_CUSTOM_PACKAGE"
        cd .. || quit "Failed to change directory to archlinux-setup"
    done
}
installpkg cgs-limine-cfg
if [[ "'$SETUP_HEADLESS'" = "false" ]]; then
    installpkg cgs-slock cgs-dmenu cgs-st cgs-slstatus cgs-dwm
fi
if [[ "'$SETUP_DEVELOPMENT_TOOLS'" = "true" ]]; then
    installpkg cgs-neovim-nightly
fi
EDITOR="vim -c ':$ | delete 1 | wq'" visudo || quit "Failed to remove sudo priveleges to user \"nobody\""

echo "----------------------------------------"
export SETUP_USER="'$SETUP_USER'"
echo "Creating user \"$SETUP_USER\"..."
groupadd $SETUP_USER || quit "Failed to create group \"$SETUP_USER\""
useradd -mg $SETUP_USER $SETUP_USER || quit "Failed to create the user \"$SETUP_USER\""
usermod --password $(openssl passwd -1 "'$SETUP_USER_PASSWORD'") $SETUP_USER || quit "Failed to set the password for \"$SETUP_USER\""
if [[ "'$SETUP_HEADLESS'" = "false" ]]; then
    installpkg cgs-xorg-user-cfg
    echo "
# Start the X server on login
if [ -z \"\$DISPLAY\" ] && [ \"\$XDG_VTNR\" = 1 ]; then
    startx
fi
" >>/home/$SETUP_USER/.bash_profile || quit "Failed to enable starting the X server upon login"
fi

echo "----------------------------------------"
echo "Giving the user \"$SETUP_USER\" root privileges..."
SETUP_SUDO_GROUP="'$SETUP_SUDO_GROUP'"
echo "%$SETUP_SUDO_GROUP ALL=(ALL:ALL) ALL" | sudo EDITOR="tee -a" visudo || quit "Failed to give sudo privileges to the \"$SETUP_SUDO_GROUP\" group"
usermod -aG $SETUP_SUDO_GROUP $SETUP_USER || quit "Failed to give sudo privileges to user \"$SETUP_USER\""

echo "----------------------------------------"
echo "Adding custom startup scripts..."
SETUP_VIM_KEYBOARD_LAYOUT="/etc/vim_keyboard_layout/us-vim.kmap"
SETUP_VIM_KEYBOARD_LAYOUT_DIR="$(dirname $SETUP_VIM_KEYBOARD_LAYOUT)"
mkdir -p $SETUP_VIM_KEYBOARD_LAYOUT_DIR || quit "Failed to create $SETUP_VIM_KEYBOARD_LAYOUT_DIR"
curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/tty/us.kmap >$SETUP_VIM_KEYBOARD_LAYOUT_DIR/us.kmap || quit "Failed to download the default console keyboard layout"
curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/tty/us-vim.kmap >$SETUP_VIM_KEYBOARD_LAYOUT_DIR/us-vim.kmap || quit "Failed to download the custom console keyboard layout"
if [[ "'$SETUP_HEADLESS'" = "false" ]]; then
    curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/x11/xmodmap >$SETUP_VIM_KEYBOARD_LAYOUT_DIR/xmodmap || quit "Failed to download the default X11 keyboard layout"
    curl https://raw.githubusercontent.com/cshmookler/vim_keyboard_layout/main/x11/xmodmap-vim >$SETUP_VIM_KEYBOARD_LAYOUT_DIR/xmodmap-vim || quit "Failed to download the custom X11 keyboard layout"
fi
mkdir -p "/etc/profile.d/" || quit "Failed to create $SETUP_DISK_ROOT_MOUNT'/etc/profile.d/'"
echo "loadkeys $SETUP_VIM_KEYBOARD_LAYOUT" >$SETUP_VIM_KEYBOARD_LAYOUT_DIR/load_tty_layout.sh || quit "Failed to create $SETUP_VIM_KEYBOARD_LAYOUT_DIR/load_tty_layout.sh"
mkdir -p /etc/systemd/system || quit "Failed to create /etc/systemd/system"
echo "[Unit]
Description=Loads the vim keyboard layout on startup
After=multi-user.target

[Service]
ExecStart=/bin/bash /etc/vim_keyboard_layout/load_tty_layout.sh

[Install]
WantedBy=graphical.target" >/etc/systemd/system/vim-keyboard-layout.service || quit "Failed to create /etc/systemd/system/vim-keyboard-layout.service"
systemctl enable vim-keyboard-layout.service || quit "Failed to enable custom keyboard layout"

echo "----------------------------------------"
echo "Securing ssh..."
SETUP_SSH_CONFIG=/etc/ssh/sshd_config.d/10-secure.conf
mkdir -p $(dirname $SETUP_SSH_CONFIG) || quit "Failed to create directory $SETUP_SSH_CONFIG"
# By default, users within the sudo group can remotely login with ssh
echo "AllowGroups $SETUP_SUDO_GROUP
Port $SETUP_SSH_PORT
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
LoginGraceTime 1m
PermitRootLogin no
StrictModes yes
MaxAuthTries 6
MaxSessions 10" >$SETUP_SSH_CONFIG || quit "Failed to create the ssh configuration file $SETUP_SSH_CONFIG"
systemctl enable sshd.service || quit "Failed to enable the ssh daemon"

echo "----------------------------------------"
echo "Enabling the firewall..."
systemctl enable ufw.service || quit "Failed to enable the ufw daemon"

echo "----------------------------------------"
echo "Adding the post-installation script..."
SETUP_POST_INSTALL_SCRIPT=/etc/post_install.sh
echo "ufw enable
ufw limit $SETUP_SSH_PORT
systemctl disable post-install.service
rm /etc/systemd/system/post-install.service
rm $SETUP_POST_INSTALL_SCRIPT" >$SETUP_POST_INSTALL_SCRIPT || quit "Failed to create the post-installation script"
chmod +x $SETUP_POST_INSTALL_SCRIPT || quit "Failed to make the post-installation script executable"
echo "[Unit]
Description=Executes post-installation operations that can only be completed after booting into the installed operating system
After=ufw.service

[Service]
ExecStart=/bin/bash $SETUP_POST_INSTALL_SCRIPT

[Install]
WantedBy=graphical.target" >/etc/systemd/system/post-install.service || quit "Failed to create /etc/systemd/system/post-install.service"
systemctl enable post-install.service || quit "Failed to enable the post installation script"

if [[ "'$SETUP_HEADLESS'" = "false" ]]; then
    echo "----------------------------------------"
    echo "Disabling VT switching and zapping within the X server..."
    Xorg :0 -configure || quit "Failed to generate configuration for the X server"
    SETUP_XORG_CONF=/etc/X11/xorg.conf.d/xorg.conf
    mkdir -p $(dirname $SETUP_XORG_CONF) || quit "Failed to create directory $SETUP_XORG_CONF"
    mv /root/xorg.conf.new $SETUP_XORG_CONF || quit "Failed to move configuration for the X server to /etc/X11/"
    echo "Section \"ServerFlags\"
        Option \"DontVTSwitch\" \"True\"
        Option \"DontZap\" \"True\"
EndSection
" >>$SETUP_XORG_CONF || quit "Failed to patch the X server configuration"

    echo "----------------------------------------"
    echo "Configuring the Tor Browser for user \"$SETUP_USER\"..."
    mkdir -p /home/$SETUP_USER/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/ || quit "Failed to create the Tor Browser profile directory for user \"$SETUP_USER\""
    echo "user_pref(\"extensions.torlauncher.start_tor\", false);
user_pref(\"network.dns.disabled\", false);
user_pref(\"network.proxy.socks\", \" \");
user_pref(\"browser.startup.homepage\", \"about:blank\");
user_pref(\"browser.urlbar.suggest.bookmark\", false);
user_pref(\"browser.urlbar.suggest.calculator\", true);" >/home/$SETUP_USER/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default/user.js || quit "Failed to configure the default Tor Browser profile for user \"$SETUP_USER\""
fi

if [[ "'$SETUP_DEVELOPMENT_TOOLS'" = "true" ]]; then
    echo "----------------------------------------"
    echo "Downloading the custom neovim configuration for user \"$SETUP_USER\"..."
    git clone --depth=1 https://github.com/cshmookler/config.nvim /home/$SETUP_USER/.config/nvim || quit "Failed to download the custom neovim configuration for user \"$SETUP_USER\""

    echo "----------------------------------------"
    echo "Generating dictionary for neovim..."
    mkdir -p /etc/xdg/nvim/ || quit "Failed to create /etc/xdg/nvim/"
    aspell -d en dump master | aspell -l en expand >/etc/xdg/nvim/en.dict || quit "Failed generate the dictionary for neovim"
fi

echo "----------------------------------------"
echo "Changing ownership of all files in /home/$SETUP_USER from root to user \"$SETUP_USER\"..."
chown -R $SETUP_USER:$SETUP_USER /home/$SETUP_USER || quit "Failed to change ownership of files in /home/$SETUP_USER from root to user \"$SETUP_USER\"..."

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
if [[ "$SETUP_RESTART_TIME" -ne "-1" ]]; then
    timer $SETUP_RESTART_TIME "Restarting"
    shutdown -r now || quit "Failed to restart"
else
    echo "Restart cancelled"
fi

exit 0
