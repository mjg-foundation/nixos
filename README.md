# My NixOS

This a decent starter NixOS config, with hyprland as the WM, waybar, walker launcher, and brave browser.

## Installation
This config doesn't assume it's in /etc/nixos, so you'll see some import paths starting with `${inputs.self}` to reach the root of the repo automatically.

    git clone git@github.com:mjg-foundation/nixos.git
    cd nixos

Replace the hostnames, usernames, and hardware-configuration.nix with your own, then

    sudo nixos-rebuild switch --flake .#\`hostname\`

Afterwards, `just` will be installed, so future rebuilds can be done with `just nixos`. All commands can be listed with `just --list`.

## Customization
I've tried to keep host-specific things in each host, so for example, monitor resolutions are set in `hosts/<framework>/hyprland/default.nix`, wallpapers can be adjusted in `hosts/<host>/hyprland/hyprpaper.nix`, and various themes are set in modules in each host directory.

## Keymaps
You can inspect all keymaps at `modules/hyprland/hyprland.conf`, but these are the basics:
- mod + shift + q: kill active window
- mod + space: walker launcher
- mod + b: brave browser
- mod + shift + e: exit hyprland
- mod + enter: kitty terminal
- mod + j: swap window splits
- mod + arrow keys: swap adjacent windows
- mod + f: fullscreen active window

## File Structure
```
nix_config/
├─flake.nix: defines hosts and package versioning
├─flake.lock: do not edit, specifies exact working package versions
├─Justfile: useful commands for nixos, run just --list for more info
├─README.md: add any new installation details here
├─modules/: home manager modules that are useful to every host
│ ├─packages.nix: easy place to install common packages
│ └─hyprland/: hyprland common config, note use of a directory for multi-file modules
│   ├─default.nix: hyprland root config, imports hyprland.conf
│   └─hyprland.conf: default hyprland config with added keybinds
└─hosts/: all hosts and host-specific configurations
  └─framework/: my main host, has the latest changes
    ├─configuration.nix: inherited and modified default nixos config
    ├─hardware-configuration.nix: replace with your own after copying a host
    ├─home.nix: imports common and host-specific modules
    ├─git.nix: includes a gpg key ID you should replace
    └─hyprland/: host-specific resolutions and wallpapers
      ├─default.nix: sets monitor positions and resolutions
      └─hyprpaper.nix: sets wallpapers
```
