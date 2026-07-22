{ lib, inputs, ... }:

{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  services.displayManager.sddm = {
    enable = true;
    # The X11 greeter has one 96-DPI canvas for the complete desktop, so it
    # cannot choose a scale independently for the laptop panel and DP-1.
    # KWin's Wayland greeter can apply the output scale per monitor.
    wayland.enable = lib.mkForce true;
  };

  programs.silentSDDM = {
    enable = true;
    theme = "default";
  };
}
