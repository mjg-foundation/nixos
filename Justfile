hostname := `hostname`

# Preserves previous generations in a fibonacci pattern
clean:
    #!/usr/bin/env bash
    gens=($(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep -oE '^[[:space:]]*[0-9]+' | tr -d ' ' | sort -nr))
    gens_length=${#gens[@]}

    fibs=(0 1 2)
    while true; do
        fibs_length=${#fibs[@]}
        last_index=${fibs[$fibs_length - 1]}
        prev_index=${fibs[$fibs_length - 2]}
        next=$(( last_index + prev_index ))

        if [ "$next" -ge "$gens_length" ]; then
            break
        fi

        fibs+=($next)
    done

    fibs_length=${#fibs[@]}

    delete=()
    i=0
    next_fib=0
    next_keep=${fibs[$next_fib]}

    while [ $i -lt $gens_length ]; do
        if [[ "$i" -eq "$next_keep" ]]; then
            i=$((next_keep + 1))
            next_fib=$(( next_fib + 1 ))
            next_keep=${fibs[$next_fib]}
        else
            delete+=(${gens[$i]})
            i=$((i + 1))
        fi
    done

    if [ ${#delete[@]} == 0 ]; then
        echo "No gens to delete."
        exit 1
    fi

    echo "Current gens: ${gens[*]}"
    echo "Delete these gens: ${delete[*]} ?"
    read -rp "[y/n]: " confirm
    case "$confirm" in
        [yY])
            sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations ${delete[*]}
            sudo nix-collect-garbage
            sudo nixos-rebuild boot --flake .#{{hostname}}
            ;;
        *)
            echo "canceled"
            ;;
    esac

# Checks whether ~/.claude/settings.json has drifted from the last nix-declared
# state.  If it has, shows a diff and prompts before proceeding.  Run this
# before any rebuild that would overwrite local Claude Code settings.
check-claude-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    SETTINGS="$HOME/.claude/settings.json"
    SHADOW="$HOME/.claude/.nix-settings.json"

    if [ ! -f "$SETTINGS" ] || [ ! -f "$SHADOW" ]; then
        exit 0
    fi

    LOCAL=$(jq --sort-keys . "$SETTINGS" 2>/dev/null || echo "")
    NIX=$(jq --sort-keys . "$SHADOW" 2>/dev/null || echo "")

    if [ "$LOCAL" = "$NIX" ]; then
        exit 0
    fi

    echo ""
    echo "~/.claude/settings.json has local changes not synced to nix config:"
    echo "(left = nix-declared, right = local)"
    echo ""
    diff <(echo "$NIX") <(echo "$LOCAL") || true
    echo ""
    echo "To keep local changes, update modules/claude-code.nix before rebuilding."
    echo ""
    read -rp "Overwrite local settings with nix config and continue? [y/N] " confirm
    case "$confirm" in
        [yY]) ;;
        *) echo "Rebuild aborted: unsynced Claude Code settings."; exit 1 ;;
    esac

# Rebuilds Nixos
nixos: check-claude-sync
    sudo nixos-rebuild switch --flake .#{{hostname}}

nixos-test: check-claude-sync
    sudo nixos-rebuild test --flake .#{{hostname}}

nixos-check:
    sudo nixos-rebuild dry-build --flake .#{{hostname}}

update:
    nix flake update
