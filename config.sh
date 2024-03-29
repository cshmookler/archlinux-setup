SETUP_PING=1.1.1.1                      # IP address or domain name for testing network connectivity
SETUP_DISK_MIN_BYTES=16000000000        # The minimum number of bytes that a disk must have to be automatically selected for installation (default 16 GB)
# SETUP_DISK=/dev/vda                     # The disk to install Arch Linux on (unset by default, an unmounted disk is automatically selected)
# SETUP_DISK_ROOT=/dev/vda2               # The root partition (unset by default)
# SETUP_DISK_BOOT=/dev/vda1               # The boot partition (unset by default, only applicable to BIOS bootable systems)
# SETUP_DISK_EFI=/dev/vda1                # The EFI partition (unset by default, only applicable to UEFI bootable systems)
SETUP_HEADLESS=false                    # Whether to install a display server and other related software
SETUP_DEVELOPMENT_TOOLS=true            # Whether to install development tools
SETUP_EXTRA_PACKAGES="xf86-video-intel" # Extra packages to install on the system
SETUP_TIME_ZONE=America/Denver          # The system time zone
SETUP_HOSTNAME="arch"                   # The system hostname
SETUP_ROOT_PASSWORD="arch"              # The root password
SETUP_USER="main"                       # The name of the non-root account
SETUP_USER_PASSWORD="main"              # The password for the non-root account
SETUP_SUDO_GROUP="wheel"                # The name of the group with sudo privileges
SETUP_SSH_PORT=22                       # The port for ssh to listen on
SETUP_RESTART_TIME=5                    # The timed delay before restarting once installation is complete (-1 cancels the restart)
