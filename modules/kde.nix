{ pkgs, ... }:

{
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [
    pkgs.kdePackages.sddm-kcm
    pkgs.kdePackages.knewstuff
    pkgs.qt6.qtmultimedia
  ];
}
