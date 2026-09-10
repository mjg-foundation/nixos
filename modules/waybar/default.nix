{config, inputs, pkgs, ...}: let
  ai-usagebar = inputs.ai-usagebar.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  home.packages = [ai-usagebar];

  xdg.configFile."ai-usagebar/config.toml".text = ''
    [ui]
    primary = "openai"
  '';

  programs.waybar = {
    enable = true;
    style = builtins.readFile "${inputs.self}/modules/waybar/style.css";

    settings = {
      mainBar = {
        layer = "top";
        position = "bottom";
        height = 30;

        modules-left = ["hyprland/workspaces"];
        modules-center = [];
        modules-right = ["custom/player-status" "tray" "group/indicators" "custom/ai-usagebar" "cpu" "custom/battery-status" "custom/clock"];

        "group/indicators" = {
          orientation = "horizontal";
          modules = ["bluetooth" "network" "pulseaudio"];
        };

        "hyprland/workspaces" = {
          disable-scroll = false;
          # all-outputs = true;
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          format = "{name}";
          format-icons = {
            urgent = "";
            active = "";
            default = "";
          };
        };

        "hyprland/window" = {
          format = "{}";
          separate-outputs = true;
          max-length = 50;
        };

        # "custom/separator" = {
        #   format = "│";
        #   tooltip = false;
        # };

        "custom/ai-usagebar" = {
          exec = "${pkgs.python3}/bin/python3 ${./codex-status.py} ${ai-usagebar}/bin/ai-usagebar ${pkgs.hyprland}/bin/hyprctl";
          return-type = "json";
          restart-interval = 5;
          tooltip = true;
          on-click = "${pkgs.kitty}/bin/kitty --class ai-usagebar ${ai-usagebar}/bin/ai-usagebar-tui";
          on-click-right = "${pkgs.python3}/bin/python3 ${./codex-status.py} --focus-waiting ${pkgs.hyprland}/bin/hyprctl";
        };

        cpu = {
          format = "  {usage:02}%";
          tooltip = false;
          interval = 5;
          on-click = "plasma-systemmonitor";
        };

        "custom/battery-status" = {
          exec = "battery-status";
          interval = 5;
          return-type = "json";
          on-click = "power-profile";
        };

        "custom/clock" = {
          exec = "date '+%a %b %d %H:%M' | tr '[:upper:]' '[:lower:]'";
          interval = 10;
          tooltip = false;
        };

        "custom/player-status" = {
          exec = "bash ${inputs.self}/modules/waybar/player-status.sh";
          interval = 2;
          on-click = "album-picker";
          tooltip = false;
        };

        pulseaudio = {
          format = "{icon} ";
          on-click = "kitty --class wiremix wiremix";
          on-right-click = "album-picker";
          tooltip-format = "Playing at {volume}%";
          scroll-step = 5;
          format-muted = "󰝟";
          format-icons = {
            "default" = ["" "" ""];
          };
        };

        network = {
          on-click = "kitty --class nmtui nmtui";
          format-icons = ["󰤯" "󰤟" "󰤢" "󰤥" "󰤨"];
          format = "{icon}";
          format-wifi = "{icon}";
          format-ethernet = "󰀂";
          format-disconnected = "󰖪";
          tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-disconnected = "disconnected";
          interval = 3;
          spacing = 2;
        };

        bluetooth = {
          format = "";
          format-disabled = "󰂲";
          format-connected = "";
          tooltip-format = "devices connected= {num_connections}";
          on-click = "kitty --class bluetui bluetui";
        };

        tray = {
          icon-size = 14;
          spacing = 20;
        };
      };
    };
  };
}
