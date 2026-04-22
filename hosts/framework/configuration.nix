{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (import "${inputs.self}/modules/system-common.nix" { usernames = [ "matt" ]; })
    "${inputs.self}/modules/x11.nix"
    "${inputs.self}/modules/kde.nix"
    "${inputs.self}/modules/bluetooth.nix"
    (import "${inputs.self}/modules/swapdevices.nix" { megabytes = 32 * 1024; })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "framework";
  time.timeZone = "America/Indiana/Indianapolis";
  services.displayManager.sddm.enable = true;

  users.users.matt = {
    isNormalUser = true;
    description = "Matt";
    extraGroups = [ "networkmanager" "wheel" "dialout" ];
  };

  security.pam.services."matt".kwallet = {
    enable = true;
    package = pkgs.kdePackages.kwallet-pam;
  };

  home-manager.users."matt" = import ./home.nix;

  environment.variables = {
    KEYOS = "/home/matt/Projects/KeyOS";
    NIX = "/home/matt/nix_config";
    NGWALLET = "/home/matt/Projects/ngwallet";
    ROOT_PASSPORT = "/home/matt/Projects/passport2";
    PASSPORT = "/home/matt/Projects/passport2/ports/stm32/boards/Passport";
  };

  system.stateVersion = "25.05";
}
