{config, inputs, ...}: {
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
        modules-right = ["tray" "group/indicators" "cpu" "battery" "custom/clock"];

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

        "custom/separator" = {
          format = "│";
          tooltip = false;
        };

        cpu = {
          format = " {usage:02}%";
          tooltip = false;
          interval = 5;
        };

        battery = {
          format = "{icon} {capacity}%";
          format-icons = {
            default = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          };
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-full = "󰂅";
          tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
          tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";

          interval = 5;
          states = {
            warning = 20;
          };
        };

        "custom/clock" = {
          exec = "date '+%a %b %d %H:%M' | tr '[:upper:]' '[:lower:]'";
          interval = 10;
          tooltip = false;
        };

        pulseaudio = {
          format = "{icon}";
          on-click = "kitty --class wiremix wiremix";
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
          spacing = 1;
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
          spacing = 8;
        };
      };
    };
  };
}
