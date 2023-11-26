# **Arch Linux Installation Script**

A script that installs Arch Linux with my preferred configuration.

## **Run this script**

**1.** Complete steps 1.1 -> 1.4 in the [Arch Linux Installation Guide](https://wiki.archlinux.org/title/installation_guide).

**2.** (Optional) This script can be configured by setting options. All of these options and their defualt configurations are shown here.

```bash
export SETUP_DIR=~                      # Directory to switch to before doing anything else
export SETUP_PING=1.1.1.1               # IP address or domain name for testing network connectivity
export SETUP_DISK=                      # The disk to install arch linux on (unset by default, an unmounted disk is automatically selected)
export SETUP_DISK_MIN_BYTES=10737418240 # The minimum number of bytes that a disk must have to be automatically selected for installation (default 10 GiB)
export SETUP_TIME_ZONE=America/Denver   # The system time zone
export SETUP_HOSTNAME="arch"            # The system hostname
export SETUP_ROOT_PASSWORD="arch"       # The root password
export SETUP_RESTART_TIME=5             # The timed delay before restarting once installation is complete (set to -1 to exit instead)
```

> **Warning**: If the SETUP_DISK option is unset, the largest available disk is partitioned and formatted. This may result in data being overwritten. Run this script at your own risk!

**3.** Download this script, make it executable, and run it as root.

```bash
curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/setup.sh >setup.sh && chmod +x setup.sh && ./setup.sh
```

## **TODO**

- [X] Partition, format, and mount disks.
- [ ] Install the Linux kernel, core utilities, and a boot loader.
- [ ] Install additional command-line tools and their dependencies (NeoVim, Git, Clang).
- [ ] Ensure proper functionality with UEFI boot mode.
- [ ] Install a display server (possibly Wayland but most likely Xorg).
- [ ] Install a window manager (DWM or another lightweight alternative).
- [ ] Install essential GUI applications (firefox).

