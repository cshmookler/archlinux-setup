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

echo "----------------------------------------"
echo "Configuring options..."
if [[ -z "$SETUP_DIR" ]]; then
    SETUP_DIR=~
fi
if [[ -z "$SETUP_PING" ]]; then
    SETUP_PING=1.1.1.1
fi
if [[ -z "$SETUP_DISK_MIN_BYTES" ]]; then
    SETUP_DISK_MIN_BYTES=8589934592
fi
if [[ -z "$SETUP_HEADLESS" ]]; then
    SETUP_HEADLESS=false
fi
if [[ -z "$SETUP_DEVELOPMENT_TOOLS" ]]; then
    SETUP_DEVELOPMENT_TOOLS=true
fi
if [[ -z "$SETUP_EXTRA_PACKAGES" ]]; then
    SETUP_EXTRA_PACKAGES=""
fi
SETUP_BASE_PACKAGES="base base-devel linux linux-firmware networkmanager limine efibootmgr bash bash-completion zsh zsh-completions man-db man-pages texinfo zip unzip curl git python htop lynx ufw transmission-cli openssh"
if [[ "$SETUP_HEADLESS" = "false" ]]; then
    SETUP_EXTRA_PACKAGES="xorg xorg-xinit xss-lock physlock ttf-hack-nerd noto-fonts-emoji torbrowser-launcher gtkmm3 alsa-lib vlc libreoffice-fresh xreader $SETUP_EXTRA_PACKAGES"
fi
if [[ "$SETUP_DEVELOPMENT_TOOLS" = "true" ]]; then
    SETUP_EXTRA_PACKAGES="clang python-black cmake ninja lua-language-server bash-language-server aspell aspell-en $SETUP_EXTRA_PACKAGES"
fi
if [[ -z "$SETUP_TIME_ZONE" ]]; then
    SETUP_TIME_ZONE="America/Denver"
fi
if [[ -z "$SETUP_HOSTNAME" ]]; then
    SETUP_HOSTNAME="arch"
fi
if [[ -z "$SETUP_ROOT_PASSWORD" ]]; then
    SETUP_ROOT_PASSWORD="arch"
fi
if [[ -z "$SETUP_USER" ]]; then
    SETUP_USER="main"
fi
if [[ -z "$SETUP_USER_PASSWORD" ]]; then
    SETUP_USER_PASSWORD="main"
fi
if [[ -z "$SETUP_SUDO_GROUP" ]]; then
    SETUP_SUDO_GROUP="wheel"
fi
if [[ -z "$SETUP_SSH_PORT" ]]; then
    SETUP_SSH_PORT=22
fi
if [[ -z "$SETUP_RESTART_TIME" ]]; then
    SETUP_RESTART_TIME=5
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
    if [[ -z "$SETUP_DISK" ]]; then
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
"
timer 5 "Beginning installation"

echo "----------------------------------------"
echo "Partitioning, formatting, and mounting $SETUP_DISK"
if ! cat /sys/firmware/efi/fw_platform_size >>null 2>>null; then
    echo "This system is BIOS bootable only"
    SETUP_BOOT_MODE=BIOS
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
    SETUP_DISK_BOOT=$SETUP_DISK"1"
    SETUP_DISK_ROOT=$SETUP_DISK"2"
    echo "Created boot partition: $SETUP_DISK_BOOT"
    echo "Created root partition: $SETUP_DISK_ROOT"
    mkfs.fat -F 32 $SETUP_DISK_BOOT || quit "Failed to format the boot partition: $SETUP_DISK_BOOT"
    mkfs.ext4 $SETUP_DISK_ROOT || quit "Failed to format the root partition: $SETUP_DISK_ROOT"
    echo "Formatted boot partition with FAT32"
    echo "Formatted root partition with EXT4"
    SETUP_DISK_ROOT_MOUNT=/mnt
    SETUP_DISK_BOOT_MOUNT=/mnt/boot
    # The root partition must be mounted first because the boot partition is mounted within the root filesystem
    mount --mkdir $SETUP_DISK_ROOT $SETUP_DISK_ROOT_MOUNT || quit "Failed to mount $SETUP_DISK_ROOT -> $SETUP_DISK_ROOT_MOUNT"
    mount --mkdir $SETUP_DISK_BOOT $SETUP_DISK_BOOT_MOUNT || quit "Failed to mount $SETUP_DISK_BOOT -> $SETUP_DISK_BOOT_MOUNT"
    echo "Mounted root partition to $SETUP_DISK_ROOT_MOUNT"
    echo "Mounted boot partition to $SETUP_DISK_BOOT_MOUNT"
elif cat /sys/firmware/efi/fw_platform_size | grep -q 32; then
    echo "This system is 32-bit UEFI bootable"
    SETUP_BOOT_MODE=UEFI-32
elif cat /sys/firmware/efi/fw_platform_size | grep -q 64; then
    echo "This system is 64-bit UEFI bootable"
    SETUP_BOOT_MODE=UEFI-64
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
    SETUP_DISK_EFI=$SETUP_DISK"1"
    SETUP_DISK_ROOT=$SETUP_DISK"2"
    echo "Created EFI partition: $SETUP_DISK_EFI"
    echo "Created root partition: $SETUP_DISK_ROOT"
    mkfs.fat -F 32 $SETUP_DISK_EFI || quit "Failed to format the EFI partition: $SETUP_DISK_EFI"
    mkfs.ext4 $SETUP_DISK_ROOT || quit "Failed to format the root partition: $SETUP_DISK_ROOT"
    echo "Formatted EFI partition with FAT32"
    echo "Formatted root partition with EXT4"
    SETUP_DISK_ROOT_MOUNT=/mnt
    SETUP_DISK_EFI_MOUNT=/mnt/boot
    mount --mkdir $SETUP_DISK_ROOT $SETUP_DISK_ROOT_MOUNT || quit "Failed to mount $SETUP_DISK_ROOT -> $SETUP_DISK_ROOT_MOUNT"
    mount --mkdir $SETUP_DISK_EFI $SETUP_DISK_EFI_MOUNT || quit "Failed to mount $SETUP_DISK_EFI -> $SETUP_DISK_EFI_MOUNT"
    echo "Mounted root partition to $SETUP_DISK_ROOT_MOUNT"
    echo "Mounted EFI partition to $SETUP_DISK_EFI_MOUNT"
fi

echo "----------------------------------------"
echo "Installing packages with pacstrap..."
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
SETUP_BOOT_LOADER_DIR=/boot/limine
echo "Moving boot loader to $SETUP_BOOT_LOADER_DIR"
mkdir -p $SETUP_BOOT_LOADER_DIR || quit "Failed to create boot loader subdirectory"
mkdir -p /etc/pacman.d/hooks || quit "Failed to create the pacman hooks subdirectory"
if [[ "'$SETUP_BOOT_MODE'" = "UEFI-32" ]] || [[ "'$SETUP_BOOT_MODE'" = "UEFI-64" ]]; then
    echo "[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine

[Action]
Description = Deploying Limine after upgrade...
When = PostTransaction
Exec = /usr/bin/cp /usr/share/limine/BOOTX64.EFI /boot/
    " >/etc/pacman.d/hooks/liminedeploy.hook || quit "Failed to create hook for automatically deplouing the boot loader after upgrade"
elif [[ "'$SETUP_BOOT_MODE'" = "BIOS" ]]; then
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
else
    quit "Unknown boot mode: '$SETUP_BOOT_MODE'"
fi
pacman -S --noconfirm limine || quit "Failed to deploy the boot loader"
echo "TIMEOUT=0

:Arch Linux
    PROTOCOL=linux
    KERNEL_PATH=boot:///vmlinuz-linux
    CMDLINE=root=UUID=$(findmnt '$SETUP_DISK_ROOT' -no UUID) rw
    MODULE_PATH=boot:///initramfs-linux.img
" >/boot/limine/limine.cfg || quit "Failed to create the boot loader configuration file"

if [[ "'$SETUP_BOOT_MODE'" = "UEFI-32" ]] || [[ "'$SETUP_BOOT_MODE'" = "UEFI-64" ]]; then
    echo "Adding EFI boot label..."
    efibootmgr --create --disk "'$SETUP_DISK_EFI'" --loader /BOOTX64.EFI --label "Arch Linux" --unicode || quit "Failed to create the EFI boot label"
fi

echo "----------------------------------------"
SETUP_USER="'$SETUP_USER'"
echo "Creating user \"$SETUP_USER\"..."
groupadd $SETUP_USER || quit "Failed to create group \"$SETUP_USER\""
useradd -mg $SETUP_USER $SETUP_USER || quit "Failed to create the user \"$SETUP_USER\""
usermod --password $(openssl passwd -1 "'$SETUP_USER_PASSWORD'") $SETUP_USER || quit "Failed to set the password for \"$SETUP_USER\""
if [[ "'$SETUP_HEADLESS'" = "false" ]]; then
    echo "xmodmap /etc/vim_keyboard_layout/xmodmap-vim
xset s 120 120 dpms 120 120 120
nohup xss-lock slock </dev/null >/dev/null 2>&1 &
/usr/local/src/dwm-bar/dwm_bar.sh &
dwm
physlock -p \"This console is locked by $'"USER"'\"" >/home/$SETUP_USER/.xinitrc || quit "Failed to create the X server init file"
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
mkdir -p $SETUP_DISK_ROOT_MOUNT"/etc/profile.d/" || quit "Failed to create $SETUP_DISK_ROOT_MOUNT'/etc/profile.d/'"
echo "loadkeys $SETUP_VIM_KEYBOARD_LAYOUT" >$SETUP_VIM_KEYBOARD_LAYOUT_DIR/load_tty_layout.sh || quit "Failed to create $SETUP_VIM_KEYBOARD_LAYOUT_DIR/load_tty_layout.sh"
mkdir -p $SETUP_DISK_ROOT_MOUNT/etc/systemd/system || quit "Failed to create $SETUP_DISK_ROOT_MOUNT/etc/systemd/system"
echo "[Unit]
Description=Loads the vim keyboard layout on startup
After=multi-user.target

[Service]
ExecStart=/bin/bash /etc/vim_keyboard_layout/load_tty_layout.sh

[Install]
WantedBy=graphical.target" >$SETUP_DISK_ROOT_MOUNT/etc/systemd/system/vim-keyboard-layout.service || quit "Failed to create $SETUP_DISK_ROOT_MOUNT/etc/systemd/system"
systemctl enable vim-keyboard-layout || quit "Failed to enable custom keyboard layout"

echo "----------------------------------------"
echo "Securing ssh..."
SETUP_SSH_CONFIG=/etc/ssh/sshd_config.d/sshd_config
mkdir -p $(dirname $SETUP_SSH_CONFIG) || quit "Failed to create directory $SETUP_SSH_CONFIG"
# By default, users within the sudo group can remotely login with ssh
echo "
AllowGroups $SETUP_SUDO_GROUP
Port $SETUP_SSH_PORT
Banner /etc/issue" >$SETUP_SSH_CONFIG || quit "Failed to create the ssh configuration file $SETUP_SSH_CONFIG"
systemctl enable sshd.service || quit "Failed to enable the ssh daemon"

echo "----------------------------------------"
echo "Enabling the firewall..."
ufw enable || quit "Failed to enable the firewall"
ufw allow $SETUP_SSH_PORT || quit "Failed to allow connection through ssh"

if [[ "'$SETUP_HEADLESS'" = "false" ]]; then
    echo "----------------------------------------"
    echo "Installing dwm..."
    SETUP_DWM_SOURCE=/usr/local/src/dwm
    git clone --depth=1 git://git.suckless.org/dwm $SETUP_DWM_SOURCE || quit "Failed to clone dwm"
    cd $SETUP_DWM_SOURCE || quit "Failed to change directory to $SETUP_DWM_SOURCE"
    curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/dwm/config.def.h.patch | patch || quit "Failed to patch dwm"
    make clean install || quit "Failed to build dwm from source"

    echo "----------------------------------------"
    echo "Installing st..."
    SETUP_ST_SOURCE=/usr/local/src/st
    git clone --depth=1 git://git.suckless.org/st $SETUP_ST_SOURCE || quit "Failed to clone st"
    cd $SETUP_ST_SOURCE || quit "Failed to change directory to $SETUP_ST_SOURCE"
    curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/st/config.def.h.patch | patch || quit "Failed to patch st"
    make clean install || quit "Failed to build st from source"

    echo "----------------------------------------"
    echo "Installing a status bar for dwm..."
    SETUP_STATUS_SOURCE=/usr/local/src/dwm-bar
    git clone --depth=1 https://github.com/joestandring/dwm-bar $SETUP_STATUS_SOURCE || quit "Failed to clone dwm-bar"
    cd $SETUP_STATUS_SOURCE || quit "Failed to change directory to $SETUP_STATUS_SOURCE"
    curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/dwm-bar/dwm_bar.sh.patch | patch || quit "Failed to patch dwm-bar"

    echo "----------------------------------------"
    echo "Installing dmenu..."
    SETUP_DMENU_SOURCE=/usr/local/src/dmenu
    git clone --depth=1 git://git.suckless.org/dmenu $SETUP_DMENU_SOURCE || quit "Failed to clone dmenu"
    cd $SETUP_DMENU_SOURCE || quit "Failed to change directory to $SETUP_DMENU_SOURCE"
    curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/dmenu/config.def.h.patch | patch || quit "Failed to patch dmenu"
    make clean install || quit "Failed to build dmenu from source"

    echo "----------------------------------------"
    echo "Installing slock..."
    SETUP_SLOCK_SOURCE=/usr/local/src/slock
    git clone --depth=1 git://git.suckless.org/slock $SETUP_SLOCK_SOURCE || quit "Failed to clone slock"
    cd $SETUP_SLOCK_SOURCE || quit "Failed to change directory to $SETUP_SLOCK_SOURCE"
    curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/slock/config.def.h.patch | patch || quit "Failed to patch slock"
    make clean install || quit "Failed to build slock from source"

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
    echo "Installing neovim..."
    SETUP_NVIM_SOURCE=/usr/local/src/nvim
    mkdir -p $SETUP_NVIM_SOURCE || quit "Failed to create neovim source directory"
    curl -L https://github.com/neovim/neovim/archive/refs/tags/nightly.tar.gz -o $SETUP_NVIM_SOURCE/nightly.tar.gz || quit "Failed to download neovim"
    cd $SETUP_NVIM_SOURCE || quit "Failed to change directory to $SETUP_NVIM_SOURCE"
    tar -xf nightly.tar.gz || quit "Failed to extract neovim"
    cd $SETUP_NVIM_SOURCE/neovim-nightly || quit "Failed to change directory to $SETUP_NVIM_SOURCE/neovim-nightly"
    make CMAKE_BUILD_TYPE=RelWithDebInfo install || quit "Failed to build neovim from source"

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
