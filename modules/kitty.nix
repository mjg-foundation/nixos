{config, ...}: {
  programs.kitty = {
    enable = true;
    enableGitIntegration = true;
    shellIntegration.enableBashIntegration = false;
    settings = {
      enable_audio_bell = false;
      confirm_os_window_close = 0;
      background_opacity = "0.9";
    };
  };
}
