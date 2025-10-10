hostname := `hostname`

clean:
    nix-collect-garbage -d

nixos:
    @if [ -n "$(git status --porcelain)" ]; then \
        echo "error: pending git changes"; \
        exit 1; \
    fi
    sudo nixos-rebuild switch --flake .#{{hostname}}

nixos-test:
    sudo nixos-rebuild test --flake .#{{hostname}}

nixos-check:
    sudo nixos-rebuild dry-build --flake .#{{hostname}}

update:
    nix flake update
