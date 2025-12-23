{
  lib,
  pkgs,
  config,
  ...
}: {
  programs.helix = {
    settings = {
      theme = "gruvbox_dark_hard";
    };
  };
}
