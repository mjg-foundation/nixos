{...}: {
  virtualisation.docker = {
    enable = true;
  };

  users.users.matt.extraGroups = [ "docker" ];
}
