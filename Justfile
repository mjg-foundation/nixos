hostname := `hostname`

# Preserves previous generations in a fibonacci pattern
clean:
    #!/usr/bin/env bash
    current=$(nix-env --list-generations | grep current | awk '{print $1}')

    if [[ -z "$current" ]]; then
        echo "Could not determine current generation."
        exit 1
    fi

    gens=($(nix-env --list-generations | grep -oE '^[[:space:]]*[0-9]+' | tr -d ' ' | sort -nr))
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
            nix-env --delete-generations "${delete[*]}"
            ;;
        *)
            echo "canceled"
            ;;
    esac

# Rebuilds Nixos
nixos:
    sudo nixos-rebuild switch --flake .#{{hostname}}

nixos-test:
    sudo nixos-rebuild test --flake .#{{hostname}}

nixos-check:
    sudo nixos-rebuild dry-build --flake .#{{hostname}}

update:
    nix flake update
