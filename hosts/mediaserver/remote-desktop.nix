{ pkgs, lib, ... }: {
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
  # Low memory footprint (~350MB RAM), fast and stable for desktop & headless use.
  # Default boot uses your physical monitor output (while XRDP still creates virtual sessions on demand).
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.lightdm.enable = true;
  };

  # 3. Headless Virtual Display Specialisation
  # Allows running RustDesk without any physical monitor plugged in.
  # Use the helper commands:
  #   sudo headless-on   (switches to virtual 1080p dummy display & restarts display manager)
  #   sudo headless-off  (switches back to physical HDMI/DP monitor)
  specialisation.headless.configuration = {
    services.xserver = {
      videoDrivers = lib.mkForce [ "dummy" ];
      deviceSection = ''
        VideoRam 256000
      '';
      monitorSection = ''
        HorizSync 28.0-80.0
        VertRefresh 48.0-75.0
        Modeline "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
      '';
      screenSection = ''
        DefaultDepth 24
        SubSection "Display"
          Depth 24
          Modes "1920x1080"
        EndSubSection
      '';
    };
  };

  # Helper scripts for seamless headless switching
  environment.systemPackages = with pkgs; [
    rustdesk-flutter
    xclip # clipboard support
    (pkgs.writeShellScriptBin "headless-on" ''
      echo "=== Switching to Headless (Virtual Display) Mode ==="
      /nix/var/nix/profiles/system/specialisation/headless/bin/switch-to-configuration switch
      echo "Restarting display manager for virtual display..."
      systemctl restart display-manager.service
      systemctl restart rustdesk.service
      echo "=== Headless mode active (Virtual 1920x1080 on :0) ==="
    '')
    (pkgs.writeShellScriptBin "headless-off" ''
      echo "=== Switching to Physical Monitor Mode ==="
      /nix/var/nix/profiles/system/bin/switch-to-configuration switch
      echo "Restarting display manager for physical monitor..."
      systemctl restart display-manager.service
      systemctl restart rustdesk.service
      echo "=== Physical monitor mode active ==="
    '')
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
