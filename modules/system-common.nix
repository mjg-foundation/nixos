{ usernames ? [] }:
{ pkgs, inputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.default
    (import "${inputs.self}/modules/system-packages.nix" { inherit usernames; })
    "${inputs.self}/modules/opentabletdriver.nix"
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.printing.enable = true;
  services.pulseaudio.enable = false;

  services.udev = {
    enable = true;
    extraRules = ''
      # Silicon Labs CP210x UART Bridge (debug board)
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="plugdev", MODE="0666"
      # Transcend Information, Inc. 2GB/4GB/8GB Flash Drive (Prime)
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1307", ATTRS{idProduct}=="0165", MODE="0666", SYMLINK+="ttyPrime"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="1307", ATTRS{idProduct}=="0165", MODE="0666", TAG+="uaccess"
      # Ledger Passport Prime (Prime in Legacy mode)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2c97", ATTRS{idProduct}=="0007", MODE="0666", TAG+="uaccess"
      # Atmel Corp. at91sam SAMBA bootloader (Prime)
      SUBSYSTEM=="tty", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="6124", MODE="0666"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="6124", MODE="0666", TAG+="uaccess"
    '';
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages."${pkgs.stdenv.hostPlatform.system}".hyprland;
  };

  home-manager.extraSpecialArgs = { inherit inputs; };

  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.symbols-only
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
}
