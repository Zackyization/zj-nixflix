{ lib, ... }: {
  # Attached storage drive configuration
  # Mounts your attached drive at /data (which hosts media, downloads, and state).
  #
  # TIP: Find your hard drive's UUID with:
  #   lsblk -f   OR   blkid
  # and change '/dev/disk/by-label/data' to '/dev/disk/by-uuid/<YOUR-UUID>'
  fileSystems."/data" = {
    device = lib.mkDefault "/dev/disk/by-label/data";
    fsType = lib.mkDefault "ext4";
    options = [
      "defaults"
      "nofail"
    ]; # 'nofail' ensures system boots even if unplugged
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

      # 3. Main Data Drive: Full attached drive (protected, requires 'admin' login)
      "SharedDrive" = {
        "path" = "/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "admin";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force group" = "media";
        "comment" = "Full Attached Storage Drive";
      };
    };
  };

  # Windows Network Discovery Daemon (WSDD)
  # Automatically advertises this server so it shows up in Windows Explorer under "Network"
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
