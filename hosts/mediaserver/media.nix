{ pkgs, ... }:
let
  secrets = import ./secrets.nix;
in
{
  # 1. AMD Hardware Transcoding for Ryzen 7 5700G (Radeon Vega iGPU)
  # Enables VA-API hardware transcoding so Jellyfin can stream 4K/1080p without high CPU usage
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # Grant Jellyfin permissions to access GPU render nodes (/dev/dri/renderD128)
  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];

  # 2. Nixflix Media Stack Configuration
  nixflix = {
    enable = true;

    # Media and storage directories on your attached hard drive
    mediaDir = "/data/media";
    downloadsDir = "/data/downloads";
    stateDir = "/data/.state";
    mediaUsers = [ "admin" ];

    # Unified theme across all services
    theme = {
      enable = true;
      name = "catppuccin-mocha";
    };

    # Reverse proxy: Caddy (access apps via http://<service>.nixflix.local)
    caddy = {
      enable = true;
      addHostsEntries = true;
      domain = "nixflix.local";
    };

    # PostgreSQL database backend for optimal performance
    postgres.enable = true;

    # Jellyfin media streaming server
    jellyfin = {
      enable = true;
      apiKey = secrets.jellyfin.apiKey;
      users.admin = {
        policy.isAdministrator = true;
        password = secrets.jellyfin.adminPassword;
      };
    };

    # Seerr media request management (integrates with Jellyfin, Sonarr, Radarr)
    seerr = {
      enable = true;
      apiKey = secrets.seerr.apiKey;
    };

    # Sonarr: TV show automation
    sonarr = {
      enable = true;
      config = {
        apiKey = secrets.sonarr.apiKey;
        hostConfig.password = secrets.sonarr.webPassword;
      };
    };

    # Radarr: Movie automation
    radarr = {
      enable = true;
      config = {
        apiKey = secrets.radarr.apiKey;
        hostConfig.password = secrets.radarr.webPassword;
      };
    };

    # Prowlarr: Torrent & Usenet indexer manager
    prowlarr = {
      enable = true;
      config = {
        apiKey = secrets.prowlarr.apiKey;
        hostConfig.password = secrets.prowlarr.webPassword;
      };
    };

    # qBittorrent download client
    torrentClients.qbittorrent = {
      enable = true;
    };
  };

  # Open firewall for direct port access in addition to Caddy reverse proxy
  networking.firewall.allowedTCPPorts = [
    80 # Caddy HTTP
    443 # Caddy HTTPS
    8096 # Jellyfin direct HTTP
    5055 # Seerr direct HTTP
    8989 # Sonarr direct HTTP
    7878 # Radarr direct HTTP
    9696 # Prowlarr direct HTTP
    8282 # qBittorrent Web UI
  ];
}
