{ lib, pkgs, inputs, ... }:

{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  fonts.packages = [ pkgs.mplus-outline-fonts.osdnRelease ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = lib.mkForce true;
  };

  programs.silentSDDM = {
    enable = true;
    theme = "default";
    backgrounds.mii-channel = ./mii_channel.jpg;
    settings = {
      "General".background-fill-mode = "stretch";
      "LockScreen" = {
        background = "mii_channel.jpg";
        # Replace the theme's initial blur with a readable, translucent-black
        # treatment that carries through to the password screen.
        blur = 0;
        brightness = -0.35;
      };
      "LoginScreen" = {
        background = "mii_channel.jpg";
        blur = 0;
        brightness = -0.35;
      };
      "LockScreen.Clock".font-family = "M+ 1c";
      "LockScreen.Date".font-family = "M+ 1c";
      "LockScreen.Message".font-family = "M+ 1c";
      "LoginScreen.LoginArea.Username".font-family = "M+ 1c";
      "LoginScreen.LoginArea.PasswordInput".font-family = "M+ 1c";
      "LoginScreen.LoginArea.LoginButton".font-family = "M+ 1c";
      "LoginScreen.LoginArea.Spinner".font-family = "M+ 1c";
      "LoginScreen.LoginArea.WarningMessage".font-family = "M+ 1c";
    };
  };
}
