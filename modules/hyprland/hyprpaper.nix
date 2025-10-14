{config, inputs, ...}: {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      preload = [ "${inputs.self}/modules/hyprland/wii_menu_3.png" ];
      wallpaper = [", ${inputs.self}/modules/hyprland/wii_menu_3.png"];
    };
  };
}
