{ usernames ? [] }:
{ lib, pkgs, ... }:

{
  users.groups.plugdev = {};

  users.users = lib.genAttrs usernames (_: {
    extraGroups = [ "plugdev" ];
  });

  services.udev.packages = [ pkgs.openocd ];
}
