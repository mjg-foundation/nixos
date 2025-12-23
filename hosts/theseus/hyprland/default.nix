{config, inputs, ...}: {
  imports = [
    "${inputs.self}/modules/hyprland/default.nix"
    "${inputs.self}/hosts/theseus/hyprland/hyprpaper.nix"
  ];

  wayland.windowManager.hyprland = {
    extraConfig =
    ''
################
### MONITORS ###
################

# See https://wiki.hypr.land/Configuring/Monitors/
# This confused me for a bit, to place my second monitor (DP-3) to the
# left and allow the mouse to move between the two, I needed to
# position the main monitor at coordinates relative to the second
# monitor's resolution divided by its scaling, so
# 1920 / 1.2 = 1600. Adjust accordingly if editing.
# Use `hyprctl monitors all` to find monitor names and resolutions
monitor=eDP-1, preferred, 1920x0, 1.6
monitor=DP-1, 1920x1080, 3330x0, 1

##################
### AUTO START ###
##################
exec-once = hyprpaper
    '';
  };
}
