{ userName, userEmail }:
{ inputs, ... }:

{
  imports = [
    (import "${inputs.self}/modules/git.nix" { inherit userName userEmail; })
    "${inputs.self}/modules/packages.nix"
    "${inputs.self}/modules/waybar/default.nix"
    "${inputs.self}/modules/kitty.nix"
    "${inputs.self}/modules/rust.nix"
    "${inputs.self}/modules/album-picker/default.nix"
    "${inputs.self}/modules/reminder/default.nix"
    "${inputs.self}/modules/screenshot.nix"
    "${inputs.self}/modules/neovim.nix"
  ];

  programs.home-manager.enable = true;
}
