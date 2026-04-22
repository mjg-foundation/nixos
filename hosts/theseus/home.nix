{ inputs, ... }:
{
  imports = [
    (import "${inputs.self}/modules/home-common.nix" {
      userName = "Matt Gleason";
      userEmail = "mjgleason@foundationdevices.com";
    })
    "${inputs.self}/hosts/theseus/hyprland/default.nix"
    "${inputs.self}/hosts/theseus/kitty.nix"
    "${inputs.self}/hosts/theseus/helix.nix"
    "${inputs.self}/hosts/theseus/git.nix"
    "${inputs.self}/hosts/theseus/cmus.nix"
    "${inputs.self}/hosts/theseus/neovim.nix"
  ];
  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.05";
}
