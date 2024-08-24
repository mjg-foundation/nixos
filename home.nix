{ config, pkgs, ... }:
let
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz";
    sha256 = "0c83di08nhkzq0cwc3v7aax3x8y5m7qahyzxppinzwxi3r8fnjq3";
  };
  # TODO: update home-manager version with nixpkgs version
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.matt = {
    home.stateVersion = "24.05";

    programs.git = {
      enable = true;
      userEmail = "mjgleason@foundationdevices.com";
      userName = "Matt Gleason";
      extraConfig = {
        core = {
          editor = "vim";
        };
      };
    };

    xdg.configFile."sway/config".source = ./sway_config;

  };
}
