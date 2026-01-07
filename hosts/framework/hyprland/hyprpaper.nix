{config, pkgs, inputs, ...}: {
  services.hyprpaper.enable = false;

  # Manually create hyprpaper config with correct syntax
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    ipc = on
    splash = false

    wallpaper {
      monitor = eDP-1
      path = ${inputs.self}/hosts/framework/hyprland/wii_menu_2256x1504.png
      fit_mode = cover
    }

    wallpaper {
      monitor = DP-3
      path = ${inputs.self}/hosts/framework/hyprland/take_a_break_1920x1080.png
      fit_mode = cover
    }

    wallpaper {
      monitor = DP-2
      path = ${inputs.self}/hosts/framework/hyprland/take_a_break_1920x1080.png
      fit_mode = cover
    }
  '';

  # Create systemd service to run hyprpaper
  systemd.user.services.hyprpaper = {
    Unit = {
      Description = "hyprpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
