#!/usr/bin/env bash
#
# NixOS Configuration Detection and Management
# Advanced detection of profiles, configurations, and comparison

# Prevent double-sourcing
[[ -n "${NIXOS_CONFIG_DETECTION_LOADED:-}" ]] && return 0
readonly NIXOS_CONFIG_DETECTION_LOADED=1

#############################################################################
# Active Configuration Detection
#############################################################################

nixos_find_active_config() {
    # Returns the path to the currently active NixOS configuration
    
    # Check system profile link
    if [[ -L /run/current-system ]]; then
        local system_path=$(readlink -f /run/current-system)
        echo "$system_path"
        return 0
    fi
    
    return 1
}

nixos_get_active_profile() {
    # Get the currently active system profile
    if [[ -L /nix/var/nix/profiles/system ]]; then
        readlink -f /nix/var/nix/profiles/system
    fi
}

nixos_get_active_generation() {
    # More robust generation detection
    if [[ -L /run/current-system ]]; then
        local current=$(readlink -f /run/current-system)
        echo "$current" | grep -oP 'system-\K[0-9]+-link' | sed 's/-link//'
    else
        # Fallback
        nixos-rebuild list-generations | grep current | awk '{print $1}'
    fi
}

#############################################################################
# Configuration Path Detection
#############################################################################

nixos_find_all_configs() {
    # Find all possible NixOS configurations on the system
    local configs=()
    
    # Standard locations
    [[ -f /etc/nixos/configuration.nix ]] && configs+=("/etc/nixos")
    [[ -f /etc/nixos/flake.nix ]] && configs+=("/etc/nixos")
    
    # User home configs
    if [[ -n "$HOME" ]]; then
        [[ -f "$HOME/.config/nixos/configuration.nix" ]] && configs+=("$HOME/.config/nixos")
        [[ -f "$HOME/.config/nixos/flake.nix" ]] && configs+=("$HOME/.config/nixos")
    fi
    
    # Flake inputs (if flake-based)
    if [[ -f /etc/nixos/flake.nix ]]; then
        cd /etc/nixos
        nix flake metadata --json 2>/dev/null | jq -r '.path' | grep -v null
    fi
    
    # Print unique configs
    printf '%s\n' "${configs[@]}" | sort -u
}

nixos_detect_config_type() {
    local config_path=$1
    
    if [[ -f "$config_path/flake.nix" ]]; then
        echo "flake"
    elif [[ -f "$config_path/configuration.nix" ]]; then
        echo "standard"
    elif [[ -f "$config_path" && "$config_path" == *.nix ]]; then
        echo "custom"
    else
        echo "unknown"
    fi
}

nixos_get_flake_outputs() {
    local flake_path=${1:-/etc/nixos}
    
    if [[ ! -f "$flake_path/flake.nix" ]]; then
        return 1
    fi
    
    cd "$flake_path"
    nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]'
}

nixos_get_active_flake_output() {
    # Determine which flake output is currently active
    local hostname=$(hostname -s)
    local flake_path=${1:-/etc/nixos}
    
    # Check if hostname matches a flake output
    if nixos_get_flake_outputs "$flake_path" | grep -q "^${hostname}$"; then
        echo "$hostname"
    else
        # Return first output as fallback
        nixos_get_flake_outputs "$flake_path" | head -1
    fi
}

#############################################################################
# Configuration Comparison
#############################################################################

nixos_compare_configs() {
    local config1=$1
    local config2=$2
    
    if [[ ! -e "$config1" || ! -e "$config2" ]]; then
        echo "Error: One or both configurations not found" >&2
        return 1
    fi
    
    echo "=== Configuration Comparison ==="
    echo
    echo "Config 1: $config1"
    echo "Config 2: $config2"
    echo
    
    # Compare file structure
    if [[ -d "$config1" && -d "$config2" ]]; then
        echo "--- File Differences ---"
        diff -rq "$config1" "$config2" | grep -v ".git" | head -20
        echo
    fi
    
    # If both are nix files, show semantic diff
    if [[ -f "$config1" && -f "$config2" ]] && \
       [[ "$config1" == *.nix && "$config2" == *.nix ]]; then
        echo "--- Nix Expression Diff ---"
        diff -u "$config1" "$config2" | head -50
    fi
}

nixos_compare_generations() {
    local gen1=${1:-current}
    local gen2=${2:-previous}
    
    echo "=== Generation Comparison ==="
    echo
    
    # Get generation paths
    local gen1_path gen2_path
    
    if [[ "$gen1" == "current" ]]; then
        gen1_path=$(readlink -f /run/current-system)
    else
        gen1_path="/nix/var/nix/profiles/system-${gen1}-link"
    fi
    
    if [[ "$gen2" == "previous" ]]; then
        gen2_path=$(nixos-rebuild list-generations | tail -2 | head -1 | \
                    grep -oP '/nix/store/[^ ]+')
    else
        gen2_path="/nix/var/nix/profiles/system-${gen2}-link"
    fi
    
    # Compare packages
    echo "--- Package Differences ---"
    if [[ -d "$gen1_path" && -d "$gen2_path" ]]; then
        comm -3 \
            <(nix-store -q --references "$gen1_path" | sort) \
            <(nix-store -q --references "$gen2_path" | sort) | \
            head -20
    fi
}

nixos_diff_before_update() {
    # Show what will change with an update
    local config_path=${1:-/etc/nixos}
    local config_type=$(nixos_detect_config_type "$config_path")
    
    echo "=== Update Diff Preview ==="
    echo "Config: $config_path"
    echo "Type: $config_type"
    echo
    
    case "$config_type" in
        flake)
            cd "$config_path"
            echo "--- Flake Input Changes ---"
            nix flake update --dry-run 2>&1 || true
            echo
            
            echo "--- System Build Diff ---"
            nixos-rebuild dry-build --flake ".#$(nixos_get_active_flake_output "$config_path")" 2>&1 | \
                grep -E "will be (updated|installed|removed)" | head -20
            ;;
        standard)
            echo "--- Channel Updates ---"
            nix-channel --list
            echo
            
            echo "--- System Build Diff ---"
            nixos-rebuild dry-build 2>&1 | \
                grep -E "will be (updated|installed|removed)" | head -20
            ;;
    esac
}

#############################################################################
# Profile Management
#############################################################################

nixos_list_profiles() {
    echo "=== Available NixOS Profiles ==="
    echo
    
    # System profile
    echo "System Profile:"
    echo "  $(readlink -f /nix/var/nix/profiles/system)"
    echo
    
    # Per-user profiles
    if [[ -d /nix/var/nix/profiles/per-user ]]; then
        echo "User Profiles:"
        for user_dir in /nix/var/nix/profiles/per-user/*; do
            if [[ -d "$user_dir" ]]; then
                local user=$(basename "$user_dir")
                echo "  User: $user"
                ls -1 "$user_dir" | sed 's/^/    /'
            fi
        done
        echo
    fi
    
    # Flake outputs (if applicable)
    if [[ -f /etc/nixos/flake.nix ]]; then
        echo "Flake Outputs:"
        nixos_get_flake_outputs /etc/nixos | sed 's/^/  /'
        echo
        echo "Active Output: $(nixos_get_active_flake_output /etc/nixos)"
    fi
}

nixos_validate_config() {
    local config_path=$1
    local config_type=$(nixos_detect_config_type "$config_path")
    
    echo "=== Configuration Validation ==="
    echo "Config: $config_path"
    echo "Type: $config_type"
    echo
    
    local errors=0
    
    # Syntax check
    echo "→ Checking Nix syntax..."
    case "$config_type" in
        flake)
            if ! nix flake check "$config_path" 2>&1; then
                ((errors++))
            fi
            ;;
        standard|custom)
            if ! nix-instantiate --parse "$config_path" >/dev/null 2>&1; then
                ((errors++))
            fi
            ;;
    esac
    
    # Build test
    echo "→ Testing build..."
    case "$config_type" in
        flake)
            cd "$config_path"
            if ! nixos-rebuild dry-build --flake ".#$(nixos_get_active_flake_output "$config_path")" 2>&1 | tail -5; then
                ((errors++))
            fi
            ;;
        standard)
            if ! nixos-rebuild dry-build --file "$config_path/configuration.nix" 2>&1 | tail -5; then
                ((errors++))
            fi
            ;;
    esac
    
    if [[ $errors -eq 0 ]]; then
        echo "✓ Configuration is valid"
        return 0
    else
        echo "✗ Configuration has $errors error(s)"
        return 1
    fi
}

#############################################################################
# Hardware Compatibility
#############################################################################

nixos_check_hardware_compatibility() {
    echo "=== Hardware Compatibility Check ==="
    echo
    
    # Check critical hardware support
    local warnings=0
    
    # GPU drivers
    echo "→ Checking GPU support..."
    if lspci | grep -qi "nvidia"; then
        if ! nix-env -qa | grep -q "nvidia"; then
            echo "  ⚠ NVIDIA GPU detected but drivers may not be installed"
            ((warnings++))
        fi
    fi
    
    # Network adapters
    echo "→ Checking network hardware..."
    if ! ip link show | grep -q "state UP"; then
        echo "  ⚠ No active network interfaces detected"
        ((warnings++))
    fi
    
    # Storage
    echo "→ Checking storage..."
    if ! df -h / | tail -1 | awk '{print $5}' | grep -qE '[0-9]+%'; then
        echo "  ⚠ Unable to determine root filesystem usage"
        ((warnings++))
    fi
    
    # Boot loader
    echo "→ Checking boot configuration..."
    if [[ ! -d /boot/loader ]]; then
        echo "  ⚠ Boot loader directory not found"
        ((warnings++))
    fi
    
    if [[ $warnings -eq 0 ]]; then
        echo "✓ No hardware compatibility issues detected"
    else
        echo "⚠ $warnings potential compatibility issue(s) detected"
    fi
    
    return $warnings
}

#############################################################################
# Export Functions
#############################################################################

export -f nixos_find_active_config
export -f nixos_get_active_profile
export -f nixos_get_active_generation
export -f nixos_find_all_configs
export -f nixos_detect_config_type
export -f nixos_get_flake_outputs
export -f nixos_get_active_flake_output
export -f nixos_compare_configs
export -f nixos_compare_generations
export -f nixos_diff_before_update
export -f nixos_list_profiles
export -f nixos_validate_config
export -f nixos_check_hardware_compatibility
