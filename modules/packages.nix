{pkgs, ...}: {
  home.packages = with pkgs; [
    just
    gh
    ffmpeg
    rustup
    cmake
    screenfetch
    xclip
    baobab
    kitty
  ];
}
