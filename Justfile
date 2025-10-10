hostname := `hostname`

clean:
    nix-collect-garbage -d

nixos:
    sudo nixos-rebuild switch --flake .#{{hostname}}

nixos-test:
    sudo nixos-rebuild test --flake .#{{hostname}}

nixos-check:
    sudo nixos-rebuild dry-build --flake .#{{hostname}}

update:
    nix flake update
