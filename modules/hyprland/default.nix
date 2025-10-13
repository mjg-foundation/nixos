{config, inputs, ...}: {
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = builtins.readFile "${inputs.self}/modules/hyprland/hyprland.conf";
  };
}
