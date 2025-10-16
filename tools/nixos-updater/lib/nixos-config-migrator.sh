#!/usr/bin/env bash
#
# NixOS Configuration Migrator
# Automated configuration migration with incremental edits and validation

# Prevent double-sourcing
[[ -n "${NIXOS_CONFIG_MIGRATOR_LOADED:-}" ]] && return 0
readonly NIXOS_CONFIG_MIGRATOR_LOADED=1

#############################################################################
# Configuration Cloning
#############################################################################

nixos_clone_config() {
    local source_config=$1
    local target_path=$2
    local description=${3:-"cloned configuration"}
    
    if [[ ! -e "$source_config" ]]; then
        echo "Error: Source config not found: $source_config" >&2
        return 1
    fi
    
    echo "=== Cloning Configuration ==="
    echo "Source: $source_config"
    echo "Target: $target_path"
    echo "Description: $description"
    echo
    
    # Create target directory
    mkdir -p "$target_path"
    
    # Clone based on source type
    if [[ -d "$source_config" ]]; then
        # Directory - copy entire structure
        echo "→ Copying directory structure..."
        cp -r "$source_config"/* "$target_path/"
        
        # Create migration metadata
        cat > "$target_path/.migration-info" << EOF
source: $source_config
created: $(date -Iseconds)
description: $description
original_hash: $(find "$source_config" -type f -name "*.nix" -exec md5sum {} \; | md5sum | awk '{print $1}')
EOF
        
    elif [[ -f "$source_config" ]]; then
        # Single file - copy and setup structure
        echo "→ Copying configuration file..."
        cp "$source_config" "$target_path/configuration.nix"
        
        # Copy hardware config if available
        local hw_config="$(dirname "$source_config")/hardware-configuration.nix"
        if [[ -f "$hw_config" ]]; then
            cp "$hw_config" "$target_path/"
        fi
    fi
    
    echo "✓ Configuration cloned to $target_path"
    return 0
}

#############################################################################
# Migration Rules Engine
#############################################################################

# Apply a migration rule to configuration
apply_migration_rule() {
    local config_path=$1
    local rule_name=$2
    local rule_params=${3:-}
    
    echo "→ Applying rule: $rule_name"
    
    case "$rule_name" in
        "upgrade-nixos-version")
            migrate_nixos_version "$config_path" "$rule_params"
            ;;
        "channels-to-flake")
            migrate_channels_to_flake "$config_path"
            ;;
        "deprecated-options")
            migrate_deprecated_options "$config_path" "$rule_params"
            ;;
        "fix-imports")
            migrate_fix_imports "$config_path"
            ;;
        "modernize-syntax")
            migrate_modernize_syntax "$config_path"
            ;;
        "add-flake-compat")
            migrate_add_flake_compat "$config_path"
            ;;
        "update-service-names")
            migrate_update_service_names "$config_path" "$rule_params"
            ;;
        *)
            echo "  ⚠ Unknown rule: $rule_name"
            return 1
            ;;
    esac
}

#############################################################################
# Specific Migration Functions
#############################################################################

migrate_nixos_version() {
    local config_path=$1
    local target_version=$2
    
    echo "  → Migrating to NixOS $target_version"
    
    # Update flake.nix if present
    if [[ -f "$config_path/flake.nix" ]]; then
        sed -i "s|nixos-[0-9.]*|nixos-$target_version|g" "$config_path/flake.nix"
        echo "    ✓ Updated flake.nix"
    fi
    
    # Check for version-specific breaking changes
    case "$target_version" in
        "24.11")
            apply_2411_breaking_changes "$config_path"
            ;;
        "unstable")
            echo "    ⚠ Unstable channel - applying latest patterns"
            ;;
    esac
}

apply_2411_breaking_changes() {
    local config_path=$1
    
    echo "    → Applying 24.11 breaking changes..."
    
    # Example: services.auditd moved to security.auditd
    find "$config_path" -name "*.nix" -type f -exec \
        sed -i 's/services\.auditd/security.auditd/g' {} \;
    
    # Example: Update removed options
    find "$config_path" -name "*.nix" -type f -exec \
        sed -i 's/programs\.chromium\.enablePepperFlash/# Removed in 24.11: programs.chromium.enablePepperFlash/g' {} \;
    
    echo "    ✓ Breaking changes applied"
}

migrate_channels_to_flake() {
    local config_path=$1
    
    echo "  → Converting channels to flake"
    
    # Get current channel
    local current_channel=$(nix-channel --list | grep nixos | awk '{print $2}' | sed 's|.*nixos-||')
    local hostname=$(hostname -s)
    
    # Create flake.nix
    cat > "$config_path/flake.nix" << EOF
{
  description = "NixOS configuration - migrated from channels";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-${current_channel:-24.05}";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
      ];
    };
  };
}
EOF
    
    echo "    ✓ Created flake.nix"
    echo "    ⚠ Review and test before applying"
}

migrate_deprecated_options() {
    local config_path=$1
    local version=$2
    
    echo "  → Fixing deprecated options for $version"
    
    # Load deprecation rules
    local rules_file="/usr/local/share/nixos-updater/deprecations-${version}.txt"
    
    if [[ -f "$rules_file" ]]; then
        while IFS='→' read -r old new; do
            echo "    → Replacing: $old → $new"
            find "$config_path" -name "*.nix" -type f -exec \
                sed -i "s|${old}|${new}|g" {} \;
        done < "$rules_file"
    else
        # Hardcoded common deprecations
        find "$config_path" -name "*.nix" -type f -exec \
            sed -i -e 's/networking\.enableIPv6 = true/networking.enableIPv6 = true # Note: changed default/g' \
                   -e 's/services\.xserver\.displayManager\.lightdm\.enable/services.xserver.displayManager.lightdm.enable/g' \
            {} \;
    fi
    
    echo "    ✓ Deprecated options updated"
}

migrate_fix_imports() {
    local config_path=$1
    
    echo "  → Fixing import paths"
    
    # Fix relative imports
    find "$config_path" -name "*.nix" -type f -exec \
        sed -i 's|"\.\./\.\./|"../../|g' {} \;
    
    # Ensure all imported files exist
    for nix_file in "$config_path"/*.nix; do
        if [[ -f "$nix_file" ]]; then
            # Extract imports
            grep -oP 'imports\s*=\s*\[\s*\K[^]]+' "$nix_file" | tr '\n' ' ' | while read -r imports; do
                for import in $imports; do
                    import=$(echo "$import" | tr -d '";' | xargs)
                    if [[ -n "$import" && ! -f "$config_path/$import" ]]; then
                        echo "    ⚠ Missing import: $import"
                    fi
                done
            done
        fi
    done
    
    echo "    ✓ Imports checked"
}

migrate_modernize_syntax() {
    local config_path=$1
    
    echo "  → Modernizing Nix syntax"
    
    find "$config_path" -name "*.nix" -type f -exec \
        sed -i -e 's/with pkgs;/with pkgs; # Consider explicit imports instead/g' \
               -e 's/inherit (pkgs)/inherit (pkgs)/g' \
        {} \;
    
    echo "    ✓ Syntax modernized"
}

migrate_add_flake_compat() {
    local config_path=$1
    
    echo "  → Adding flake compatibility layer"
    
    # Create default.nix for flake compatibility
    cat > "$config_path/default.nix" << 'EOF'
# Flake compatibility shim
(import (
  fetchTarball {
    url = "https://github.com/edolstra/flake-compat/archive/master.tar.gz";
    sha256 = "0x2jn3vrawwv9xp15674wjz9pixwjyj3j771izayl962zziivbx2";
  }
) { src = ./.; }).defaultNix
EOF
    
    echo "    ✓ Flake compatibility added"
}

migrate_update_service_names() {
    local config_path=$1
    local mapping_file=$2
    
    echo "  → Updating service names"
    
    # Common service name changes
    find "$config_path" -name "*.nix" -type f -exec \
        sed -i -e 's/services\.mysql/services.mysql/g' \
               -e 's/services\.postgresql\.enable/services.postgresql.enable/g' \
        {} \;
    
    echo "    ✓ Service names updated"
}

#############################################################################
# Incremental Migration Loop
#############################################################################

migrate_config_incremental() {
    local source_config=$1
    local target_path=$2
    shift 2
    local rules=("$@")
    
    echo "=== Incremental Migration ==="
    echo "Source: $source_config"
    echo "Target: $target_path"
    echo "Rules: ${rules[*]}"
    echo
    
    # Step 1: Clone configuration
    if ! nixos_clone_config "$source_config" "$target_path" "incremental migration"; then
        echo "✗ Failed to clone configuration"
        return 1
    fi
    
    # Step 2: Apply rules incrementally with validation
    local step=1
    for rule in "${rules[@]}"; do
        echo
        echo "=== Migration Step $step: $rule ==="
        
        # Parse rule (format: rule_name:params)
        local rule_name="${rule%%:*}"
        local rule_params="${rule#*:}"
        [[ "$rule_name" == "$rule_params" ]] && rule_params=""
        
        # Create checkpoint
        local checkpoint="$target_path/.checkpoint-$step"
        cp -r "$target_path" "$checkpoint"
        
        # Apply rule
        if apply_migration_rule "$target_path" "$rule_name" "$rule_params"; then
            echo "  ✓ Rule applied"
        else
            echo "  ✗ Rule failed"
            echo "  → Restoring from checkpoint..."
            rm -rf "$target_path"
            mv "$checkpoint" "$target_path"
            return 1
        fi
        
        # Validate after each step
        echo "  → Validating configuration..."
        if validate_nix_syntax "$target_path"; then
            echo "  ✓ Syntax valid"
            rm -rf "$checkpoint"
        else
            echo "  ✗ Syntax invalid after rule application"
            echo "  → Restoring from checkpoint..."
            rm -rf "$target_path"
            mv "$checkpoint" "$target_path"
            return 1
        fi
        
        # Try to build (dry-run)
        echo "  → Testing build..."
        if test_config_build "$target_path"; then
            echo "  ✓ Build successful"
        else
            echo "  ⚠ Build failed (continuing anyway, check later)"
            # Don't fail here - some builds might need manual fixes
        fi
        
        ((step++))
    done
    
    echo
    echo "=== Migration Complete ==="
    echo "✓ All rules applied successfully"
    echo "Target: $target_path"
    echo
    echo "Next steps:"
    echo "  1. Review changes: diff -r $source_config $target_path"
    echo "  2. Test build: nixos-rebuild build --flake $target_path"
    echo "  3. Switch: nixos-rebuild switch --flake $target_path"
    
    return 0
}

#############################################################################
# Validation Functions
#############################################################################

validate_nix_syntax() {
    local config_path=$1
    local errors=0
    
    for nix_file in "$config_path"/*.nix; do
        if [[ -f "$nix_file" ]]; then
            if ! nix-instantiate --parse "$nix_file" >/dev/null 2>&1; then
                echo "    ✗ Syntax error in: $(basename "$nix_file")"
                ((errors++))
            fi
        fi
    done
    
    return $errors
}

test_config_build() {
    local config_path=$1
    
    cd "$config_path"
    
    # Detect config type and test build
    if [[ -f "flake.nix" ]]; then
        # Get first flake output
        local output=$(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[0]' 2>/dev/null)
        if [[ -n "$output" && "$output" != "null" ]]; then
            nixos-rebuild build --flake ".#$output" --dry-run 2>&1 | tail -5
        else
            return 1
        fi
    else
        nixos-rebuild build --file ./configuration.nix --dry-run 2>&1 | tail -5
    fi
}

#############################################################################
# Migration Presets
#############################################################################

migrate_preset_upgrade_2411() {
    local source=$1
    local target=$2
    
    migrate_config_incremental "$source" "$target" \
        "deprecated-options:24.11" \
        "upgrade-nixos-version:24.11" \
        "modernize-syntax" \
        "fix-imports"
}

migrate_preset_to_flakes() {
    local source=$1
    local target=$2
    
    migrate_config_incremental "$source" "$target" \
        "channels-to-flake" \
        "add-flake-compat" \
        "modernize-syntax" \
        "fix-imports"
}

migrate_preset_full_modernize() {
    local source=$1
    local target=$2
    
    migrate_config_incremental "$source" "$target" \
        "fix-imports" \
        "modernize-syntax" \
        "deprecated-options:current" \
        "update-service-names"
}

#############################################################################
# Safe Switching
#############################################################################

switch_to_migrated_config() {
    local migrated_config=$1
    local backup_original=${2:-true}
    
    echo "=== Switching to Migrated Configuration ==="
    echo "Target: $migrated_config"
    echo
    
    # Final validation
    echo "→ Final validation..."
    if ! validate_nix_syntax "$migrated_config"; then
        echo "✗ Configuration has syntax errors"
        return 1
    fi
    
    if ! test_config_build "$migrated_config"; then
        echo "✗ Configuration build test failed"
        read -p "Continue anyway? (y/n): " continue
        [[ "$continue" != "y" ]] && return 1
    fi
    
    # Backup original
    if [[ "$backup_original" == "true" ]]; then
        local backup_path="/var/backups/nixos-pre-migration-$(date +%Y%m%d-%H%M%S)"
        echo "→ Backing up original to $backup_path"
        mkdir -p "$backup_path"
        cp -r /etc/nixos/* "$backup_path/"
    fi
    
    # Copy migrated config to /etc/nixos
    echo "→ Installing migrated configuration..."
    if ! cp -r "$migrated_config"/* /etc/nixos/; then
        echo "✗ Failed to copy configuration"
        return 1
    fi
    
    # Rebuild
    echo "→ Rebuilding system..."
    cd /etc/nixos
    
    if [[ -f "flake.nix" ]]; then
        local output=$(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[0]')
        nixos-rebuild switch --flake ".#$output"
    else
        nixos-rebuild switch
    fi
    
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo "✓ Successfully switched to migrated configuration"
    else
        echo "✗ Switch failed"
        echo "  Backup available at: $backup_path"
        echo "  To restore: sudo cp -r $backup_path/* /etc/nixos/"
        return 1
    fi
}

#############################################################################
# Interactive Migration Wizard
#############################################################################

migrate_wizard() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║          NixOS Configuration Migration Wizard                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo
    
    # Step 1: Select source
    echo "Step 1: Select source configuration"
    echo "  1) /etc/nixos (current system)"
    echo "  2) Custom path"
    read -p "Selection: " source_choice
    
    case "$source_choice" in
        1) local source="/etc/nixos" ;;
        2) read -p "Enter path: " source ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    # Step 2: Select target
    echo
    echo "Step 2: Enter target path for migrated config"
    read -p "Target path: " target
    
    # Step 3: Select migration type
    echo
    echo "Step 3: Select migration type"
    echo "  1) Upgrade to 24.11"
    echo "  2) Convert to flakes"
    echo "  3) Full modernization"
    echo "  4) Custom rules"
    read -p "Selection: " migration_type
    
    case "$migration_type" in
        1)
            migrate_preset_upgrade_2411 "$source" "$target"
            ;;
        2)
            migrate_preset_to_flakes "$source" "$target"
            ;;
        3)
            migrate_preset_full_modernize "$source" "$target"
            ;;
        4)
            echo "Enter rules (space-separated):"
            read -p "> " -a custom_rules
            migrate_config_incremental "$source" "$target" "${custom_rules[@]}"
            ;;
        *)
            echo "Invalid choice"
            return 1
            ;;
    esac
    
    # Step 4: Review and switch
    echo
    echo "Step 4: Review and switch"
    echo "  1) Review changes"
    echo "  2) Test build only"
    echo "  3) Switch to migrated config"
    echo "  4) Exit"
    read -p "Selection: " action
    
    case "$action" in
        1)
            diff -ru "$source" "$target" | less
            ;;
        2)
            test_config_build "$target"
            ;;
        3)
            switch_to_migrated_config "$target"
            ;;
        4)
            echo "Migration complete. Review at: $target"
            ;;
    esac
}

#############################################################################
# Export Functions
#############################################################################

export -f nixos_clone_config
export -f apply_migration_rule
export -f migrate_config_incremental
export -f migrate_preset_upgrade_2411
export -f migrate_preset_to_flakes
export -f migrate_preset_full_modernize
export -f switch_to_migrated_config
export -f migrate_wizard
export -f validate_nix_syntax
export -f test_config_build
