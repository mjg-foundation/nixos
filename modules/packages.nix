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
    git
    helix
    ripgrep
    bluetui
    brightnessctl
    vlc
    jmtpfs
    usbutils
    # cutecom
    obs-studio
    sparrow
    inlyne
    feh
    file
    imagemagick
    gimp2
    wiremix
    cmus
    nautilus
    unzip
    gscreenshot
    slurp
    grim
  ];
}
