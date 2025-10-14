{config, inputs, ...}: {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      # Use `hyprctl monitors all` to find monitor names and resolutions
      preload = [
        "${inputs.self}/hosts/framework/hyprland/wii_menu_2256x1504.png"
        "${inputs.self}/hosts/framework/hyprland/wii_menu_1920x1080.png"
      ];
      wallpaper = [
        "eDP-1, ${inputs.self}/hosts/framework/hyprland/wii_menu_2256x1504.png"
        "DP-3, ${inputs.self}/hosts/framework/hyprland/wii_menu_1920x1080.png"
      ];
    };
  };
}
