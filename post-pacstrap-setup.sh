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
echo "Sourcing the environment configuration script..."
source /env.sh || quit "Failed to source the environment configuration script at /env.sh"

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
echo "Enabling bluetooth..."
systemctl enable bluetooth.service || quit "Failed to enable bluetooth"

echo "----------------------------------------"
echo "Enabling the firewall..."
systemctl enable ufw.service || quit "Failed to enable the ufw daemon"

echo "----------------------------------------"
echo "Enabling ssh..."
systemctl enable sshd.service || quit "Failed to enable the ssh daemon"

echo "----------------------------------------"
echo "Enabling libvirtd..."
systemctl enable libvirtd.service || quit "Failed to enable the libvirt daemon"

echo "----------------------------------------"
echo "Adding the post-installation script..."
SETUP_POST_INSTALL_SCRIPT=/etc/post_install.sh
echo "ufw enable
ufw limit $SETUP_SSH_PORT comment 'ssh'
ufw allow 51413 comment 'transmission-cli'
localectl --no-convert set-keymap us_vim
localectl --no-convert set-x11-keymap us_vim
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
echo "Creating sudo group \"$SETUP_SUDO_GROUP\""
groupadd -f $SETUP_SUDO_GROUP || quit "Failed to create group \"$SETUP_SUDO_GROUP\""

echo "----------------------------------------"
echo "Creating user \"$SETUP_USER\"..."
useradd -mU $SETUP_USER || quit "Failed to create the user \"$SETUP_USER\""
usermod --password $(openssl passwd -1 "$SETUP_USER_PASSWORD") $SETUP_USER || quit "Failed to set the password for \"$SETUP_USER\""

echo "----------------------------------------"
echo "Installing AUR and custom packages..."
cd /tmp || quit "Failed to change directory to /tmp"
echo "%$SETUP_USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo EDITOR="tee -a" visudo || quit "Failed to temporarily give passwordless sudo privileges to user \"$SETUP_USER\""
git clone https://github.com/cshmookler/archlinux-setup || quit "Failed to download custom packages"
cd archlinux-setup || quit "Failed to change directory to archlinux-setup"
cp -f .bashrc /home/$SETUP_USER/
git clone https://aur.archlinux.org/yay.git || redtext "Failed to clone yay from the Arch Linux AUR"
chown -R $SETUP_USER:$SETUP_USER . || quit "Failed to change directory permissions of archlinux-setup to $SETUP_USER:$SETUP_USER"
SETUP_INSTALLPKG_FUNC='installpkg() {
    cd "$2" || return 1
    if ! sudo -u "$1" makepkg --install --syncdeps --noconfirm; then
        cd .. || return 2
        return 3
    fi
    cd .. || return 4
}'
eval "$SETUP_INSTALLPKG_FUNC" || quit "Failed to source the package installation script"
if test "$SETUP_BOOT_MODE" = "UEFI-32" -o "$SETUP_BOOT_MODE" = "UEFI-64"; then
    installpkg $SETUP_USER cgs-limine-uefi || quit "Failed to install cgs-limine-uefi (exit code: $?)"
elif test "$SETUP_BOOT_MODE" = "BIOS"; then
    installpkg $SETUP_USER  cgs-limine-bios || quit "Failed to install cgs-limine-bios (exit code: $?)"
else
    quit "Invalid boot mode \"$SETUP_BOOT_MODE\""
fi
installpkg $SETUP_USER yay || redtext "Failed to install yay (exit code: $?)"
installpkg $SETUP_USER cgs-vim-keyboard-layout || redtext "Failed to install cgs-vim-keyboard-layout (exit code: $?)"
installpkg $SETUP_USER cgs-ssh-cfg || redtext "Failed to install cgs-ssh-cfg (exit code: $?)"
if test "$SETUP_HEADLESS" = "false"; then
    installpkg $SETUP_USER cgs-xorg-cfg || redtext "Failed to install cgs-xorg-cfg (exit code: $?)"
    installpkg $SETUP_USER cgs-font-prefs || redtext "Failed to install cgs-font-prefs (exit code: $?)"
    installpkg $SETUP_USER cgs-slock || redtext "Failed to install cgs-slock (exit code: $?)"
    installpkg $SETUP_USER cgs-st || redtext "Failed to install cgs-st (exit code: $?)"
    installpkg $SETUP_USER cgs-status-bar || redtext "Failed to install cgs-slstatus (exit code: $?)"
    installpkg $SETUP_USER cgs-special-keys || redtext "Failed to install cgs-special-keys (exit code: $?)"
    installpkg $SETUP_USER cgs-dmenu || redtext "Failed to install cgs-dmenu (exit code: $?)"
    installpkg $SETUP_USER cgs-dwm || redtext "Failed to install cgs-dwm (exit code: $?)"
    installpkg $SETUP_USER cgs-snap || redtext "Failed to install cgs-snap (exit code: $?)"
fi
if test "$SETUP_DEVELOPMENT_TOOLS" = "true"; then
    installpkg $SETUP_USER cgs-neovim-nightly || redtext "Failed to install cgs-neovim-nightly (exit code: $?)"
    installpkg $SETUP_USER cgs-xor-crypt || redtext "Failed to install cgs-xor-crypt (exit code: $?)"
    sudo -u $SETUP_USER yay -Sy --noconfirm jdtls || redtext "Failed to install jdtls (exit code: $?)"
    # sudo -u $SETUP_USER yay -Sy --noconfirm swift-mesonlsp || redtext "Failed to install swift-mesonlsp (exit code: $?)"
fi
sudo -u $SETUP_USER bash -ue user-cfg/user-cfg-base.sh || redtext "Failed to configure user \"$SETUP_USER\""
if test "$SETUP_HEADLESS" = "false"; then
    sudo -u $SETUP_USER bash -ue user-cfg/user-cfg-x.sh || redtext "Failed to configure the X server for user \"$SETUP_USER\""
fi
if test "$SETUP_DEVELOPMENT_TOOLS" = "true"; then
    sudo -u $SETUP_USER bash -ue user-cfg/user-cfg-dev-tools.sh || redtext "Failed to configure dev tools for user \"$SETUP_USER\""
fi
if ! test -f /bin/vim; then
    # Install vim if it or an alternative hasn't already been installed.
    pacman -Sy --needed --noconfirm vim || redtext "Failed to install vim"
fi
EDITOR="sed -i '$ d'" visudo || quit "Failed to remove sudo privileges from user \"$SETUP_USER\""

echo "----------------------------------------"
echo "Giving the user \"$SETUP_USER\" root privileges..."
echo "
## Allow members of group $SETUP_SUDO_GROUP to execute any command
%$SETUP_SUDO_GROUP ALL=(ALL:ALL) ALL" | sudo EDITOR="tee -a" visudo || quit "Failed to give sudo privileges to the \"$SETUP_SUDO_GROUP\" group"
usermod -aG $SETUP_SUDO_GROUP $SETUP_USER || quit "Failed to give sudo privileges to user \"$SETUP_USER\""

echo "----------------------------------------"
echo "Permitting the user \"$SETUP_USER\" to use KVM..."
usermod -aG libvirt $SETUP_USER || quit "Failed to add user \"$SETUP_USER\" to the \"libvirt\" group"
echo "
# Allow users in the group \"libvirt\" to use KVM
unix_sock_group = \"libvirt\"
uix_sock_rw_perms = \"0770\"
" >>/etc/libvirt/libvirt.conf || quit "Failed to alow users in the \"libvirt\" group to use KVM"

echo "----------------------------------------"
echo "Switching ssh to port $SETUP_SSH_PORT and only allowing remote login by users within the group \"$SETUP_SUDO_GROUP\""
echo "AllowGroups $SETUP_SUDO_GROUP
Port $SETUP_SSH_PORT" >/etc/ssh/sshd_config.d/20-access.conf

echo "----------------------------------------"
echo "Changing ownership of all files in /home/$SETUP_USER from root to user \"$SETUP_USER\"..."
chown -R $SETUP_USER:$SETUP_USER /home/$SETUP_USER || quit "Failed to change ownership of files in /home/$SETUP_USER from root to user \"$SETUP_USER\"..."

exit 0
