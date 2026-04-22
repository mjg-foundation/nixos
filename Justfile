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

# Checks whether Claude Code plugins have drifted from the nix-declared state.
# Compares both settings.json (enabledPlugins) and installed_plugins.json
# against the shadow file written by the last activation.  Prompts to reconcile
# before any rebuild that would overwrite local state.
check-claude-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    SETTINGS="$HOME/.claude/settings.json"
    SHADOW="$HOME/.claude/.nix-settings.json"
    INSTALLED="$HOME/.claude/plugins/installed_plugins.json"

    if [ ! -f "$SHADOW" ]; then
        exit 0
    fi

    dirty=0

    # Check 1: settings.json enabledPlugins vs nix-declared enabledPlugins
    if [ -f "$SETTINGS" ]; then
        LOCAL=$(jq --sort-keys . "$SETTINGS")
        NIX=$(jq --sort-keys . "$SHADOW")
        if [ "$LOCAL" != "$NIX" ]; then
            echo ""
            echo "~/.claude/settings.json has drifted from nix config:"
            echo "(- nix-declared  + local)"
            diff <(echo "$NIX") <(echo "$LOCAL") || true
            dirty=1
        fi
    fi

    # Check 2: installed plugins not declared in nix config
    if [ -f "$INSTALLED" ]; then
        INSTALLED_KEYS=$(jq -r '.plugins | keys[]' "$INSTALLED" | sort)
        NIX_KEYS=$(jq -r '.enabledPlugins | keys[]' "$SHADOW" | sort)
        EXTRA=$(comm -23 <(echo "$INSTALLED_KEYS") <(echo "$NIX_KEYS"))
        if [ -n "$EXTRA" ]; then
            echo ""
            echo "Plugins installed locally but not declared in nix config:"
            echo "$EXTRA" | sed 's/^/  /'
            dirty=1
        fi
    fi

    if [ "$dirty" = "0" ]; then
        exit 0
    fi

    echo ""
    echo "  [O] Overwrite  — discard local changes, rebuild with nix config"
    echo "  [M] Merge      — add local plugins to modules/claude-code.nix, then rebuild"
    echo "  [Q] Quit       — abort so you can reconcile manually"
    echo ""
    read -rp "Choice [O/M/Q]: " choice
    case "$choice" in
        [oO])
            echo "Overwriting local state with nix config."
            ;;
        [mM])
            CLAUDE_NIX="{{justfile_directory()}}/modules/claude-code.nix"
            # Union of nix-declared and all locally installed plugin names
            NIX_KEYS=$(jq -r '.enabledPlugins | keys[]' "$SHADOW" | sort)
            INST_KEYS=$([ -f "$INSTALLED" ] && jq -r '.plugins | keys[]' "$INSTALLED" | sort || true)
            ALL_KEYS=$(sort -u <(echo "$NIX_KEYS") <(echo "$INST_KEYS"))
            # Write merged plugin entries to a temp file for awk to read
            TMPLIST=$(mktemp)
            while IFS= read -r p; do
                [ -n "$p" ] && printf '    "%s"\n' "$p" >> "$TMPLIST"
            done <<< "$ALL_KEYS"
            # Replace the plugins = [ ... ]; block in modules/claude-code.nix
            awk '/plugins = \[/ { in_list=1; print; next }
                 in_list && /\];/ { in_list=0;
                     while ((getline line < pfile) > 0) print line;
                     close(pfile); print; next }
                 in_list { next }
                 { print }' pfile="$TMPLIST" "$CLAUDE_NIX" > "${CLAUDE_NIX}.tmp"
            mv "${CLAUDE_NIX}.tmp" "$CLAUDE_NIX"
            rm "$TMPLIST"
            echo "Updated $CLAUDE_NIX."
            ;;
        *)
            echo "Rebuild aborted."
            exit 1
            ;;
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
