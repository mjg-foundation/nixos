{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "keybinds";
      runtimeInputs = with pkgs; [
        gawk
        rofi
      ];
      text = builtins.readFile ./keybinds.sh;
    })
  ];
}
