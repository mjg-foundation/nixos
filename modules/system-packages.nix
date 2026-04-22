{ usernames ? [] }:
{ pkgs, inputs, ... }:

{
  imports = [
    "${inputs.self}/modules/steam.nix"
    "${inputs.self}/modules/docker.nix"
    (import "${inputs.self}/modules/openocd.nix" { inherit usernames; })
  ];

  programs.firefox.enable = true;
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    gcc
    clang
    rofi
    wlogout
  ];
}
