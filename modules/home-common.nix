{ userName, userEmail }:
{ inputs, ... }:

{
  imports = [
    (import "${inputs.self}/modules/git.nix" { inherit userName userEmail; })
    "${inputs.self}/modules/home-packages.nix"
    "${inputs.self}/modules/waybar/default.nix"
    "${inputs.self}/modules/kitty.nix"
    "${inputs.self}/modules/rust.nix"
    "${inputs.self}/modules/album-picker/default.nix"
    "${inputs.self}/modules/reminder/default.nix"
    "${inputs.self}/modules/screenshot.nix"
    "${inputs.self}/modules/neovim.nix"
    "${inputs.self}/modules/claude-code.nix"
    "${inputs.self}/modules/python.nix"
    "${inputs.self}/modules/cmus-queue-stash.nix"
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;

  programs.cmusQueueStash = {
    enable = true;
    startCommand = "kitty -e cmus";
  };
}
