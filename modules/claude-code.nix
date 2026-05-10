{ lib, pkgs, ... }:

let
  # Plugins to enable. Each entry is "pluginName@marketplace".
  # Update this list when adding or removing plugins, then rebuild.
  plugins = [
    "commit-commands@claude-plugins-official"
    "context7@claude-plugins-official"
    "figma@claude-plugins-official"
    "github@claude-plugins-official"
    "linear@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "superpowers@claude-plugins-official"
  ];

  settingsContent = builtins.toJSON {
    enabledPlugins = builtins.listToAttrs (
      map (name: { inherit name; value = true; }) plugins
    );
  };

  nixSettings = pkgs.writeText "claude-settings.json" settingsContent;
in
{
  home.packages = [ pkgs.claude-code ];

  # Write ~/.claude/settings.json and a shadow copy (.nix-settings.json)
  # that records the last nix-declared state.  The Justfile check-claude-sync
  # recipe diffs the two files before every rebuild so local drift is caught
  # interactively rather than silently overwritten.
  #
  # Using home.activation (not home.file) so Claude Code can still write to
  # settings.json at runtime.  Rebuilding resets it to the declared state.
  home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.claude"
    $DRY_RUN_CMD cp --no-preserve=mode "${nixSettings}" "$HOME/.claude/settings.json"
    $DRY_RUN_CMD cp --no-preserve=mode "${nixSettings}" "$HOME/.claude/.nix-settings.json"
  '';
}
