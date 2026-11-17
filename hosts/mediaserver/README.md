# Nixflix Media Server Setup & Installation Guide (`garciamedia`)

This directory (`hosts/mediaserver/`) configures the **`garciamedia`** NixOS host (`nixosConfigurations.garciamedia` in [flake.nix](../../flake.nix)): a media, storage, and remote-capable desktop/server setup tailored for an **AMD Ryzen 7 5700G (Radeon Vega iGPU)** with 16GB RAM.

---

## What Is Configured

1. **System & Development Tools ([default.nix](default.nix))**:
   - Hostname: `garciamedia`, user `garciamedia` (initial password: `zildjian`, passwordless `sudo`).
   - Flakes & `nix-command` enabled, `nixpkgs.config.allowUnfree = true`, and `programs.nix-ld.enable = true`.
   - Editors & tooling: **VS Code** (`vscode.fhs`), **Antigravity IDE** (`antigravity-ide-fhs`), `git`, `gh`, `nixd`, `nixfmt`.

2. **Storage & Local Network Sharing ([storage.nix](storage.nix))**:
   - `/data` (`/data/media`, `/data/downloads`, `/data/.state`) lives on the NVMe root partition.
   - Your existing SATA/USB drives are mounted non-destructively by UUID under `/mnt/drives/` (`ZeeJay_640G`, `Windows`, `DESK_1TB`, `LinuxData`) with `nofail` and a 5s device timeout.
   - **Samba (SMB)** file sharing on your local network (`192.168.4.0/22` / `192.168.0.0/16`):
     - `\\garciamedia\Media` (guest read/write access to `/data/media`).
     - `\\garciamedia\Downloads` (guest read/write access to `/data/downloads`).
     - `\\garciamedia\SharedDrive`, `\\garciamedia\ZeeJay_640G`, `\\garciamedia\Windows`, `\\garciamedia\DESK_1TB`, `\\garciamedia\LinuxData` (protected; log in as `garciamedia` after setting your SMB password with `sudo smbpasswd -a garciamedia`).
   - **WS-Discovery (`samba-wsdd`) & Avahi (`mDNS`)**: Advertises `garciamedia` to Windows Explorer ("Network") and `garciamedia.local` to macOS Finder / Linux file managers.

3. **Remote Desktop & Display Modes ([remote-desktop.nix](remote-desktop.nix))**:
   - **SSH**: Remote CLI & VS Code Remote-SSH access (`ssh garciamedia@<ip>`).
   - **XFCE + LightDM**: Lightweight desktop environment with `garciamedia` auto-login.
   - **XRDP (Windows Remote Desktop)**: Connect with Windows **Remote Desktop Connection** (`mstsc`) as `garciamedia`. Spawns its own virtual X11 session on demand (works in both physical monitor and headless modes).
   - **RustDesk**: Daemon + tray autostart with firewall ports open (`21115-21119` TCP, `21116` UDP).
   - **Dual Display Modes (`specialisation.headless`)**: Physical monitor output by default, plus an on-demand `headless` virtual 1080p `dummy` display specialisation (see [Switching Between Physical Monitor and Virtual Display](#switching-between-physical-monitor-and-virtual-display)).

4. **Media Stack & AMD GPU Acceleration ([media.nix](media.nix))**:
   - AMD VA-API hardware transcoding support (`hardware.graphics`, `jellyfin` in `video`/`render` groups).
   - **Jellyfin**, **Seerr**, **Sonarr**, **Radarr**, **Prowlarr**, **qBittorrent**, **PostgreSQL**, and **Caddy** (`http://<service>.nixflix.local` and direct ports `:8096`, `:5055`, `:8989`, `:7878`, `:9696`, `:8282`).

5. **Secrets & Passwords ([secrets.nix](secrets.nix))**:
   - Initial API keys and service web passwords (default `"zildjian"` — Jellyfin web login user is `admin`). Change these before exposing anything outside your LAN.

---

## Services, Ports & Network Access Reference (IP: `192.168.4.41`)

### 1. Web UIs & Media Services

Access these directly from any browser or client app on your local network:

| Service | Port | Direct IP Address | Local Hostname Address | Default Username | Default Password | Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Jellyfin** | `8096` | `http://192.168.4.41:8096` | `http://garciamedia.local:8096` | `admin` | `zildjian` | Media streaming (TV, Movies, Music) |
| **Seerr** | `5055` | `http://192.168.4.41:5055` | `http://garciamedia.local:5055` | *(Sign in with Jellyfin)* | `zildjian` | Media discovery & request manager |
| **Sonarr** | `8989` | `http://192.168.4.41:8989` | `http://garciamedia.local:8989` | `sonarr` | `zildjian` | TV series automation & manager |
| **Radarr** | `7878` | `http://192.168.4.41:7878` | `http://garciamedia.local:7878` | `radarr` | `zildjian` | Movie automation & manager |
| **Prowlarr** | `9696` | `http://192.168.4.41:9696` | `http://garciamedia.local:9696` | `prowlarr` | `zildjian` | Torrent & Usenet indexer manager |
| **qBittorrent** | `8282` | `http://192.168.4.41:8282` | `http://garciamedia.local:8282` | `admin` | `zildjian` | BitTorrent download client WebUI |

> [!TIP]
> Devices that support mDNS/Bonjour (iOS, iPadOS, macOS, Android, and Windows with mDNS) can reach these services using `http://garciamedia.local:<port>` as well as `http://192.168.4.41:<port>`.

### 2. Network Hard Drive Shares (Samba / SMB)

Connect from another computer to browse or transfer files:
- **Windows**: Press `Win + R` and type `\\192.168.4.41` (or `\\garciamedia`)
- **macOS / Linux**: In Finder, press `Cmd + K` and enter `smb://192.168.4.41` (or `smb://garciamedia.local`)

| Share Name | Physical Location | Access Level | Login Credentials |
| :--- | :--- | :--- | :--- |
| **`Media`** | `/data/media` *(NVMe)* | **Public (Guest)** | None required |
| **`Downloads`** | `/data/downloads` *(NVMe)* | **Public (Guest)** | None required |
| **`SharedDrive`** | `/data` *(NVMe Root)* | Authenticated | `garciamedia` / `zildjian` |
| **`ZeeJay_640G`** | `/mnt/drives/ZeeJay_640G` *(sda1)* | Authenticated | `garciamedia` / `zildjian` |
| **`DESK_1TB`** | `/mnt/drives/DESK_1TB` *(sdc1)* | Authenticated | `garciamedia` / `zildjian` |
| **`Windows`** | `/mnt/drives/Windows` *(sdb3)* | Authenticated | `garciamedia` / `zildjian` |
| **`LinuxData`** | `/mnt/drives/LinuxData` *(sdd1)* | Authenticated | `garciamedia` / `zildjian` |

### 3. Remote Administration & Desktop

| Protocol / Tool | Port | Connection Target | Credentials | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **SSH** | `22` | `ssh garciamedia@192.168.4.41` | `garciamedia` / `zildjian` | Terminal CLI & VS Code Remote |
| **XRDP (Remote Desktop)** | `3389` | `192.168.4.41` in `mstsc.exe` | `garciamedia` / `zildjian` | Virtual XFCE desktop session |
| **RustDesk** | `21115-21119` | Server RustDesk ID | Set in RustDesk UI | Captures physical or headless `:0` |

### 4. Reverse Proxy via Caddy (Port 80)

All services are accessible on HTTP port 80 with Catppuccin Mocha theming if your client PC's hosts file maps `192.168.4.41` to:
- `http://jellyfin.nixflix.local`
- `http://seerr.nixflix.local`
- `http://sonarr.nixflix.local`
- `http://radarr.nixflix.local`
- `http://prowlarr.nixflix.local`
- `http://qbittorrent.nixflix.local`

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

4. **Stage files and switch to the flake**:
   ```bash
   cd /etc/nixos/zj-nixflix
   git add -A
   sudo env NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#garciamedia
   ```

5. **Reboot and verify repo ownership for `garciamedia`**:
   ```bash
   sudo reboot
   ```
   After logging in as `garciamedia`, ensure `garciamedia` owns the repo for remote editing:
   ```bash
   sudo chown -R garciamedia:users /etc/nixos/zj-nixflix
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
   ssh garciamedia@<IP-ADDRESS>
   # Initial password: zildjian
   ```
   *(Change your Linux password with `passwd`.)*

2. **Remote Desktop:**
   - **Windows RDP (`mstsc`):** Connect to `<IP-ADDRESS>` with username `garciamedia` (always creates a virtual session, even in physical monitor mode).
   - **RustDesk:** Connect using the server's RustDesk ID (switch to the `headless` specialisation if no monitor is plugged in).

3. **VS Code & Antigravity IDE:**
   - **Inside RDP / RustDesk:** Launch `antigravity` or `code /etc/nixos/zj-nixflix`.
   - **Via Remote-SSH:** Connect from another computer to `garciamedia@garciamedia` (or `garciamedia@<IP-ADDRESS>`) and open `/etc/nixos/zj-nixflix`.
   - **Apply configuration changes:**
     ```bash
     cd /etc/nixos/zj-nixflix
     git add -A
     sudo nixos-rebuild switch --flake .#garciamedia
     ```

4. **Shared Network Drives (SMB):**
   First set your Samba password once on `garciamedia`:
   ```bash
   sudo smbpasswd -a garciamedia
   ```
   Then connect from Windows (`\\garciamedia\<Share>`) or macOS/Linux (`smb://garciamedia.local/<Share>`):
   - Public (guest): `Media`, `Downloads`
   - Authenticated (`garciamedia`): `SharedDrive`, `ZeeJay_640G`, `Windows`, `DESK_1TB`, `LinuxData`

---

## Downloading Torrents from Another PC (Remote qBittorrent WebUI)

Instead of downloading torrents over SMB from another desktop, open **`garciamedia`'s own qBittorrent WebUI** in your browser so `garciamedia` writes directly to its local drives (even if your other PC sleeps or shuts down).

### 1. Open qBittorrent WebUI from another desktop on your LAN
Choose either method:

- **Option A — Via Caddy (`http://qbittorrent.nixflix.local`, zero server config changes):**
  On your client PC, add a line to its `hosts` file (`C:\Windows\System32\drivers\etc\hosts` on Windows as Administrator, or `/etc/hosts` on macOS/Linux):
  ```text
  <GARCIAMEDIA-IP>  qbittorrent.nixflix.local jellyfin.nixflix.local seerr.nixflix.local sonarr.nixflix.local radarr.nixflix.local prowlarr.nixflix.local
  ```
  Then open `http://qbittorrent.nixflix.local` in your browser.

- **Option B — Direct port (`http://<GARCIAMEDIA-IP>:8282` or `http://garciamedia.local:8282`):**
  By default qBittorrent binds only to `127.0.0.1` (for Caddy). To allow direct LAN access on port `8282`, add `serverConfig.Preferences.WebUI.Address = "*";` inside `torrentClients.qbittorrent` in [media.nix](media.nix), then run:
  ```bash
  cd /etc/nixos/zj-nixflix
  git add -A
  sudo nixos-rebuild switch --flake .#garciamedia
  ```

### 2. Log in to qBittorrent WebUI
Log in with username `admin` and password `zildjian` (configured in [secrets.nix](secrets.nix) and [media.nix](media.nix)).

### 3. Choose where the torrent saves
In qBittorrent's **Add Torrent** dialog, set **Save at** to a local path on `garciamedia` — it will automatically appear on the corresponding network share:

| qBittorrent **Save at** path | Visible on the network at |
| --- | --- |
| `/data/downloads/torrent/default` *(default)* | `\\garciamedia\Downloads\torrent\default` |
| `/mnt/drives/ZeeJay_640G` | `\\garciamedia\ZeeJay_640G` |
| `/mnt/drives/DESK_1TB` | `\\garciamedia\DESK_1TB` |
| `/mnt/drives/Windows` | `\\garciamedia\Windows` |
| `/mnt/drives/LinuxData/<writable-folder>` | `\\garciamedia\LinuxData\<writable-folder>` |
