{pkgs, ...}: let
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    #!/usr/bin/env bash

    CHOICE=$(echo -e "Selection\nFull Screen" | ${pkgs.walker}/bin/walker --dmenu --placeholder "Screenshot")

    FILENAME=~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png

    case "$CHOICE" in
      "Selection")
        ${pkgs.grimblast}/bin/grimblast copysave area "$FILENAME"
        ;;
      "Full Screen")
        ${pkgs.grimblast}/bin/grimblast copysave screen "$FILENAME"
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
