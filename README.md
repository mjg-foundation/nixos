# My NixOS

This a decent starter NixOS config, with hyprland as the WM, waybar, walker launcher, and brave browser.

## Installation
This config doesn't assume it's in /etc/nixos, so you'll see some import paths starting with `${inputs.self}` to reach the root of the repo automatically.

    git clone git@github.com:mjg-foundation/nixos.git
    cd nixos

Replace the hostnames and usernames with your own, then

    sudo nixos-rebuild switch --flake .#\`hostname\`

Afterwards, `just` will be installed, so future rebuilds can be done with `just nixos`.

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
