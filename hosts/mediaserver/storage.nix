{ ... }:
let
  # Shared options for non-POSIX drives (exfat/ntfs3) so the 'media' group (gid 169)
  # — including garciamedia, qbittorrent, and jellyfin — has read/write access
  # without touching existing drive contents.
  nonPosixOptions = [
    "defaults"
    "nofail"
    "x-systemd.device-timeout=5s"
    "uid=0"
    "gid=169"
    "dmask=0002"
    "fmask=0113"
    "iocharset=utf8"
  ];

  mkUserShare =
    {
      path,
      comment,
      forceRoot ? false,
    }:
    {
      inherit path comment;
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "garciamedia";
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = "media";
    }
    // (if forceRoot then { "force user" = "root"; } else { });
in
{
  # Enable kernel NTFS (ntfs3) support for the Windows partition
  boot.supportedFilesystems = [ "ntfs" ];

  # Mount existing SATA/USB drives under /mnt/drives without modifying or formatting them.
  # /data remains on the NVMe root partition (nvme0n1p2).
  fileSystems = {
    "/mnt/drives/ZeeJay_640G" = {
      device = "/dev/disk/by-uuid/BC1B-EE38";
      fsType = "exfat";
      options = nonPosixOptions;
    };

    "/mnt/drives/Windows" = {
      device = "/dev/disk/by-uuid/680259DA0259AE36";
      fsType = "ntfs3";
      options = nonPosixOptions;
    };

    "/mnt/drives/DESK_1TB" = {
      device = "/dev/disk/by-uuid/B4B7-7594";
      fsType = "exfat";
      options = nonPosixOptions;
    };

    "/mnt/drives/LinuxData" = {
      device = "/dev/disk/by-uuid/d584bbb9-5f65-4d33-9f76-8429e4c0c2db";
      fsType = "ext4";
      options = [
        "defaults"
        "nofail"
        "x-systemd.device-timeout=5s"
      ];
    };
  };

  # Samba (SMB) file sharing across the local network (Windows, Mac, Linux, TVs)
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "Nixflix Media & File Server";
        "netbios name" = "garciamedia";
        "security" = "user";
        # Allow connections from your local subnet (covers 192.168.4.0/22: 192.168.4.1 to 192.168.7.254)
        "hosts allow" = "192.168.4. 192.168. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
        # Performance tuning for fast network transfers
        "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
        "min protocol" = "SMB2";
        "ea support" = "yes";
      };

      # 1. Media Share: Movies, Shows, Music (accessible without password on home LAN)
      "Media" = {
        "path" = "/data/media";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force user" = "root";
        "force group" = "media";
        "comment" = "Nixflix Media Library";
      };

      # 2. Downloads Share: Active and finished downloads
      "Downloads" = {
        "path" = "/data/downloads";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force user" = "root";
        "force group" = "media";
        "comment" = "Active and Completed Downloads";
      };

      # 3. Protected shares (require 'garciamedia' SMB password: sudo smbpasswd -a garciamedia)
      "SharedDrive" = mkUserShare {
        path = "/data";
        comment = "Nixflix Data Directory (NVMe)";
      };

      "ZeeJay_640G" = mkUserShare {
        path = "/mnt/drives/ZeeJay_640G";
        comment = "ZeeJay 640GB Drive (sda1)";
      };

      "Windows" = mkUserShare {
        path = "/mnt/drives/Windows";
        comment = "Windows NTFS Drive (sdb3)";
      };

      "DESK_1TB" = mkUserShare {
        path = "/mnt/drives/DESK_1TB";
        comment = "DESK 1TB Drive (sdc1)";
      };

      "LinuxData" = mkUserShare {
        path = "/mnt/drives/LinuxData";
        comment = "Linux ext4 Drive (sdd1)";
        # Allow garciamedia to read existing files on sdd1 regardless of prior UIDs
        forceRoot = true;
      };
    };
  };

  # Windows Network Discovery Daemon (WSDD) for Windows Explorer
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Avahi (mDNS/Bonjour) for macOS Finder & Linux file manager discovery (garciamedia.local)
  services.avahi = {
    enable = true;
    openFirewall = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      workstation = true;
      userServices = true;
    };
  };
}
