# Nixflix Media Server Setup & Installation Guide

This directory (`hosts/mediaserver/`) configures a dedicated headless media and storage server tailored for an **AMD Ryzen 7 5700G (Radeon Vega iGPU)** with 16GB RAM.

______________________________________________________________________

## What Is Configured

1. **Storage & Local Network Sharing (\[storage.nix\](file:///home/zeejay/Projects/zj-nixflix/hosts/mediaserver/storage.nix))**:

   - Attached drive mount at `/data` with `nofail` (won't hang boot if unmounted).
   - **Samba (SMB)** file sharing allowing Windows, Mac, and Linux systems on your local network (`192.168.4.0/22`) to access:
     - `\\mediaserver\Media` (Public read/write access to movies, tv, music).
     - `\\mediaserver\Downloads` (Public read/write access to torrent/usenet downloads).
     - `\\mediaserver\SharedDrive` (Full disk access for `admin` user).
   - **WS-Discovery (`samba-wsdd`)**: Automatically advertises the server so it appears in Windows Explorer under "Network".

1. **Remote Desktop & Headless Management (\[remote-desktop.nix\](file:///home/zeejay/Projects/zj-nixflix/hosts/mediaserver/remote-desktop.nix))**:

   - **SSH**: Remote CLI access (`ssh admin@<ip>`).
   - **Lightweight Desktop (XFCE)**: Low resource consumption (~350MB RAM).
   - **XRDP (Windows Remote Desktop)**: Native RDP server. On any Windows PC, open **Remote Desktop Connection** (`mstsc`), enter the server's IP, and log in. Spawns its own virtual display session on demand.
   - **RustDesk**: Client daemon running as a systemd service, auto-starts on boot with firewall ports open (`21115-21119`).
   - **Virtual Dummy Display**: X11 dummy video driver configured for 1080p in software so graphical sessions work with zero physical monitors attached. *(If you plug in an inexpensive HDMI dummy plug instead, you can comment out the `videoDrivers = [ "dummy" ]` block to use AMD GPU rendering).*

1. **Media Stack & AMD GPU Acceleration (\[media.nix\](file:///home/zeejay/Projects/zj-nixflix/hosts/mediaserver/media.nix))**:

   - AMD VA-API hardware transcoding enabled on the Ryzen 5700G Radeon Vega GPU (`/dev/dri/renderD128`).
   - **Jellyfin**: Media streaming server with automated libraries.
   - **Seerr**: Media request dashboard.
   - **Sonarr & Radarr**: TV and movie download managers.
   - **Prowlarr**: Indexer management.
   - **qBittorrent**: Torrent download client.
   - **Caddy Reverse Proxy**: Serves apps at `http://<service>.nixflix.local` (or direct ports like `:8096`, `:5055`, `:8989`, etc.).

1. **Secrets & Passwords (\[secrets.nix\](file:///home/zeejay/Projects/zj-nixflix/hosts/mediaserver/secrets.nix))**:

   - Initial passwords and API keys. Change these to your own secure passwords.

______________________________________________________________________

## Step-by-Step Installation on the Target PC

### Step 1: Boot into the NixOS Live Installer

1. Download the NixOS ISO from [nixos.org](https://nixos.org) and flash it onto a USB drive (e.g. with Rufus or Ventoy).
1. Plug the USB and ethernet cable into the target PC, power on, and boot into the USB installer.

### Step 2: Partition & Mount Disks

Assuming your OS drive is `/dev/nvme0n1` (adjust to `/dev/sda` if SATA SSD):

```bash
# 1. Create GPT partition table
parted /dev/nvme0n1 -- mklabel gpt

# 2. Create 1GB EFI boot partition
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1024MiB
parted /dev/nvme0n1 -- set 1 esp on

# 3. Create Root partition using the rest of the disk
parted /dev/nvme0n1 -- mkpart primary 1024MiB 100%

# 4. Format partitions
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2

# 5. Mount root and boot
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

If you already have your attached storage drive connected (e.g. formatted as ext4 with label `data`):

```bash
# Check drive labels & UUIDs
lsblk -f

# (Optional) If formatting a new storage drive as ext4:
# mkfs.ext4 -L data /dev/sdb1

mkdir -p /mnt/data
mount /dev/disk/by-label/data /mnt/data
```

### Step 3: Generate Hardware Config & Clone Repo

```bash
# Generate the machine's exact hardware scan
nixos-generate-config --root /mnt

# Clone this repo into the target system
git clone https://github.com/Zackyization/zj-nixflix.git /mnt/etc/nixos/zj-nixflix

# Overwrite the hardware configuration stub with the real detected hardware
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/zj-nixflix/hosts/mediaserver/hardware-configuration.nix

cd /mnt/etc/nixos/zj-nixflix
git add -A
```

### Step 4: Install NixOS

```bash
nixos-install --flake .#mediaserver
```

When prompted, set a password for the `root` user.

### Step 5: Reboot & Remote Connect

1. Remove the USB drive and reboot:

   ```bash
   reboot
   ```

1. Unplug any monitor if you want it to run headless.

1. Check your router or scan your LAN (`192.168.4.x`) to find the server's IP address.

1. **Connect via SSH**:

   ```bash
   ssh admin@<IP-ADDRESS>
   # Default password: admin
   ```

   *Immediately change the password by running `passwd`.*

1. **Connect via Remote Desktop**:

   - **Option A (Windows RDP)**: Press `Win + R`, type `mstsc`, enter the server IP `<IP-ADDRESS>`, and log in with username `admin`.
   - **Option B (RustDesk)**: Open RustDesk on your PC and connect using the server's RustDesk ID.

1. **Access Shared Network Drives**:

   - In Windows File Explorer, navigate to:
     `\\<IP-ADDRESS>\Media` or `\\mediaserver\Media`
     `\\<IP-ADDRESS>\SharedDrive` (log in with `admin`)
