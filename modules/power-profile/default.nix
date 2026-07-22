{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "power-profile";
      runtimeInputs = with pkgs; [
        power-profiles-daemon
        rofi
      ];
      text = builtins.readFile ./power-profile.sh;
    })
  ];
}
