# My NixOS

This is a NixOS configuration with Hyprland, Waybar, the Rofi launcher, and Brave.

## Installation
This config doesn't assume it's in /etc/nixos, so you'll see some import paths starting with `${inputs.self}` to reach the root of the repo automatically.

    git clone git@github.com:mjg-foundation/nixos.git
    cd nixos

Replace the hostnames, usernames, and hardware-configuration.nix with your own, then

    sudo nixos-rebuild switch --flake .#$(hostname)

Afterwards, `just` will be installed, so future rebuilds can be done with `just nixos`. All commands can be listed with `just --list`.

## Customization
Host-specific settings live under `hosts/<host>/`. For example, monitor layouts are set in `hosts/<host>/hyprland/default.nix`, wallpapers in `hosts/<host>/hyprland/hyprpaper.nix`, and host-specific Kitty, Git, Cmus, and Neovim settings have their own files.

## Keymaps
You can inspect all keymaps at `modules/hyprland/hyprland.conf`, but these are the basics:

- mod + shift + q: kill active window
- mod + space: Rofi launcher
- mod + b: brave browser
- mod + shift + e: exit hyprland
- mod + enter: kitty terminal
- mod + j: swap window splits
- mod + shift + arrow keys: swap adjacent windows
- mod + f: fullscreen active window
- mod + p: pick a random album
- mod + shift + p: shutdown menu
- mod + click: drag and move windows
- mod + shift + b: bluetui
- mod + shift + w: nmtui
- mod + ?: show keybindings

## Aliases
These shell aliases are defined in shared Home Manager modules:

- `vim` = `nvim` (`modules/neovim.nix`)
- `git_diff_parallel` = `git difftool -x difft` (`modules/git.nix`)

## Shortcuts
These environment variables help me jump to frequently visited directories. They are username-specific, so modify or replace them as needed. They are defined in `hosts/<host>/configuration.nix`:

- $KEYOS = ~/Projects/KeyOS
- $NIX = ~/nix\_config
- $NGWALLET = ~/Projects/ngwallet
- $ROOT_PASSPORT = ~/Projects/passport2
- $PASSPORT = ~/Projects/passport2/ports/stm32/boards/Passport

## File Structure
```
nix_config/
├── flake.nix                     # Declares inputs and the framework/theseus hosts
├── flake.lock                    # Pinned input versions; update with `nix flake update`
├── Justfile                      # Rebuild, check, clean, and update recipes
├── README.md
├── modules/                      # Shared NixOS and Home Manager modules
│   ├── system-common.nix          # Common system configuration
│   ├── system-packages.nix        # System packages and system-level modules
│   ├── home-common.nix            # Common Home Manager imports
│   ├── home-packages.nix          # Shared user packages
│   ├── keybinds/                   # Rofi keybinding reference
│   ├── cmus/                       # Shared Cmus configuration
│   ├── mpris.nix                   # Playerctl and MPRIS integration
│   ├── hyprland/
│   │   ├── default.nix            # Loads the shared Hyprland configuration
│   │   └── hyprland.conf          # Shared Hyprland settings and keybindings
│   ├── waybar/                    # Waybar configuration, styling, and Cmus status script
│   ├── album-picker/              # Album picker module and script
│   ├── reminder/                  # Reminder module and script
│   └── *.nix                      # Focused modules (Git, Kitty, Neovim, Rust, etc.)
└── hosts/                         # Per-machine system and Home Manager configuration
    ├── framework/
    │   ├── configuration.nix      # NixOS configuration and machine-specific variables
    │   ├── hardware-configuration.nix
    │   ├── home.nix               # Combines shared and host-specific Home Manager modules
    │   ├── {cmus,git,kitty,neovim}.nix
    │   └── hyprland/              # Monitor layout, wallpaper configuration, and images
    └── theseus/                   # Same layout for the theseus machine
```
