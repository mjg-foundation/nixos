{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.codex-nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex
  ];

  home.file.".codex/AGENTS.md".source = ./AGENTS.md;
  home.file.".agents/skills/technical-writing/SKILL.md".source =
    ./skills/technical-writing/SKILL.md;
}
