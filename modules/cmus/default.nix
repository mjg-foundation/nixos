{ ... }: {
  programs.cmus = {
    enable = true;
    extraConfig = ''
      set resume=true
    '';
  };
}
