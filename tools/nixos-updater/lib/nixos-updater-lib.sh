#!/usr/bin/env bash
#
# NixOS Updater Library
# Reusable functions for NixOS system updates
# Can be sourced by other scripts for integration

# Prevent double-sourcing
[[ -n "${NIXOS_UPDATER_LIB_LOADED:-}" ]] && return 0
readonly NIXOS_UPDATER_LIB_LOADED=1

#############################################################################
# System Information Functions
#############################################################################

nixos_get_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

nixos_get_codename() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${VERSION_CODENAME:-unknown}"
    else
        echo "unknown"
    fi
}

nixos_is_flake() {
    [[ -f "/etc/nixos/flake.nix" ]] || [[ -f "$HOME/.config/nixos/flake.nix" ]]
}

nixos_get_config_path() {
    if [[ -f "/etc/nixos/flake.nix" ]]; then
        echo "/etc/nixos"
    elif [[ -f "$HOME/.config/nixos/flake.nix" ]]; then
        echo "$HOME/.config/nixos"
    elif [[ -f "/etc/nixos/configuration.nix" ]]; then
        echo "/etc/nixos/configuration.nix"
    else
        echo ""
    fi
}

nixos_get_hostname() {
    hostname -s
}

nixos_get_system_type() {
    if nixos_is_flake; then
        echo "flake"
    elif [[ -f "/etc/nixos/configuration.nix" ]]; then
        echo "standard"
    else
        echo "unknown"
    fi
}

#############################################################################
# Generation Management
#############################################################################

nixos_get_current_generation() {
    readlink /run/current-system | sed 's|/nix/store/||' | cut -d- -f1
}

nixos_list_generations() {
    nixos-rebuild list-generations
}

nixos_get_generation_count() {
    nixos-rebuild list-generations | wc -l
}

nixos_get_previous_generation() {
    nixos-rebuild list-generations | tail -2 | head -1 | awk '{print $1}'
}

#############################################################################
# Update/Upgrade Functions
#############################################################################

nixos_dry_run() {
    local system_type=$(nixos_get_system_type)
    
    case "$system_type" in
        flake)
            local config_path=$(nixos_get_config_path)
            cd "$config_path"
            nixos-rebuild dry-build --flake ".#$(nixos_get_hostname)"
            ;;
        standard)
            nixos-rebuild dry-build
            ;;
        *)
            echo "Error: Unknown system type" >&2
            return 1
            ;;
    esac
}

nixos_update_channels() {
    local system_type=$(nixos_get_system_type)
    
    case "$system_type" in
        flake)
            local config_path=$(nixos_get_config_path)
            cd "$config_path"
            nix flake update
            ;;
        standard)
            nix-channel --update
            ;;
    esac
}

nixos_rebuild_switch() {
    local system_type=$(nixos_get_system_type)
    
    case "$system_type" in
        flake)
            local config_path=$(nixos_get_config_path)
            cd "$config_path"
            nixos-rebuild switch --flake ".#$(nixos_get_hostname)"
            ;;
        standard)
            nixos-rebuild switch
            ;;
    esac
}

nixos_rebuild_boot() {
    local system_type=$(nixos_get_system_type)
    
    case "$system_type" in
        flake)
            local config_path=$(nixos_get_config_path)
            cd "$config_path"
            nixos-rebuild boot --flake ".#$(nixos_get_hostname)"
            ;;
        standard)
            nixos-rebuild boot
            ;;
    esac
}

#############################################################################
# Backup and Rollback
#############################################################################

nixos_create_backup_tag() {
    local tag_name=$1
    local generation=$(nixos_get_current_generation)
    local backup_file="/var/lib/nixos-updater/backups/${tag_name}_${generation}"
    
    mkdir -p "$(dirname "$backup_file")"
    echo "generation=$generation" > "$backup_file"
    echo "timestamp=$(date +%s)" >> "$backup_file"
    echo "channel=$(nixos_get_version)" >> "$backup_file"
    echo "$backup_file"
}

nixos_rollback_to_generation() {
    local target_gen=$1
    nixos-rebuild switch --rollback --target-generation "$target_gen"
}

nixos_rollback_previous() {
    nixos-rebuild switch --rollback
}

#############################################################################
# Channel Management
#############################################################################

nixos_get_available_channels() {
    cat << EOF
unstable
24.11
24.05
23.11
23.05
EOF
}

nixos_is_valid_channel() {
    local channel=$1
    nixos_get_available_channels | grep -q "^${channel}$"
}

nixos_change_channel() {
    local new_channel=$1
    local system_type=$(nixos_get_system_type)
    
    case "$system_type" in
        flake)
            echo "For flake-based systems, edit flake.nix manually"
            echo "Change: nixpkgs.url = \"github:NixOS/nixpkgs/nixos-$new_channel\";"
            return 1
            ;;
        standard)
            nix-channel --add "https://nixos.org/channels/nixos-$new_channel" nixos
            nix-channel --update
            ;;
    esac
}

#############################################################################
# Garbage Collection
#############################################################################

nixos_collect_garbage() {
    local keep_generations=${1:-5}
    nix-collect-garbage --delete-older-than "${keep_generations}d"
}

nixos_optimize_store() {
    nix-store --optimise
}

nixos_clean_old_generations() {
    local keep_count=${1:-5}
    nix-env --delete-generations "+${keep_count}"
}

#############################################################################
# Health Checks
#############################################################################

nixos_check_store_health() {
    nix-store --verify --check-contents
}

nixos_check_for_updates() {
    local system_type=$(nixos_get_system_type)
    
    case "$system_type" in
        flake)
            local config_path=$(nixos_get_config_path)
            cd "$config_path"
            nix flake update --dry-run
            ;;
        standard)
            nix-channel --update --dry-run
            ;;
    esac
}

#############################################################################
# Utility Functions
#############################################################################

nixos_get_package_version() {
    local package=$1
    nix-env -qaP "$package" | head -1 | awk '{print $2}'
}

nixos_list_installed_packages() {
    nix-env -q
}

nixos_get_system_profile() {
    readlink -f /nix/var/nix/profiles/system
}

#############################################################################
# Export Functions
#############################################################################

# Export all functions for use by other scripts
export -f nixos_get_version
export -f nixos_get_codename
export -f nixos_is_flake
export -f nixos_get_config_path
export -f nixos_get_hostname
export -f nixos_get_system_type
export -f nixos_get_current_generation
export -f nixos_list_generations
export -f nixos_get_generation_count
export -f nixos_get_previous_generation
export -f nixos_dry_run
export -f nixos_update_channels
export -f nixos_rebuild_switch
export -f nixos_rebuild_boot
export -f nixos_create_backup_tag
export -f nixos_rollback_to_generation
export -f nixos_rollback_previous
export -f nixos_get_available_channels
export -f nixos_is_valid_channel
export -f nixos_change_channel
export -f nixos_collect_garbage
export -f nixos_optimize_store
export -f nixos_clean_old_generations
export -f nixos_check_store_health
export -f nixos_check_for_updates
export -f nixos_get_package_version
export -f nixos_list_installed_packages
export -f nixos_get_system_profile
