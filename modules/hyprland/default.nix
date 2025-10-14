{config, inputs, ...}: {
  imports = [
    "${inputs.self}/modules/hyprland/hyprpaper.nix"
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile "${inputs.self}/modules/hyprland/hyprland.conf";
  };
}
