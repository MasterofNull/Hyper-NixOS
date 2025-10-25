#!/bin/bash
# Migration Template for Hyper-NixOS Version Upgrades
# Copy this template for each version migration

# Migration metadata
MIGRATION_NAME="descriptive-name-of-change"
FROM_VERSION="0.9.0"
TO_VERSION="1.0.0"
MIGRATION_ID="$(date +%Y%m%d)-${MIGRATION_NAME}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
VERSION_FILE="/etc/hypervisor/VERSION"
BACKUP_DIR="/var/lib/hypervisor/backups"
CONFIG_DIR="/etc/hypervisor"
MIGRATION_LOG="${BACKUP_DIR}/migrations.log"

# ============================================================================
# PRE-MIGRATION CHECKS
# ============================================================================

check_current_version() {
  if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${YELLOW}⚠ No version file found, assuming fresh install${NC}"
    echo "0.0.0" > "$VERSION_FILE"
  fi

  local current=$(cat "$VERSION_FILE")
  if [ "$current" != "$FROM_VERSION" ]; then
    echo -e "${YELLOW}⚠ Current version ($current) does not match expected ($FROM_VERSION)${NC}"
    echo -e "${YELLOW}⚠ Migration may not be applicable${NC}"
    return 1
  fi

  return 0
}

check_prerequisites() {
  # Check system requirements
  echo "Checking prerequisites..."

  # Example checks:
  # - Sufficient disk space
  # - Required packages installed
  # - No conflicting processes running

  local available_space=$(df -BG "$CONFIG_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
  if [ "$available_space" -lt 1 ]; then
    echo -e "${RED}✗ Insufficient disk space${NC}"
    return 1
  fi

  echo -e "${GREEN}✓ Prerequisites met${NC}"
  return 0
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

create_backup() {
  local backup_path="${BACKUP_DIR}/migration-${MIGRATION_ID}"

  echo "Creating backup..."
  mkdir -p "$backup_path"

  # Backup configuration files
  if [ -d "$CONFIG_DIR" ]; then
    cp -r "$CONFIG_DIR" "$backup_path/config" 2>/dev/null || true
  fi

  # Backup NixOS configuration
  if [ -f /etc/nixos/configuration.nix ]; then
    mkdir -p "$backup_path/nixos"
    cp /etc/nixos/configuration.nix "$backup_path/nixos/" 2>/dev/null || true
    cp -r /etc/nixos/modules "$backup_path/nixos/" 2>/dev/null || true
  fi

  # Backup database if exists
  if [ -f /var/lib/hypervisor/database.db ]; then
    cp /var/lib/hypervisor/database.db "$backup_path/" 2>/dev/null || true
  fi

  # Record backup metadata
  cat > "$backup_path/metadata.json" <<EOF
{
  "migration_id": "$MIGRATION_ID",
  "migration_name": "$MIGRATION_NAME",
  "from_version": "$FROM_VERSION",
  "to_version": "$TO_VERSION",
  "backup_created": "$(date -Iseconds)",
  "system_user": "$USER"
}
EOF

  echo "$backup_path" > "${backup_path}/.backup_path"
  echo -e "${GREEN}✓ Backup created: $backup_path${NC}"
  echo "$backup_path"
}

# ============================================================================
# MIGRATION STEPS
# ============================================================================

migrate_configuration_format() {
  echo "Migrating configuration format..."

  # Example: Convert old configuration to new format
  # This is migration-specific logic

  # if [ -f "$CONFIG_DIR/old-config.json" ]; then
  #   # Convert format
  #   jq '.newField = .oldField' "$CONFIG_DIR/old-config.json" > "$CONFIG_DIR/new-config.json"
  #   rm "$CONFIG_DIR/old-config.json"
  # fi

  echo -e "${GREEN}✓ Configuration format migrated${NC}"
}

migrate_data_structures() {
  echo "Migrating data structures..."

  # Example: Update database schema, file formats, etc.
  # This is migration-specific logic

  echo -e "${GREEN}✓ Data structures migrated${NC}"
}

migrate_module_paths() {
  echo "Migrating module paths..."

  # Example: Update import paths in NixOS configuration
  # if [ -f /etc/nixos/configuration.nix ]; then
  #   sed -i 's/old-module-path/new-module-path/g' /etc/nixos/configuration.nix
  # fi

  echo -e "${GREEN}✓ Module paths migrated${NC}"
}

update_version_file() {
  echo "Updating version..."
  echo "$TO_VERSION" > "$VERSION_FILE"
  echo -e "${GREEN}✓ Version updated to $TO_VERSION${NC}"
}

# ============================================================================
# POST-MIGRATION VERIFICATION
# ============================================================================

verify_migration() {
  echo "Verifying migration..."

  local errors=0

  # Check version file
  if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${RED}✗ Version file missing${NC}"
    ((errors++))
  else
    local version=$(cat "$VERSION_FILE")
    if [ "$version" != "$TO_VERSION" ]; then
      echo -e "${RED}✗ Version mismatch: expected $TO_VERSION, got $version${NC}"
      ((errors++))
    fi
  fi

  # Verify configuration files
  # Add migration-specific verification checks here

  if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✓ Migration verified successfully${NC}"
    return 0
  else
    echo -e "${RED}✗ Migration verification failed with $errors errors${NC}"
    return 1
  fi
}

# ============================================================================
# ROLLBACK FUNCTION
# ============================================================================

rollback_migration() {
  local backup_path="$1"

  echo -e "${YELLOW}⚠ Rolling back migration...${NC}"

  if [ ! -d "$backup_path" ]; then
    echo -e "${RED}✗ Backup directory not found: $backup_path${NC}"
    return 1
  fi

  # Restore configuration
  if [ -d "$backup_path/config" ]; then
    rm -rf "$CONFIG_DIR"
    cp -r "$backup_path/config" "$CONFIG_DIR"
  fi

  # Restore NixOS configuration
  if [ -d "$backup_path/nixos" ]; then
    cp "$backup_path/nixos/configuration.nix" /etc/nixos/ 2>/dev/null || true
    cp -r "$backup_path/nixos/modules" /etc/nixos/ 2>/dev/null || true
  fi

  # Restore database
  if [ -f "$backup_path/database.db" ]; then
    cp "$backup_path/database.db" /var/lib/hypervisor/
  fi

  # Restore version
  echo "$FROM_VERSION" > "$VERSION_FILE"

  echo -e "${GREEN}✓ Rollback complete${NC}"
  echo -e "${YELLOW}⚠ System restored to version $FROM_VERSION${NC}"
}

# ============================================================================
# LOGGING
# ============================================================================

log_migration() {
  local status="$1"
  local message="$2"

  mkdir -p "$(dirname "$MIGRATION_LOG")"

  cat >> "$MIGRATION_LOG" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "migration_id": "$MIGRATION_ID",
  "from_version": "$FROM_VERSION",
  "to_version": "$TO_VERSION",
  "status": "$status",
  "message": "$message"
}
EOF
}

# ============================================================================
# MAIN MIGRATION ORCHESTRATOR
# ============================================================================

run_migration() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Migration: $MIGRATION_NAME${NC}"
  echo -e "${BLUE}From: $FROM_VERSION → To: $TO_VERSION${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Pre-migration checks
  if ! check_current_version; then
    echo -e "${YELLOW}⚠ Skipping migration (version mismatch)${NC}"
    exit 0
  fi

  if ! check_prerequisites; then
    echo -e "${RED}✗ Prerequisites not met${NC}"
    log_migration "failed" "Prerequisites check failed"
    exit 1
  fi

  # Create backup
  local backup_path
  backup_path=$(create_backup)
  if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Backup failed${NC}"
    log_migration "failed" "Backup creation failed"
    exit 1
  fi

  # Run migration steps
  echo ""
  echo "Running migration steps..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local migration_failed=false

  migrate_configuration_format || migration_failed=true
  migrate_data_structures || migration_failed=true
  migrate_module_paths || migration_failed=true

  if [ "$migration_failed" = true ]; then
    echo -e "${RED}✗ Migration failed${NC}"
    echo -e "${YELLOW}Initiating rollback...${NC}"
    rollback_migration "$backup_path"
    log_migration "failed-rolled-back" "Migration failed, rolled back successfully"
    exit 1
  fi

  # Update version
  update_version_file

  # Verify migration
  echo ""
  if ! verify_migration; then
    echo -e "${RED}✗ Migration verification failed${NC}"
    echo -e "${YELLOW}Initiating rollback...${NC}"
    rollback_migration "$backup_path"
    log_migration "failed-rolled-back" "Verification failed, rolled back"
    exit 1
  fi

  # Success
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✓ Migration completed successfully!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Backup location: $backup_path"
  echo "To rollback: Run with --rollback $backup_path"
  echo ""

  log_migration "success" "Migration completed successfully"
}

# ============================================================================
# CLI INTERFACE
# ============================================================================

show_help() {
  cat <<EOF
Migration Script: $MIGRATION_NAME
From: $FROM_VERSION → To: $TO_VERSION

Usage:
  $0 [OPTIONS]

Options:
  --run              Run the migration (default)
  --dry-run          Show what would be done without executing
  --rollback PATH    Rollback to backup at PATH
  --verify           Verify migration without running
  --help             Show this help

Examples:
  $0 --run
  $0 --dry-run
  $0 --rollback /var/lib/hypervisor/backups/migration-20241017-example

EOF
}

# Main entry point
main() {
  local action="${1:---run}"

  case "$action" in
    --run)
      run_migration
      ;;
    --dry-run)
      echo "DRY RUN MODE - No changes will be made"
      echo ""
      check_current_version
      check_prerequisites
      echo ""
      echo "Would perform:"
      echo "  • Configuration format migration"
      echo "  • Data structure migration"
      echo "  • Module path migration"
      echo "  • Version update to $TO_VERSION"
      ;;
    --rollback)
      if [ -z "$2" ]; then
        echo "Error: --rollback requires backup path"
        echo "Usage: $0 --rollback /path/to/backup"
        exit 1
      fi
      rollback_migration "$2"
      ;;
    --verify)
      verify_migration
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo "Unknown option: $action"
      show_help
      exit 1
      ;;
  esac
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
