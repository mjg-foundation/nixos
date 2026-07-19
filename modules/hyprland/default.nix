{config, inputs, ...}: {
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    extraConfig = builtins.readFile "${inputs.self}/modules/hyprland/hyprland.conf";
  };
}
