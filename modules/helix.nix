{
  lib,
  pkgs,
  config,
  ...
}: {
  programs.helix = {
    enable = true;

    settings = {
      theme = "gruvbox_dark_hard";
      editor = {
        search = {
          smart-case = false;
        };
        soft-wrap = {
          enable = true;
        };
      };
    };
  };
}
