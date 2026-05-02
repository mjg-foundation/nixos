{pkgs, ...}: {
  home.packages = with pkgs; [
    (python314.withPackages (ps: with ps; [
      pip
      numpy
      matplotlib
      jupyter
      pyaudio
    ]))
  ];
}
