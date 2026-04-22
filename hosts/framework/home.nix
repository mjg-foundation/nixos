{ inputs, ... }:
{
  imports = [
    (import "${inputs.self}/modules/home-common.nix" {
      userName = "Matt Gleason";
      userEmail = "mjgleason@foundationdevices.com";
    })
    "${inputs.self}/hosts/framework/hyprland/default.nix"
    "${inputs.self}/hosts/framework/kitty.nix"
    "${inputs.self}/hosts/framework/helix.nix"
    "${inputs.self}/hosts/framework/git.nix"
    "${inputs.self}/hosts/framework/cmus.nix"
    "${inputs.self}/hosts/framework/neovim.nix"
  ];
  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.05";
}
