{config, inputs, ...}: {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      # Use `hyprctl monitors all` to find monitor names and resolutions
      preload = [
        "${inputs.self}/hosts/theseus/hyprland/luca-bravo-ii5JY_46xH0-unsplash.jpg"
      ];
      wallpaper = [
        "eDP-1, ${inputs.self}/hosts/theseus/hyprland/luca-bravo-ii5JY_46xH0-unsplash.jpg"
        "DP-1, ${inputs.self}/hosts/theseus/hyprland/luca-bravo-ii5JY_46xH0-unsplash.jpg"
      ];
    };
  };
}
