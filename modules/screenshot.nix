{pkgs, ...}: let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    #!/usr/bin/env bash

    if [[ "''${1:-}" == "--fullscreen" ]]; then
      CHOICE="Full Screen"
    else
      CHOICE=$(echo -e "Selection\nFull Screen" | ${pkgs.rofi}/bin/rofi -dmenu -p "Screenshot")
    fi

    FILENAME=~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png

    case "$CHOICE" in
      "Selection")
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$FILENAME"
        ;;
      "Full Screen")
        if [[ "''${1:-}" != "--fullscreen" ]]; then
          # Let Rofi finish closing before Grim captures the whole screen.
          ${pkgs.coreutils}/bin/sleep 0.25
        fi
        ${pkgs.grim}/bin/grim "$FILENAME"
        ;;
      *)
        exit 1
        ;;
    esac

    ${pkgs.feh}/bin/feh "$FILENAME"
  '';
in {
  home.packages = [
    screenshot
  ];
}
