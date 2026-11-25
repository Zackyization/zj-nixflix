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

    # Media and storage directories on the unified MergerFS pool (/mnt/storage)
    # State, configs, and databases remain on the fast NVMe root drive (/data/.state)
    mediaDir = "/mnt/storage/media";
    downloadsDir = "/mnt/storage/downloads";
    stateDir = "/data/.state";
    mediaUsers = [ "garciamedia" ];

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
      openFirewall = true;
      network.localNetworkAddresses = [ "0.0.0.0" ];
      apiKey = secrets.jellyfin.apiKey;
      users.admin = {
        policy = {
          isAdministrator = true;
          enableSubtitleManagement = true;
        };
        password = secrets.jellyfin.adminPassword;
      };

      plugins = {
        # Multi-provider subtitle downloader (supports automatic & on-demand downloads)
        subbuzz = {
          enable = true;
          config = {
            # Providers that work out-of-the-box without an account/API key
            EnableYifySubtitles = true;
            EnableAddic7ed = true;
            EnableSubf2m = true;
            EnablePodnapisiNet = true;

            # Optional: uncomment and add credentials/API keys for broader TV & movie coverage
            # EnableOpenSubtitles = true;
            # OpenSubUserName = "your-opensubtitles-username";
            # OpenSubPassword = "your-opensubtitles-password";
            # OpenSubApiKey = "your-opensubtitles-api-key";
            # EnableSubdlCom = true;
            # SubdlApiKey = "your-subdl-api-key";
            # EnableSubSource = true;
            # SubSourceApiKey = "your-subsource-api-key";
          };
        };

        # Proactively extract embedded subtitles from video files during library scans
        "Subtitle Extract" = {
          enable = true;
          config.ExtractionDuringLibraryScan = true;
        };
      };

      libraries =
        let
          subtitleSettings = {
            subtitleDownloadLanguages = [ "eng" ];
            requirePerfectSubtitleMatch = false;
            saveSubtitlesWithMedia = true;
            skipSubtitlesIfEmbeddedSubtitlesPresent = true;
            skipSubtitlesIfAudioTrackMatches = false;
          };
        in
        {
          Shows = subtitleSettings;
          Movies = subtitleSettings;
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
      mediaDirs = [
        "/mnt/storage/media/tv"
        "/data/media/tv"
      ];
      config = {
        apiKey = secrets.sonarr.apiKey;
        hostConfig = {
          bindAddress = "0.0.0.0";
          username = "admin";
          password = secrets.sonarr.webPassword;
        };
      };
    };

    # Radarr: Movie automation
    radarr = {
      enable = true;
      mediaDirs = [
        "/mnt/storage/media/movies"
        "/data/media/movies"
      ];
      config = {
        apiKey = secrets.radarr.apiKey;
        hostConfig = {
          bindAddress = "0.0.0.0";
          username = "admin";
          password = secrets.radarr.webPassword;
        };
      };
    };

    # FlareSolverr: Cloudflare challenge solver proxy for Prowlarr indexers
    flaresolverr.enable = true;

    # Prowlarr: Torrent & Usenet indexer manager
    prowlarr = {
      enable = true;
      config = {
        apiKey = secrets.prowlarr.apiKey;
        hostConfig = {
          bindAddress = "0.0.0.0";
          username = "admin";
          password = secrets.prowlarr.webPassword;
        };
        indexers = map (name: {
          inherit name;
          tags = [ "flaresolverr" ];
        }) [
          "1337x"
          "The Pirate Bay"
          "YTS"
          "EZTV"
          "Knaben"
          "Nyaa.si"
        ];
      };
    };

    # qBittorrent download client
    torrentClients.qbittorrent = {
      enable = true;
      webuiPort = 8282;
      password = secrets.qbittorrent.webPassword;
      serverConfig = {
        LegalNotice.Accepted = true;
        Preferences = {
          WebUI = {
            Address = "*";
            Username = "admin";
            Password_PBKDF2 = secrets.qbittorrent.passwordPbkdf2;
          };
          General.Locale = "en";
        };
      };
    };
  };

  # Bind Seerr to 0.0.0.0 so direct port access (5055) works from the LAN
  systemd.services.seerr.environment.HOST = pkgs.lib.mkForce "0.0.0.0";

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
