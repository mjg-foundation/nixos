{config, pkgs, inputs, ...}: {
  services.hyprpaper.enable = false;

  # Manually create hyprpaper config with correct syntax
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    ipc = on
    splash = false

    wallpaper {
      monitor = eDP-1
      path = ${inputs.self}/hosts/theseus/hyprland/luca-bravo-ii5JY_46xH0-unsplash.jpg
      fit_mode = cover
    }

    wallpaper {
      monitor = DP-1
      path = ${inputs.self}/hosts/theseus/hyprland/luca-bravo-ii5JY_46xH0-unsplash.jpg
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
