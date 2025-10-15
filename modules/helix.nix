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
        auto-pairs = {
          "(" = ")";
          "{" = "}";
          "[" = "]";
        };
        clipboard-provider = "wayland";
      };

      keys.normal = {
        G = "goto_last_line";
      };
    };
  };
}
