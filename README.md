# **Arch Linux Installation Script**

A script that installs Arch Linux with my preferred configuration.

## **Run this script**

**1.** Complete steps 1.1 -> 1.4 in the [Arch Linux Installation Guide](https://wiki.archlinux.org/title/installation_guide).

**2.** Download this script, make it executable, and run it as root.
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

