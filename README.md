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
```

**3.** Download this script, make it executable, and run it as root.

```bash
curl https://raw.githubusercontent.com/cshmookler/archlinux-setup/main/setup.sh >setup.sh && chmod +x setup.sh && ./setup.sh
```

## **TODO**

- [ ] Partition disks
- [ ] Install the Linux kernel, core utilities, and a boot loader.
- [ ] Install additional command-line tools and their dependencies (NeoVim, Git, Clang).
- [ ] Install a display server (possibly Wayland but most likely Xorg).
- [ ] Install a window manager (DWM or another lightweight alternative).
- [ ] Install essential GUI applications (firefox).

