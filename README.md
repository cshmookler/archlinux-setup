# **Arch Linux Installation Script**

A script that installs Arch Linux with my preferred configuration.

## **Run this script**

**1.** Complete steps 1.1 -> 1.4 in the [Arch Linux Installation Guide](https://wiki.archlinux.org/title/installation_guide).

**2.** (Optional) This script can be configured by setting options. All of these options and their defualt configurations are shown here.

```bash
export SETUP_DIR=~                      # Directory to switch to before doing anything else
export SETUP_PING=1.1.1.1               # IP address or domain name for testing network connectivity
export SETUP_DISK=                      # The disk to install arch linux on (unset by default, an unmounted disk is automatically selected)
export SETUP_DISK_MIN_BYTES=16000000000 # The minimum number of bytes that a disk must have to be automatically selected for installation (default 16 GB)
export SETUP_HEADLESS=false             # Whether to install a display server and other related software
export SETUP_DEVELOPMENT_TOOLS=true     # Whether to install development tools
export SETUP_EXTRA_PACKAGES=""          # Extra packages to install on the system
export SETUP_TIME_ZONE=America/Denver   # The system time zone
export SETUP_HOSTNAME="arch"            # The system hostname
export SETUP_ROOT_PASSWORD="arch"       # The root password
export SETUP_USER="main"                # The name of the non-root account
export SETUP_USER_PASSWORD="main"       # The password for the non-root account
export SETUP_SUDO_GROUP="wheel"         # The name of the group with sudo privileges
export SETUP_SSH_PORT=22                # The port for ssh to listen on
export SETUP_RESTART_TIME=10            # The timed delay before restarting once installation is complete (-1 cancels the restart)
```

> **Warning**: If the SETUP_DISK option is unset, the largest available disk is partitioned and formatted. This may result in data being overwritten. Run this script at your own risk!

**3.** Download this script and run it as root with bash.

```bash
curl -O https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/setup.sh && bash setup.sh
```

## **TODO**

- [X] Partition, format, and mount disks.
- [X] Install the Linux kernel, core utilities, and a boot loader.
- [X] Install additional command-line tools and their dependencies (NeoVim, Git, Clang).
- [X] Fix fsck issue during boot.
- [X] Ensure proper functionality with UEFI boot mode.
- [X] Install a display server (possibly Wayland but most likely Xorg).
- [X] Install a window manager (DWM or another lightweight alternative).
- [X] Automatic screen locking and suspending.
- [X] Install essential GUI applications (firefox).
- [X] Replace dwm-bar with cgs-slstatus.
- [X] Separate each component into its own package.
- [X] Allow optional components of the installation to fail without stopping the installation.
- [X] Package the custom neovim configuration into its own package.
- [ ] Plug OpenVPN dns leak.
- [ ] Automatically install browser extensions.
