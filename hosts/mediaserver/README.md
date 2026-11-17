# Nixflix Media Server Setup & Installation Guide (`garciamedia`)

This directory (`hosts/mediaserver/`) configures the **`garciamedia`** NixOS host (`nixosConfigurations.garciamedia` in [flake.nix](../../flake.nix)): a media, storage, and remote-capable desktop/server setup tailored for an **AMD Ryzen 7 5700G (Radeon Vega iGPU)** with 16GB RAM.

---

## What Is Configured

1. **System & Development Tools ([default.nix](default.nix))**:
   - Hostname: `garciamedia`, user `admin` (initial password: `zildjian`, passwordless `sudo`).
   - Flakes & `nix-command` enabled, `nixpkgs.config.allowUnfree = true`, and `programs.nix-ld.enable = true`.
   - Editors & tooling: **VS Code** (`vscode.fhs`), **Antigravity IDE** (`antigravity-ide-fhs`), `git`, `gh`, `nixd`, `nixfmt`.

2. **Storage & Local Network Sharing ([storage.nix](storage.nix))**:
   - Attached drive mount at `/data` (`/dev/disk/by-label/data`, `nofail` so boot succeeds even if unmounted).
   - **Samba (SMB)** file sharing on your local network (`192.168.4.0/22` / `192.168.0.0/16`):
     - `\\garciamedia\Media` (public read/write access to movies, tv, music).
     - `\\garciamedia\Downloads` (public read/write access to downloads).
     - `\\garciamedia\SharedDrive` (full `/data` access for `admin`).
   - **WS-Discovery (`samba-wsdd`)**: Advertises `garciamedia` under Windows Explorer "Network".

3. **Remote Desktop & Display Modes ([remote-desktop.nix](remote-desktop.nix))**:
   - **SSH**: Remote CLI & VS Code Remote-SSH access (`ssh admin@<ip>`).
   - **XFCE + LightDM**: Lightweight desktop environment with `admin` auto-login.
   - **XRDP (Windows Remote Desktop)**: Connect with Windows **Remote Desktop Connection** (`mstsc`) as `admin`. Spawns its own virtual X11 session on demand (works in both physical monitor and headless modes).
   - **RustDesk**: Daemon + tray autostart with firewall ports open (`21115-21119` TCP, `21116` UDP).
   - **Dual Display Modes (`specialisation.headless`)**: Physical monitor output by default, plus an on-demand `headless` virtual 1080p `dummy` display specialisation (see [Switching Between Physical Monitor and Virtual Display](#switching-between-physical-monitor-and-virtual-display)).

4. **Media Stack & AMD GPU Acceleration ([media.nix](media.nix))**:
   - AMD VA-API hardware transcoding support (`hardware.graphics`, `jellyfin` in `video`/`render` groups).
   - **Jellyfin**, **Seerr**, **Sonarr**, **Radarr**, **Prowlarr**, **qBittorrent**, **PostgreSQL**, and **Caddy** (`http://<service>.nixflix.local` and direct ports `:8096`, `:5055`, `:8989`, `:7878`, `:9696`, `:8282`).

5. **Secrets & Passwords ([secrets.nix](secrets.nix))**:
   - Initial API keys and service web passwords (default `"zildjian"`). Change these before exposing anything outside your LAN.

---

## Switching Between Physical Monitor and Virtual Display

`garciamedia` supports two X11 display modes via a NixOS `specialisation`:

| Mode | When to use | How X11 / Remote Desktop behaves |
| --- | --- | --- |
| **Physical Monitor** *(default)* | Monitor plugged into the PC | XFCE renders on your physical display. **XRDP (`mstsc`)** still spawns virtual sessions on demand. |
| **Virtual Display (`headless`)** | No monitor plugged in (for **RustDesk** capture on `:0`) | Uses the Xorg `dummy` driver (`1920x1080` in RAM). Physical monitor outputs will not display LightDM/XFCE while active. |

> [!NOTE]
> Switching modes restarts `display-manager.service`, which logs out/restarts the local graphical `:0` session.

### Switch TO the Virtual Dummy Display (`headless`)
- **Live (without rebooting):**
  ```bash
  sudo /nix/var/nix/profiles/system/specialisation/headless/bin/switch-to-configuration switch
  ```
- **At boot:** Select the **`headless`** entry in the `systemd-boot` menu.

### Switch BACK to the Physical Monitor (default)
- **Live (without rebooting or rebuilding):**
  ```bash
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  ```
- **Or by rebuilding the default flake target:**
  ```bash
  sudo nixos-rebuild switch --flake /etc/nixos/zj-nixflix#garciamedia
  ```
- **At boot:** Reboot and select the default (`garciamedia`) boot entry.

---

## Installation Option A: Existing Blank NixOS Installation (Recommended if NixOS is already installed)

1. **Inspect `/etc/nixos/configuration.nix`** on the target PC before switching:
   - Check whether your installer used `systemd-boot` (UEFI) or `grub` (BIOS), and note your `system.stateVersion`.
   - If different from [default.nix](default.nix), update `boot.loader.*` and `system.stateVersion` after cloning.

2. **Clone this repository into `/etc/nixos/zj-nixflix`**:
   ```bash
   sudo git clone https://github.com/Zackyization/zj-nixflix.git /etc/nixos/zj-nixflix
   sudo chown -R $USER:users /etc/nixos/zj-nixflix
   ```

3. **Copy your generated hardware configuration**:
   ```bash
   cp /etc/nixos/hardware-configuration.nix /etc/nixos/zj-nixflix/hosts/mediaserver/hardware-configuration.nix
   ```
   *(If you have a separate media drive, check `lsblk -f` and make sure it is ext4-formatted with label `data`, or update [storage.nix](storage.nix) to use its UUID.)*

4. **Stage files and switch to the flake**:
   ```bash
   cd /etc/nixos/zj-nixflix
   git add -A
   sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#garciamedia
   ```

5. **Reboot and set `admin` ownership for remote editing**:
   ```bash
   sudo reboot
   ```
   After logging in as `admin` (password: `zildjian`), run:
   ```bash
   sudo chown -R admin:users /etc/nixos/zj-nixflix
   ```

---

## Installation Option B: Fresh Install from NixOS Live USB

### Step 1: Boot into the NixOS Live Installer
1. Download the NixOS ISO from [nixos.org](https://nixos.org) and flash it onto a USB drive (e.g. with Rufus or Ventoy).
2. Plug the USB and ethernet cable into the target PC, power on, and boot into the USB installer (UEFI mode).

### Step 2: Partition & Mount Disks
Assuming your OS drive is `/dev/nvme0n1` (adjust to `/dev/sda` if SATA SSD):

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1024MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 1024MiB 100%

mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

If you have a separate storage drive (formatted as `ext4` with label `data`):

```bash
lsblk -f
# Optional for a new drive: mkfs.ext4 -L data /dev/sdb1
mkdir -p /mnt/data
mount /dev/disk/by-label/data /mnt/data
```

### Step 3: Generate Hardware Config & Clone Repo
```bash
nixos-generate-config --root /mnt
git clone https://github.com/Zackyization/zj-nixflix.git /mnt/etc/nixos/zj-nixflix
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/zj-nixflix/hosts/mediaserver/hardware-configuration.nix

cd /mnt/etc/nixos/zj-nixflix
git add -A
```

### Step 4: Install NixOS
```bash
nixos-install --flake .#garciamedia
```
When prompted, set a password for `root`, then `reboot` and remove the USB drive.

---

## Connecting & Editing Remotely

1. **SSH:**
   ```bash
   ssh admin@<IP-ADDRESS>
   # Initial password: zildjian
   ```
   *(Change your Linux password with `passwd`.)*

2. **Remote Desktop:**
   - **Windows RDP (`mstsc`):** Connect to `<IP-ADDRESS>` with username `admin` (always creates a virtual session, even in physical monitor mode).
   - **RustDesk:** Connect using the server's RustDesk ID (switch to the `headless` specialisation if no monitor is plugged in).

3. **VS Code & Antigravity IDE:**
   - **Inside RDP / RustDesk:** Launch `antigravity` or `code /etc/nixos/zj-nixflix`.
   - **Via Remote-SSH:** Connect from another computer to `admin@garciamedia` (or `admin@<IP-ADDRESS>`) and open `/etc/nixos/zj-nixflix`.
   - **Apply configuration changes:**
     ```bash
     cd /etc/nixos/zj-nixflix
     git add -A
     sudo nixos-rebuild switch --flake .#garciamedia
     ```

4. **Shared Network Drives (SMB):**
   - `\\<IP-ADDRESS>\Media` or `\\garciamedia\Media`
   - `\\<IP-ADDRESS>\Downloads` or `\\garciamedia\Downloads`
   - `\\<IP-ADDRESS>\SharedDrive` (log in as `admin`)
