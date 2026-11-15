{ pkgs, ... }: {
  # 1. SSH Server for remote command-line management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = true; # You can disable this once you add your SSH public key
    };
    openFirewall = true;
  };

  # 2. Lightweight Desktop Environment (XFCE)
  # Low memory footprint (~350MB RAM), fast and stable for headless servers.
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.lightdm.enable = true;

    # 3. Headless Virtual Display Driver
    # Creates a virtual 1080p display in RAM so desktop sessions run without a physical monitor.
    # Note: If you choose to plug an inexpensive physical HDMI dummy plug into the PC,
    # you can comment out the 'videoDrivers' and 'config' lines below to use hardware acceleration.
    videoDrivers = [ "dummy" ];
    config = ''
      Section "Device"
        Identifier "VirtualDummyDevice"
        Driver "dummy"
        VideoRam 256000
      EndSection

      Section "Monitor"
        Identifier "VirtualDummyMonitor"
        HorizSync 28.0-80.0
        VertRefresh 48.0-75.0
        Modeline "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
      EndSection

      Section "Screen"
        Identifier "VirtualDummyScreen"
        Device "VirtualDummyDevice"
        Monitor "VirtualDummyMonitor"
        DefaultDepth 24
        SubSection "Display"
          Depth 24
          Modes "1920x1080"
        EndSubSection
      EndSection
    '';
  };

  # Auto-login to the admin session on boot
  services.displayManager.autoLogin = {
    enable = true;
    user = "admin";
  };

  # 4. XRDP (Windows Remote Desktop Protocol)
  # Allows connecting directly from any Windows PC using the built-in "Remote Desktop Connection" (mstsc)
  # Creates its own virtual display session on demand with no monitor required.
  services.xrdp = {
    enable = true;
    defaultWindowManager = "xfce4-session";
    openFirewall = true;
  };

  # 5. RustDesk Remote Desktop
  environment.systemPackages = with pkgs; [
    rustdesk-flutter
    xclip # clipboard support
  ];

  # RustDesk background service
  systemd.services.rustdesk = {
    description = "RustDesk Remote Desktop Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # Auto-start RustDesk tray client in the user's graphical session
  environment.etc."xdg/autostart/rustdesk.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=RustDesk
    Exec=${pkgs.rustdesk-flutter}/bin/rustdesk
    Hidden=false
    NoDisplay=false
    X-GNOME-Autostart-enabled=true
  '';

  # Firewall rules for RustDesk direct connection & local discovery
  networking.firewall = {
    allowedTCPPorts = [
      21115 # RustDesk NAT type test
      21116 # RustDesk ID/Relay port
      21117 # RustDesk Relay port
      21118 # RustDesk Web client
      21119 # RustDesk Web client
    ];
    allowedUDPPorts = [
      21116 # RustDesk ID/Heartbeat/Keepalive
    ];
  };
}
