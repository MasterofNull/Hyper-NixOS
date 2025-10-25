#!/bin/bash
# Migration Manager for Hyper-NixOS
# Orchestrates version upgrades through migration chain

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
VERSION_FILE="/etc/hypervisor/VERSION"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

get_current_version() {
  if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE"
  else
    echo "0.0.0"
  fi
}

list_available_migrations() {
  if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo "No migrations directory found"
    return
  fi

  find "$MIGRATIONS_DIR" -name "migrate_*.sh" -type f | sort
}

parse_migration_metadata() {
  local migration_file="$1"

  # Extract FROM_VERSION and TO_VERSION from migration script
  local from_version=$(grep "^FROM_VERSION=" "$migration_file" | cut -d'"' -f2 | head -1)
  local to_version=$(grep "^TO_VERSION=" "$migration_file" | cut -d'"' -f2 | head -1)
  local migration_name=$(grep "^MIGRATION_NAME=" "$migration_file" | cut -d'"' -f2 | head -1)

  echo "$from_version|$to_version|$migration_name"
}

# Simple version comparison
version_greater_than() {
  local v1="$1"
  local v2="$2"

  # Convert versions to comparable integers
  # E.g., 1.2.3 -> 001002003
  local v1_num=$(echo "$v1" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
  local v2_num=$(echo "$v2" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')

  [ "$v1_num" -gt "$v2_num" ]
}

# ============================================================================
# MIGRATION PLANNING
# ============================================================================

plan_migration_path() {
  local current_version="$1"
  local target_version="$2"

  echo -e "${CYAN}Planning migration path...${NC}"
  echo "From: $current_version"
  echo "To:   $target_version"
  echo ""

  local migration_chain=()

  # Find all applicable migrations
  while IFS= read -r migration_file; do
    [ -f "$migration_file" ] || continue

    local metadata
    metadata=$(parse_migration_metadata "$migration_file")
    IFS='|' read -r from_ver to_ver name <<< "$metadata"

    # Check if this migration is in the path
    if version_greater_than "$from_ver" "$current_version" || [ "$from_ver" = "$current_version" ]; then
      if version_greater_than "$target_version" "$to_ver" || [ "$target_version" = "$to_ver" ]; then
        migration_chain+=("$migration_file|$from_ver|$to_ver|$name")
      fi
    fi
  done < <(list_available_migrations)

  if [ ${#migration_chain[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠ No migrations needed${NC}"
    return 1
  fi

  echo "Migration chain:"
  local step=1
  for migration in "${migration_chain[@]}"; do
    IFS='|' read -r file from_ver to_ver name <<< "$migration"
    echo -e "  ${BOLD}Step $step:${NC} $from_ver → $to_ver ($name)"
    ((step++))
  done

  echo ""
  return 0
}

# ============================================================================
# MIGRATION EXECUTION
# ============================================================================

run_migration_chain() {
  local current_version="$1"
  local target_version="$2"

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}Migration Manager${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if ! plan_migration_path "$current_version" "$target_version"; then
    echo "System is up to date!"
    exit 0
  fi

  echo -e "${YELLOW}⚠ This will modify your system configuration${NC}"
  echo -e "${YELLOW}⚠ Backups will be created automatically${NC}"
  echo ""
  read -p "Continue with migration? (yes/no): " -r confirm

  if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Migration cancelled"
    exit 0
  fi

  echo ""

  # Execute each migration in sequence
  local migrations=()
  while IFS= read -r migration_file; do
    [ -f "$migration_file" ] || continue

    local metadata
    metadata=$(parse_migration_metadata "$migration_file")
    IFS='|' read -r from_ver to_ver name <<< "$metadata"

    # Check if this migration applies
    local current
    current=$(get_current_version)

    if [ "$current" = "$from_ver" ]; then
      migrations+=("$migration_file")
    fi
  done < <(list_available_migrations)

  local total_migrations=${#migrations[@]}
  local current_step=1

  for migration_file in "${migrations[@]}"; do
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Running migration $current_step of $total_migrations${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if bash "$migration_file" --run; then
      echo -e "${GREEN}✓ Migration step $current_step succeeded${NC}"
      ((current_step++))
    else
      echo -e "${RED}✗ Migration step $current_step failed${NC}"
      echo -e "${YELLOW}⚠ Migration chain halted${NC}"
      exit 1
    fi

    echo ""
  done

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✓ All migrations completed successfully!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  local final_version
  final_version=$(get_current_version)
  echo "System version: $final_version"
  echo ""
  echo -e "${CYAN}Next steps:${NC}"
  echo "1. Review changes in /etc/hypervisor/"
  echo "2. Run: sudo nixos-rebuild switch"
  echo "3. Verify system functionality"
  echo ""
}

# ============================================================================
# STATUS AND INFO
# ============================================================================

show_status() {
  local current_version
  current_version=$(get_current_version)

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}Migration Status${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "Current version: ${BOLD}$current_version${NC}"
  echo ""

  echo "Available migrations:"
  if [ ! -d "$MIGRATIONS_DIR" ] || [ -z "$(ls -A "$MIGRATIONS_DIR" 2>/dev/null)" ]; then
    echo "  None"
  else
    while IFS= read -r migration_file; do
      [ -f "$migration_file" ] || continue

      local metadata
      metadata=$(parse_migration_metadata "$migration_file")
      IFS='|' read -r from_ver to_ver name <<< "$metadata"

      local status_icon="○"
      if version_greater_than "$current_version" "$from_ver"; then
        status_icon="${GREEN}✓${NC}"
      elif [ "$current_version" = "$from_ver" ]; then
        status_icon="${YELLOW}→${NC}"
      fi

      echo -e "  $status_icon $from_ver → $to_ver: $name"
    done < <(list_available_migrations)
  fi

  echo ""

  # Check for pending migrations
  local has_pending=false
  while IFS= read -r migration_file; do
    [ -f "$migration_file" ] || continue

    local metadata
    metadata=$(parse_migration_metadata "$migration_file")
    IFS='|' read -r from_ver to_ver name <<< "$metadata"

    if [ "$current_version" = "$from_ver" ]; then
      has_pending=true
      break
    fi
  done < <(list_available_migrations)

  if $has_pending; then
    echo -e "${YELLOW}⚠ Pending migrations available${NC}"
    echo "Run: migration-manager migrate"
  else
    echo -e "${GREEN}✓ System is up to date${NC}"
  fi

  echo ""
}

list_backups() {
  local backup_dir="/var/lib/hypervisor/backups"

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}Migration Backups${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if [ ! -d "$backup_dir" ]; then
    echo "No backups found"
    return
  fi

  local backups=($(find "$backup_dir" -maxdepth 1 -type d -name "migration-*" | sort -r))

  if [ ${#backups[@]} -eq 0 ]; then
    echo "No migration backups found"
    return
  fi

  for backup in "${backups[@]}"; do
    local backup_name=$(basename "$backup")
    local metadata_file="$backup/metadata.json"

    if [ -f "$metadata_file" ]; then
      # Parse metadata
      local from_ver=$(jq -r '.from_version' "$metadata_file" 2>/dev/null || echo "unknown")
      local to_ver=$(jq -r '.to_version' "$metadata_file" 2>/dev/null || echo "unknown")
      local created=$(jq -r '.backup_created' "$metadata_file" 2>/dev/null || echo "unknown")

      echo -e "${BOLD}$backup_name${NC}"
      echo "  From: $from_ver → To: $to_ver"
      echo "  Created: $created"
      echo "  Path: $backup"
    else
      echo -e "${BOLD}$backup_name${NC}"
      echo "  Path: $backup"
    fi
    echo ""
  done
}

# ============================================================================
# CLI INTERFACE
# ============================================================================

show_help() {
  cat <<EOF
${BOLD}Migration Manager${NC} - Hyper-NixOS Version Upgrade Tool

Usage:
  migration-manager COMMAND [OPTIONS]

Commands:
  status                Show current version and migration status
  migrate [VERSION]     Run migrations to target version (latest if not specified)
  plan [VERSION]        Show migration path without executing
  list                  List all available migrations
  backups               List migration backups
  rollback BACKUP_PATH  Rollback to a specific backup
  help                  Show this help

Examples:
  migration-manager status
  migration-manager migrate 1.0.0
  migration-manager plan 1.0.0
  migration-manager rollback /var/lib/hypervisor/backups/migration-20241017-example

EOF
}

# Main entry point
main() {
  local command="${1:-status}"

  case "$command" in
    status)
      show_status
      ;;

    migrate)
      local current_version
      current_version=$(get_current_version)

      local target_version="${2:-latest}"

      if [ "$target_version" = "latest" ]; then
        # Find highest version in migrations
        local max_version="0.0.0"
        while IFS= read -r migration_file; do
          [ -f "$migration_file" ] || continue

          local metadata
          metadata=$(parse_migration_metadata "$migration_file")
          IFS='|' read -r from_ver to_ver name <<< "$metadata"

          if version_greater_than "$to_ver" "$max_version"; then
            max_version="$to_ver"
          fi
        done < <(list_available_migrations)

        target_version="$max_version"
      fi

      run_migration_chain "$current_version" "$target_version"
      ;;

    plan)
      local current_version
      current_version=$(get_current_version)

      local target_version="${2:-latest}"

      if [ "$target_version" = "latest" ]; then
        local max_version="0.0.0"
        while IFS= read -r migration_file; do
          [ -f "$migration_file" ] || continue

          local metadata
          metadata=$(parse_migration_metadata "$migration_file")
          IFS='|' read -r from_ver to_ver name <<< "$metadata"

          if version_greater_than "$to_ver" "$max_version"; then
            max_version="$to_ver"
          fi
        done < <(list_available_migrations)

        target_version="$max_version"
      fi

      plan_migration_path "$current_version" "$target_version"
      ;;

    list)
      echo "Available migrations:"
      while IFS= read -r migration_file; do
        [ -f "$migration_file" ] || continue

        local metadata
        metadata=$(parse_migration_metadata "$migration_file")
        IFS='|' read -r from_ver to_ver name <<< "$metadata"

        echo "  $from_ver → $to_ver: $name"
        echo "    File: $(basename "$migration_file")"
      done < <(list_available_migrations)
      ;;

    backups)
      list_backups
      ;;

    rollback)
      if [ -z "${2:-}" ]; then
        echo "Error: rollback requires backup path"
        echo "Usage: migration-manager rollback /path/to/backup"
        exit 1
      fi

      # Find migration script that created this backup
      local backup_path="$2"
      local metadata_file="$backup_path/metadata.json"

      if [ ! -f "$metadata_file" ]; then
        echo "Error: Invalid backup (no metadata found)"
        exit 1
      fi

      # Rollback requires the original migration script
      echo -e "${YELLOW}⚠ Manual rollback required${NC}"
      echo "1. Identify the migration that created this backup"
      echo "2. Run: bash /path/to/migration.sh --rollback $backup_path"
      ;;

    help|--help|-h)
      show_help
      ;;

    *)
      echo "Unknown command: $command"
      show_help
      exit 1
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
