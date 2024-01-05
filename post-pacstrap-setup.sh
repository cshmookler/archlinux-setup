#!/bin/bash

yellowtext() {
    echo -e "\e[33;1m$1\e[0m"
}

redtext() {
    echo -e "\e[31;1m$1\e[0m"
}

quit() {
    redtext "$1"
    exit 1
}

echo "----------------------------------------"
echo "Setting time zone: $SETUP_TIME_ZONE"
ln -sf /usr/share/zoneinfo/$SETUP_TIME_ZONE /etc/localtime || quit "Failed to set time zone: $SETUP_TIME_ZONE"

echo "----------------------------------------"
echo "Setting the hardware clock..."
hwclock --systohc || quit "Failed to set the hardware clock"

echo "----------------------------------------"
echo "Generating locales..."
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen || quit "Failed to set locales"
echo "LANG=en_US.UTF-8" >/etc/locale.conf || quit "Failed to generate locale configuration file"
locale-gen || quit "Failed to generate locales"

echo "----------------------------------------"
echo "Setting hostname: $SETUP_HOSTNAME"
echo "$SETUP_HOSTNAME" >/etc/hostname || quit "Failed to set hostname: $SETUP_HOSTNAME"

echo "----------------------------------------"
echo "Enabling automatic network configuration..."
systemctl enable NetworkManager || quit "Failed to enable networking"

echo "----------------------------------------"
echo "Enabling the firewall..."
systemctl enable ufw.service || quit "Failed to enable the ufw daemon"

echo "----------------------------------------"
echo "Enabling ssh..."
systemctl enable sshd.service || quit "Failed to enable the ssh daemon"

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
ExecStart=/bin/bash -c 'source $SETUP_POST_INSTALL_SCRIPT'

[Install]
WantedBy=graphical.target" >/etc/systemd/system/post-install.service || quit "Failed to create /etc/systemd/system/post-install.service"
systemctl enable post-install.service || quit "Failed to enable the post installation script"

echo "----------------------------------------"
echo "Setting the root password..."
usermod --password $(openssl passwd -1 $SETUP_ROOT_PASSWORD) root || quit "Failed to set the root password"

echo "----------------------------------------"
echo "Installing custom packages..."
cd /tmp || quit "Failed to change directory to /tmp"
git clone https://github.com/cshmookler/archlinux-setup || quit "Failed to download custom packages"
cd archlinux-setup || quit "Failed to change directory to archlinux-setup"
chown -R nobody:nobody . || quit "Failed to change directory permissions of archlinux-setup to nobody:nobody"
echo "%nobody ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo || quit "Failed to temporarily give sudo privileges to user \"nobody\""
SETUP_INSTALLPKG_FUNC='installpkg() {
    cd "$1" || return 1
    sudo -u nobody makepkg --install --syncdeps --noconfirm || cd .. ; return 2
    cd .. || return 3
}'
eval "$SETUP_INSTALLPKG_FUNC" || quit "Failed to source the package installation script"
if test "$SETUP_BOOT_MODE" = "UEFI-32" -o "$SETUP_BOOT_MODE" = "UEFI-64"; then
    installpkg cgs-limine-uefi || quit "Failed to install cgs-limine-uefi"
elif test "$SETUP_BOOT_MODE" = "BIOS"; then
    installpkg cgs-limine-bios || quit "Failed to install cgs-limine-bios"
else
    quit "Invalid boot mode \"$SETUP_BOOT_MODE\""
fi
installpkg cgs-vim-keyboard-layout || redtext "Failed to install cgs-vim-keyboard-layout"
installpkg cgs-ssh-cfg || redtext "Failed to install cgs-ssh-cfg"
if test "$SETUP_HEADLESS" = "false"; then
    installpkg cgs-xorg-cfg || redtext "Failed to install cgs-xorg-cfg"
    installpkg cgs-slock || redtext "Failed to install cgs-slock"
    installpkg cgs-st || redtext "Failed to install cgs-st"
    installpkg cgs-slstatus || redtext "Failed to install cgs-slstatus"
    installpkg cgs-dwm || redtext "Failed to install cgs-dwm"
fi
if test "$SETUP_DEVELOPMENT_TOOLS" = "true"; then
    if ! installpkg cgs-neovim-nightly; then
        redtext "Failed to install cgs-neovim-nightly"
        pacman -Sy vim
    fi
else
    pacman -Sy vim
fi
EDITOR="vim -c \":$ | delete 1 | wq\!\"" visudo || quit "Failed to remove sudo privileges to user \"nobody\""

echo "----------------------------------------"
echo "Creating user \"$SETUP_USER\"..."
groupadd $SETUP_USER || quit "Failed to create group \"$SETUP_USER\""
useradd -mg $SETUP_USER $SETUP_USER || quit "Failed to create the user \"$SETUP_USER\""
usermod --password $(openssl passwd -1 "$SETUP_USER_PASSWORD") $SETUP_USER || quit "Failed to set the password for \"$SETUP_USER\""
if test "$SETUP_HEADLESS" = "false"; then
    sudo -u main bash -c 'eval '"$SETUP_INSTALLPKG_FUNC"' ; installpkg cgs-xorg-user-cfg ; exit $?' || redtext "Failed to install cgs-xorg-user-cfg"
    sudo -u main bash -c "eval $SETUP_INSTALLPKG_FUNC ; installpkg cgs-tor-browser-user-cfg ; exit '$?'" || redtext "Failed to install cgs-tor-browser-user-cfg"
    echo '
# Start the X server on login
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    startx
fi
' >>/home/$SETUP_USER/.bash_profile || quit "Failed to enable starting the X server upon login"
fi
if test "$SETUP_DEVELOPMENT_TOOLS" = "true"; then
    echo "----------------------------------------"
#     echo "Downloading the custom neovim configuration for user \"$SETUP_USER\"..."
#     git clone --depth=1 https://github.com/cshmookler/config.nvim /home/$SETUP_USER/.config/nvim || quit "Failed to download the custom neovim configuration for user \"$SETUP_USER\""

#     echo "----------------------------------------"
#     echo "Generating dictionary for neovim..."
#     mkdir -p /etc/xdg/nvim/ || quit "Failed to create /etc/xdg/nvim/"
#     aspell -d en dump master | aspell -l en expand >/etc/xdg/nvim/en.dict || quit "Failed generate the dictionary for neovim"
fi

echo "----------------------------------------"
echo "Giving the user \"$SETUP_USER\" root privileges..."
echo "%$SETUP_SUDO_GROUP ALL=(ALL:ALL) ALL" | sudo EDITOR="tee -a" visudo || quit "Failed to give sudo privileges to the \"$SETUP_SUDO_GROUP\" group"
usermod -aG $SETUP_SUDO_GROUP $SETUP_USER || quit "Failed to give sudo privileges to user \"$SETUP_USER\""

echo "----------------------------------------"
echo "Changing ownership of all files in /home/$SETUP_USER from root to user \"$SETUP_USER\"..."
chown -R $SETUP_USER:$SETUP_USER /home/$SETUP_USER || quit "Failed to change ownership of files in /home/$SETUP_USER from root to user \"$SETUP_USER\"..."

exit 0
