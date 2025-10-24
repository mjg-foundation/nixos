{ pkgs, ... }: {
  home.packages = with pkgs; [
    rustup
  ];

  home.file.".cargo/config.toml".text = ''
    [net]
    git-fetch-with-cli = true
  '';
}
