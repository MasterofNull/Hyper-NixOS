#!/bin/bash
# Example Migration: 0.9.0 to 1.0.0
# Demonstrates migration pattern for major version upgrade

# Source the migration template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/migration-template.sh"

# Override metadata for this specific migration
MIGRATION_NAME="major-1.0-release"
FROM_VERSION="0.9.0"
TO_VERSION="1.0.0"
MIGRATION_ID="$(date +%Y%m%d)-${MIGRATION_NAME}"

# Override specific migration functions
migrate_configuration_format() {
  echo "Migrating configuration to 1.0 format..."

  # Example: Update hypervisor configuration structure
  local config_file="/etc/hypervisor/hypervisor.conf"

  if [ -f "$config_file" ]; then
    # Backup original
    cp "$config_file" "${config_file}.pre-1.0"

    # Add new required fields for 1.0
    if ! grep -q "^PROGRESS_TRACKING=" "$config_file"; then
      echo "PROGRESS_TRACKING=enabled" >> "$config_file"
    fi

    if ! grep -q "^EDUCATION_MODE=" "$config_file"; then
      echo "EDUCATION_MODE=enabled" >> "$config_file"
    fi
  fi

  echo -e "${GREEN}✓ Configuration format updated${NC}"
}

migrate_data_structures() {
  echo "Migrating data structures for 1.0..."

  # Example: Initialize progress tracking database
  if command -v hv-track-progress >/dev/null 2>&1; then
    hv-track-progress init 2>/dev/null || true
  fi

  echo -e "${GREEN}✓ Data structures migrated${NC}"
}

migrate_module_paths() {
  echo "Updating module imports for 1.0..."

  # Example: Update NixOS configuration imports
  local nix_config="/etc/nixos/configuration.nix"

  if [ -f "$nix_config" ]; then
    # Backup
    cp "$nix_config" "${nix_config}.pre-1.0"

    # Update deprecated module paths (example)
    sed -i 's|modules/old-path|modules/new-path|g' "$nix_config" 2>/dev/null || true
  fi

  echo -e "${GREEN}✓ Module paths updated${NC}"
}

# Run the migration using template orchestrator
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
