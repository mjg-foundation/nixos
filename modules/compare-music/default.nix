{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "compare-music";
      runtimeInputs = [pkgs.python3];
      text = ''
        exec python3 ${./compare_music.py} "$@"
      '';
    })
  ];
}
