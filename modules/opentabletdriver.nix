{ pkgs, ... }:

{
  # OpenTabletDriver runs in userspace and needs uinput for event injection.
  hardware.opentabletdriver.enable = true;
  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];
}
