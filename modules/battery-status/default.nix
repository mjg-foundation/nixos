{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "battery-status";
      runtimeInputs = with pkgs; [
        gawk
        power-profiles-daemon
        upower
      ];
      text = builtins.readFile ./battery-status.sh;
    })
  ];
}
