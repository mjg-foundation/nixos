{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "reminder";
      runtimeInputs = with pkgs; [
        kdePackages.kdialog
      ];
      text = builtins.readFile ./reminder.sh;
    })
  ];
}
