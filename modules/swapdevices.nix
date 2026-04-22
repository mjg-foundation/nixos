{ megabytes ? 32 * 1024 }:
{ ... }:

{
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = megabytes;
    }
  ];
}
