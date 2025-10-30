{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "album-picker";
      runtimeInputs = with pkgs; [
        ffmpeg-headless
        kdePackages.kdialog
        cmus
        kitty
      ];
      text = builtins.readFile ./album-picker.sh;
    })
  ];
}
