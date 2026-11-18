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
| **Sonarr** | `8989` | `http://192.168.4.41:8989` | `http://garciamedia.local:8989` | `admin` | `zildjian` | TV series automation & manager |
| **Radarr** | `7878` | `http://192.168.4.41:7878` | `http://garciamedia.local:7878` | `admin` | `zildjian` | Movie automation & manager |
| **Prowlarr** | `9696` | `http://192.168.4.41:9696` | `http://garciamedia.local:9696` | `admin` | `zildjian` | Torrent & Usenet indexer manager |
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

#### How to Access Shared Files from a Windows PC:

* **Method 1: Direct File Explorer Path (Fastest)**
  1. On your Windows PC, press **`Windows Key + R`** to open the Run box (or click the address bar in File Explorer).
  2. Type `\\192.168.4.41` *(or `\\garciamedia`)* and press **Enter**.
  3. When the Windows Security prompt appears:
     * **Username**: `garciamedia` *(or `.\garciamedia`)*
     * **Password**: `zildjian`
     * Check **"Remember my credentials"** so you do not have to log in again.
  4. All shared folders and mounted hard drives will immediately appear.

* **Method 2: Map as a Permanent Drive Letter (e.g. `Z:`)**
  1. Open **File Explorer** and click **This PC** on the left sidebar.
  2. Click the **`...`** in the top menu bar (or right-click **This PC**) and choose **Map network drive...**
  3. Select a drive letter (e.g. `Z:`).
  4. In the **Folder** field, enter the share you want:
     * `\\192.168.4.41\Media` *(Media library)*
     * `\\192.168.4.41\Downloads` *(Downloads)*
     * `\\192.168.4.41\DESK_1TB` *(1TB SATA drive)*
     * `\\192.168.4.41\ZeeJay_640G` *(640GB SATA drive)*
     * `\\192.168.4.41\Windows` *(Windows partition)*
     * `\\192.168.4.41\LinuxData` *(Linux ext4 partition)*
  5. Check both:
     * [x] **Reconnect at sign-in**
     * [x] **Connect using different credentials**
  6. Click **Finish**, enter `garciamedia` / `zildjian`, and check **"Remember my credentials"**.

* **Method 3: Via Windows Network Discovery**
  1. In File Explorer, click **Network** on the left sidebar.
  2. If Windows displays a prompt stating *"Network discovery is turned off"*, click it and select **Turn on network discovery and file sharing**.
  3. Under **Computers**, find **`GARCIAMEDIA`** (advertised automatically via WSDD).
  4. Double-click it and enter your credentials (`garciamedia` / `zildjian`).

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

## Media Stack Workflows & Examples

All services (`Seerr`, `Radarr`, `Sonarr`, `Prowlarr`, `qBittorrent`, and `Jellyfin`) are already wired together. Follow the one-time Prowlarr setup below to unlock automated requests, or use qBittorrent directly for manual downloads.

### One-Time Setup: Add Torrent Indexers in Prowlarr
Nixflix pre-connects Prowlarr to Radarr and Sonarr, so you only need to add your torrent sites once:

1. Open **Prowlarr** (`http://192.168.4.41:9696` or `http://garciamedia.local:9696`) and sign in (`admin` / `zildjian`).
2. Go to **Indexers → Add Indexer**, pick the torrent sites you use, click **Test**, and **Save**.
3. Go to **Settings → Apps → Sync App Indexers** to push those indexers into **Radarr** and **Sonarr**.

---

### Workflow 1: Automated Movies & TV Shows (Seerr → Starr → qBittorrent → Jellyfin)
Use this when you want a "search and click Request" Netflix-style experience:

1. Open **Seerr** (`http://192.168.4.41:5055` or `http://garciamedia.local:5055`) and sign in with your Jellyfin account (`admin` / `zildjian`).
2. Search for any movie or TV series (for example, *Inception* or *Severance*) and click **Request**.
3. Behind the scenes, the stack automatically:
   - Sends movies to **Radarr** (`:7878`) or TV shows to **Sonarr** (`:8989`).
   - Queries your **Prowlarr** indexers and sends the best matching torrent to **qBittorrent**.
   - Downloads into `/data/downloads/torrent/radarr` or `/data/downloads/torrent/sonarr`.
   - Hardlinks and renames the clean media file into `/data/media/movies` or `/data/media/tv` (keeping seeding intact without using double disk space).
   - Scans it into **Jellyfin** so it is ready to watch.

> [!TIP]
> Want to hand-pick a specific torrent release (e.g. a particular codec, sub group, or 1080p/4K encode)? Open **Radarr** (`http://192.168.4.41:7878`) or **Sonarr** (`http://192.168.4.41:8989`), select the title, and click **Interactive Search**.

---

### Workflow 2: Manual Torrents in qBittorrent (Custom Magnets & Choosing Any Folder)
Use this for non-media files (ISOs, software, archives) or magnets you want to manage yourself:

1. Open **qBittorrent** (`http://192.168.4.41:8282` or `http://garciamedia.local:8282`) and log in (`admin` / `zildjian`).
2. Add a `.torrent` file or magnet link.
3. **Choosing where it downloads:**
   By default, **Torrent Management Mode** is set to **`Automatic`**, which locks the **Save files to location** box to category folders (`radarr`, `sonarr`, `prowlarr`).
   - To pick any custom folder (like `/data/media/movies` or one of your extra drives), change **Torrent Management Mode** from **`Automatic`** to **`Manual`** in the **Add Torrent** dialog.
   - Example destinations:
     - General files: `/data/downloads/torrent/default` *(visible at `\\192.168.4.41\Downloads\torrent\default`)*
     - Extra drives: `/mnt/drives/DESK_1TB` or `/mnt/drives/ZeeJay_640G` *(visible at `\\192.168.4.41\DESK_1TB` / `\\192.168.4.41\ZeeJay_640G`)*
     - Direct media drop: `/data/media/movies` or `/data/media/tv` *(or download to `/data/downloads/torrent/default` and use **Radarr / Sonarr → Wanted → Manual Import** so it gets cleanly renamed for Jellyfin)*

---

### Workflow 3: Watching & Sharing in Jellyfin
1. Open **Jellyfin** in a browser (`http://192.168.4.41:8096` or `http://garciamedia.local:8096`) or install the Jellyfin app on your TV, phone, or other PC and connect to `http://192.168.4.41:8096`.
2. Sign in as `admin` / `zildjian`. Your **Movies** (`/data/media/movies`) and **Shows** (`/data/media/tv`) libraries are already configured.
3. *(Optional)* In Jellyfin **Dashboard → Users**, create separate accounts for family/housemates — they can also sign in to **Seerr** with those Jellyfin accounts to request shows on their own.

---

## Headless Remote Access & Display Modes

You have two different ways to connect to the desktop remotely when running headless (without a physical monitor):

### Method 1: Windows Remote Desktop / XRDP (Easiest — No Setup Needed!)
- **XRDP is already active on port `3389`**.
- It creates its own dedicated virtual X11 session on demand whenever you connect.
- **You do NOT need to switch to headless mode or unplug anything**. It works in both physical monitor and headless setups automatically!
- On any Windows PC:
  1. Press `Win + R`, type `mstsc`, and press **Enter**.
  2. Enter Computer: `192.168.4.41`
  3. Log in with Username: `garciamedia` and your Linux password.

---

### Method 2: RustDesk (Remote Desktop on Display `:0`)

RustDesk captures the system's primary display (`:0`). If no physical monitor is plugged into the motherboard, the graphics card reports `0 active displays`, causing RustDesk to show **"no display"**.

To solve this, `garciamedia` includes automated commands to switch between physical monitor and virtual dummy display modes:

| Command | What it does |
| --- | --- |
| `sudo headless-on` | Switches to the virtual 1080p dummy display, restarts LightDM and RustDesk. Ready for remote access without a monitor! |
| `sudo headless-off` | Switches back to your physical monitor (HDMI/DP) and restarts LightDM and RustDesk. |

> [!TIP]
> **Best Long-Term Hardware Solution ($3 HDMI Dummy Plug):**
> If you plan to run this PC as a permanent headless server, consider buying an **HDMI Dummy Plug / Headless Ghost** (cost is around \$3 on Amazon/eBay/Shopee). 
> Plugging this tiny adapter into the motherboard keeps the AMD Radeon GPU hardware acceleration (VA-API for Jellyfin and RustDesk) permanently active at 1080p/4K without needing any software switching scripts or dummy drivers!

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
   The initial Samba password for `garciamedia` is automatically initialized to `zildjian` (change it anytime with `sudo smbpasswd garciamedia`).
   Connect from Windows (`\\192.168.4.41` or `\\garciamedia`) or macOS/Linux (`smb://192.168.4.41` or `smb://garciamedia.local`):
   - Public (guest, no password): `Media`, `Downloads`
   - Authenticated (`garciamedia` / `zildjian`): `SharedDrive`, `ZeeJay_640G`, `Windows`, `DESK_1TB`, `LinuxData`
   *(See [Network Hard Drive Shares (Samba / SMB)](#2-network-hard-drive-shares-samba--smb) above for full Windows mapping instructions).*

---

## Downloading Torrents from Another PC (Remote qBittorrent WebUI)

Instead of downloading torrents over SMB from another desktop, open **`garciamedia`'s own qBittorrent WebUI** in your browser so `garciamedia` writes directly to its local drives (even if your other PC sleeps or shuts down).

### 1. Open qBittorrent WebUI from another desktop on your LAN
- **Direct access (already enabled):** Open `http://192.168.4.41:8282` or `http://garciamedia.local:8282` in your browser.
- **Via Caddy (`http://qbittorrent.nixflix.local`):** On your client PC, add a line to its `hosts` file (`C:\Windows\System32\drivers\etc\hosts` on Windows as Administrator, or `/etc/hosts` on macOS/Linux):
  ```text
  192.168.4.41  qbittorrent.nixflix.local jellyfin.nixflix.local seerr.nixflix.local sonarr.nixflix.local radarr.nixflix.local prowlarr.nixflix.local
  ```
  Then open `http://qbittorrent.nixflix.local` in your browser.

### 2. Log in to qBittorrent WebUI
Log in with username `admin` and password `zildjian` (configured in [secrets.nix](secrets.nix) and [media.nix](media.nix)).

### 3. Choose where the torrent saves
In qBittorrent's **Add Torrent** dialog, switch **Torrent Management Mode** from **`Automatic`** to **`Manual`** to unlock **Save files to location**, then set it to a local path on `garciamedia` — it will automatically appear on the corresponding network share:

| qBittorrent **Save at** path | Visible on the network at |
| --- | --- |
| `/data/downloads/torrent/default` *(default)* | `\\garciamedia\Downloads\torrent\default` |
| `/mnt/drives/ZeeJay_640G` | `\\garciamedia\ZeeJay_640G` |
| `/mnt/drives/DESK_1TB` | `\\garciamedia\DESK_1TB` |
| `/mnt/drives/Windows` | `\\garciamedia\Windows` |
| `/mnt/drives/LinuxData/<writable-folder>` | `\\garciamedia\LinuxData\<writable-folder>` |
