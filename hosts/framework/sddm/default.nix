{ lib, pkgs, inputs, ... }:

let
  whiteMenuButton = {
    background-color = "#FFFFFF";
    background-opacity = 0.90;
    active-background-opacity = 0.90;
    content-color = "#000000";
    active-content-color = "#000000";
  };

  silentTheme =
    (inputs.silentSDDM.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      theme = "default";
      extraBackgrounds = [ ./mii_channel.jpg ];
      theme-overrides = {
        "General".background-fill-mode = "stretch";
        "LockScreen" = {
          background = "mii_channel.jpg";
          blur = 0;
          brightness = 0;
        };
        "LoginScreen" = {
          background = "mii_channel.jpg";
          blur = 0;
          brightness = 0;
        };
        "LockScreen.Clock".display = false;
        "LockScreen.Date".display = false;
        "LockScreen.Message" = {
          position = "center";
          font-family = "M+ 1c";
          color = "#000000";
          pill-color = "#FFFFFF";
          pill-opacity = 0.90;
          pill-horizontal-padding = 32;
          pill-vertical-padding = 12;
          spacing = 10;
        };
        "LoginScreen.LoginArea.Username".font-family = "M+ 1c";
        "LoginScreen.LoginArea.Username".color = "#000000";
        "LoginScreen.LoginArea.Username".margin = 18;
        "LoginScreen.LoginArea".vertical-offset = 30;
        "LoginScreen.LoginArea.Avatar" = {
          active-size = 96;
          inactive-size = 64;
        };
        "LoginScreen.LoginArea.PasswordInput" = {
          font-family = "M+ 1c";
          content-color = "#000000";
          background-color = "#FFFFFF";
          background-opacity = 0.90;
          border-radius-left = 15;
          border-radius-right = 15;
          margin-top = 18;
        };
        "LoginScreen.LoginArea.LoginButton" = {
          font-family = "M+ 1c";
          content-color = "#000000";
          active-content-color = "#000000";
          background-color = "#FFFFFF";
          background-opacity = 0.90;
          active-background-color = "#FFFFFF";
          active-background-opacity = 0.90;
          border-radius-left = 15;
          border-radius-right = 15;
        };
        "LoginScreen.LoginArea.Spinner".font-family = "M+ 1c";
        "LoginScreen.LoginArea.WarningMessage".font-family = "M+ 1c";
        "LoginScreen.MenuArea.Buttons" = {
          margin-top = 65;
          margin-right = 65;
          margin-bottom = 65;
          margin-left = 65;
          size = 30;
          border-radius = 15;
          font-family = "M+ 1c";
        };
        "LoginScreen.MenuArea.Session" = whiteMenuButton;
        "LoginScreen.MenuArea.Layout" = whiteMenuButton;
        "LoginScreen.MenuArea.Keyboard" = whiteMenuButton;
        "LoginScreen.MenuArea.Power" = whiteMenuButton;
        "LoginScreen.MenuArea.Popups" = {
          background-color = "#FFFFFF";
          background-opacity = 0.80;
          content-color = "#000000";
          active-option-background-color = "#FFFFFF";
          active-option-background-opacity = 0.90;
          active-content-color = "#000000";
          border-size = 0;
          font-family = "M+ 1c";
        };
        "Tooltips" = {
          background-color = "#FFFFFF";
          background-opacity = 0.90;
          content-color = "#000000";
          border-radius = 15;
          horizontal-padding = 14;
          font-family = "M+ 1c";
        };
      };
    }).overrideAttrs (old: {
      installPhase = old.installPhase + ''
        chmod -R u+w $out/share/sddm/themes/silent
        cd $out/share/sddm/themes/silent
        patch -p1 --no-backup-if-mismatch < ${./lock-message-pill.patch}
        patch -p1 --no-backup-if-mismatch < ${./login-ui-style.patch}
        patch -p1 --no-backup-if-mismatch < ${./tooltip-padding.patch}
        find . -name '*.qml' -type f -exec sed -i 's/[[:blank:]]*$//' {} +
      '';
    });
in {

  fonts.packages = [ pkgs.mplus-outline-fonts.osdnRelease ];

  environment.systemPackages = [ silentTheme silentTheme.test ];
  qt.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = lib.mkForce true;
    theme = "silent";
    extraPackages = silentTheme.propagatedBuildInputs;
    settings.General = {
      GreeterEnvironment = "QML2_IMPORT_PATH=${silentTheme}/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard";
      InputMethod = "qtvirtualkeyboard";
    };
  };
}
