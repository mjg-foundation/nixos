{ config, lib, pkgs, ... }:

let
  cfg = config.programs.cmusQueueStash;

  stashScript = pkgs.writeShellApplication {
    name = "cmus-stash-queue";
    runtimeInputs = [ pkgs.cmus pkgs.coreutils pkgs.gnused ];
    text = ''
      set -euo pipefail

      mkdir -p "$(dirname "${cfg.stashFile}")"

      tmp="$(mktemp)"
      queue_tmp="$(mktemp)"
      trap 'rm -f "$tmp" "$queue_tmp"' EXIT

      current="$(${pkgs.cmus}/bin/cmus-remote -Q | sed -n 's/^file //p' | head -n1 || true)"

      ${pkgs.cmus}/bin/cmus-remote -C "save -q $queue_tmp" || true

      : > "$tmp"

      if [ -n "$current" ]; then
        printf '%s\n' "$current" >> "$tmp"
      fi

      if [ -s "$queue_tmp" ]; then
        grep -Fvx "$current" "$queue_tmp" >> "$tmp" || true
      fi

      mv "$tmp" "${cfg.stashFile}"

      ${pkgs.cmus}/bin/cmus-remote -C quit
    '';
  };

  restoreScript = pkgs.writeShellApplication {
    name = "cmus-restore-queue";
    runtimeInputs = [ pkgs.cmus pkgs.coreutils ];
    text = ''
      set -euo pipefail

      if [ ! -f "${cfg.stashFile}" ]; then
        echo "No stash file found: ${cfg.stashFile}" >&2
        exit 1
      fi

      ${cfg.startCommand} &

      # Wait for cmus to accept remote commands.
      for _ in $(seq 1 50); do
        if ${pkgs.cmus}/bin/cmus-remote -Q >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done

      ${pkgs.cmus}/bin/cmus-remote -C "clear -q" || true

      first=""
      while IFS= read -r file; do
        [ -z "$file" ] && continue

        if [ -z "$first" ]; then
          first="$file"
        fi

        ${pkgs.cmus}/bin/cmus-remote -q "$file"
      done < "${cfg.stashFile}"

      if [ -n "$first" ]; then
        ${pkgs.cmus}/bin/cmus-remote -n
        ${pkgs.cmus}/bin/cmus-remote -p
      fi
    '';
  };
in
{
  options.programs.cmusQueueStash = {
    enable = lib.mkEnableOption "cmus queue stash/restore scripts";

    stashFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/cmus/queue-stash.txt";
      description = "File used to save the current cmus song and queue.";
    };

    startCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.kitty}/bin/kitty -e ${pkgs.cmus}/bin/cmus";
      description = "Command used to launch cmus before restoring the queue.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.cmus
      stashScript
      restoreScript
    ];
  };
}
