{ pkgs, ... }: {
  home.packages = [ pkgs.playerctl ];

  programs.cmus.extraConfig = ''
    set mpris=true
  '';

  systemd.user.services.playerctld = {
    Unit.Description = "Track the active MPRIS media player";
    Service = {
      ExecStart = "${pkgs.playerctl}/bin/playerctld daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
