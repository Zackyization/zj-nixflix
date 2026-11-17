{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./storage.nix
    ./remote-desktop.nix
    ./media.nix
  ];

  # 1. System Identity & Timezone
  networking.hostName = "garciamedia";
  time.timeZone = "Asia/Singapore";
  i18n.defaultLocale = "en_SG.UTF-8";

  # 2. Bootloader (UEFI / systemd-boot)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 3. Networking
  networking.networkmanager.enable = true;

  # 4. User Accounts
  users.users.garciamedia = {
    isNormalUser = true;
    description = "Media Server Administrator";
    extraGroups = [
      "wheel" # sudo privileges
      "networkmanager" # network control
      "media" # access to media & downloads directories
      "video" # GPU video acceleration
      "render" # GPU render devices
    ];
    # Default initial password is "zildjian". Change after install with: passwd
    initialPassword = "zildjian";
  };

  # Allow members of 'wheel' to run sudo without typing password (convenient for headless setup)
  security.sudo.wheelNeedsPassword = false;

  # 5. Nix & Flakes Configuration
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  # Allow proprietary packages (e.g. unfree codecs / drivers)
  nixpkgs.config.allowUnfree = true;

  # Allow dynamically linked binaries (needed for VS Code Remote-SSH & extensions)
  programs.nix-ld.enable = true;

  # Web browser for managing web UIs locally / over RDP
  programs.firefox.enable = true;

  # 6. Essential Administration & Development Tools
  environment.systemPackages = with pkgs; [
    vim
    git
    gh
    vscode.fhs
    antigravity-ide-fhs
    nixd
    nixfmt
    htop
    btop
    tmux
    curl
    wget
    pciutils
    usbutils
    fastfetch
    tree
  ];

  system.stateVersion = "26.11";
}
