{ pkgs, ... }:

let
  runner = pkgs.writeShellApplication {
    name = "roam-nixos-activity-runner";
    runtimeInputs = with pkgs; [ coreutils curl jq ];
    text = builtins.readFile ./roam-nixos-activity-runner.sh;
  };
in
{
  home.sessionVariablesExtra = ''
    if [ -r "''${XDG_CONFIG_HOME:-$HOME/.config}/roam/activity.env" ]; then
      . "''${XDG_CONFIG_HOME:-$HOME/.config}/roam/activity.env"
      export ROAM_USER_ID ROAM_ACCESS_TOKEN ROAM_SIGNING_SECRET

      # A user manager may be unavailable for non-graphical logins.
      ${pkgs.systemd}/bin/systemctl --user import-environment \
        ROAM_USER_ID ROAM_ACCESS_TOKEN ROAM_SIGNING_SECRET 2>/dev/null || true
    fi
  '';

  home.packages = [
    (pkgs.writeShellApplication {
      name = "roam-nixos-activity";
      runtimeInputs = with pkgs; [ rofi systemd ];
      text = ''
        set -euo pipefail

        if [ -z "''${ROAM_ACCESS_TOKEN:-}" ] || [ -z "''${ROAM_USER_ID:-}" ]; then
          rofi -e "Set ROAM_ACCESS_TOKEN and ROAM_USER_ID in ~/.config/roam/activity.env, then log in again."
          exit 1
        fi

        # Refresh immediately, then schedule refreshes for this login session.
        systemctl --user start roam-nixos-activity.service
        systemctl --user restart roam-nixos-activity.timer
      '';
    })
  ];

  home.file.".config/roam/activity.env.example".text = ''
    # Copy this file to activity.env and add your personal access token.
    # Keep activity.env private: chmod 600 ~/.config/roam/activity.env
    ROAM_USER_ID=replace-with-your-user-id
    ROAM_ACCESS_TOKEN=replace-with-your-token
    # Optional; needed only for webhook verification.
    ROAM_SIGNING_SECRET=
    # Log out and back in after changing these values.
  '';

  systemd.user.services.roam-nixos-activity = {
    Unit = {
      Description = "Publish NixOS activity to Roam";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${runner}/bin/roam-nixos-activity-runner";
    };
  };

  systemd.user.timers.roam-nixos-activity = {
    Unit = {
      Description = "Refresh NixOS activity in Roam";
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      OnActiveSec = "50min";
      OnUnitActiveSec = "50min";
      Persistent = false;
    };
  };
}
