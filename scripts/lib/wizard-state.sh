#!/bin/bash
# Wizard State Management for Rollback and Error Recovery
# Provides transactional capabilities for wizards

STATE_DIR="/var/lib/hypervisor/wizard-state"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# STATE INITIALIZATION
# ============================================================================

wizard_state_init() {
  local wizard_name="$1"
  local session_id="$(date +%s)-$$"

  export WIZARD_NAME="$wizard_name"
  export WIZARD_SESSION_ID="$session_id"
  export WIZARD_STATE="${STATE_DIR}/${wizard_name}-${session_id}.state"
  export WIZARD_STATE_LOG="${STATE_DIR}/${wizard_name}-${session_id}.log"

  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"

  # Initialize state file
  cat > "$WIZARD_STATE" <<EOF
# Wizard State File
# Wizard: $wizard_name
# Session: $session_id
# Started: $(date -Iseconds)
# PID: $$
# User: $USER

[METADATA]
wizard=$wizard_name
session=$session_id
started=$(date +%s)
status=in_progress

[ACTIONS]
# Format: action_type|target|backup_location|timestamp
EOF

  # Initialize log file
  {
    echo "=== Wizard State Log ==="
    echo "Wizard: $wizard_name"
    echo "Session: $session_id"
    echo "Started: $(date)"
    echo "========================"
    echo ""
  } > "$WIZARD_STATE_LOG"

  log_state "Wizard state initialized"
}

# ============================================================================
# STATE LOGGING
# ============================================================================

log_state() {
  local message="$1"

  if [ -n "${WIZARD_STATE_LOG:-}" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $message" >> "$WIZARD_STATE_LOG"
  fi
}

# ============================================================================
# ACTION TRACKING
# ============================================================================

wizard_track_action() {
  local action_type="$1"  # file_create, file_modify, file_delete, service_enable, command_run
  local target="$2"       # Path or identifier
  local backup="${3:-}"   # Backup location (if applicable)

  if [ -z "${WIZARD_STATE:-}" ]; then
    echo -e "${YELLOW}⚠ Warning: Wizard state not initialized${NC}" >&2
    return 1
  fi

  local timestamp=$(date +%s)

  # Record action
  echo "$action_type|$target|$backup|$timestamp" >> "$WIZARD_STATE"

  log_state "Action tracked: $action_type on $target"
}

# ============================================================================
# FILE OPERATIONS WITH TRACKING
# ============================================================================

wizard_create_file() {
  local file_path="$1"
  local content="${2:-}"

  log_state "Creating file: $file_path"

  # Create parent directory if needed
  mkdir -p "$(dirname "$file_path")"

  # Create file
  if [ -n "$content" ]; then
    echo "$content" > "$file_path"
  else
    touch "$file_path"
  fi

  # Track action
  wizard_track_action "FILE_CREATE" "$file_path" ""

  echo -e "${GREEN}✓${NC} Created: $file_path"
}

wizard_modify_file() {
  local file_path="$1"

  if [ ! -f "$file_path" ]; then
    echo -e "${RED}✗ File not found: $file_path${NC}" >&2
    return 1
  fi

  log_state "Modifying file: $file_path"

  # Create backup
  local backup_path="${STATE_DIR}/backup-$(basename "$file_path")-$(date +%s)"
  cp "$file_path" "$backup_path"

  # Track action with backup location
  wizard_track_action "FILE_MODIFY" "$file_path" "$backup_path"

  echo -e "${BLUE}ⓘ${NC} Backed up: $file_path → $backup_path"
  echo "$backup_path"  # Return backup path
}

wizard_delete_file() {
  local file_path="$1"

  if [ ! -f "$file_path" ]; then
    echo -e "${YELLOW}⚠ File doesn't exist: $file_path${NC}" >&2
    return 0
  fi

  log_state "Deleting file: $file_path"

  # Create backup before deletion
  local backup_path="${STATE_DIR}/deleted-$(basename "$file_path")-$(date +%s)"
  cp "$file_path" "$backup_path"

  # Delete file
  rm "$file_path"

  # Track action
  wizard_track_action "FILE_DELETE" "$file_path" "$backup_path"

  echo -e "${YELLOW}⊘${NC} Deleted: $file_path (backed up to $backup_path)"
}

# ============================================================================
# SERVICE OPERATIONS WITH TRACKING
# ============================================================================

wizard_enable_service() {
  local service_name="$1"

  log_state "Enabling service: $service_name"

  # Check if already enabled
  local was_enabled="false"
  if systemctl is-enabled "$service_name" >/dev/null 2>&1; then
    was_enabled="true"
  fi

  # Enable service
  systemctl enable "$service_name" 2>/dev/null || true

  # Track action with previous state
  wizard_track_action "SERVICE_ENABLE" "$service_name" "was_enabled=$was_enabled"

  echo -e "${GREEN}✓${NC} Enabled service: $service_name"
}

wizard_start_service() {
  local service_name="$1"

  log_state "Starting service: $service_name"

  # Check if already running
  local was_active="false"
  if systemctl is-active "$service_name" >/dev/null 2>&1; then
    was_active="true"
  fi

  # Start service
  systemctl start "$service_name" 2>/dev/null || true

  # Track action
  wizard_track_action "SERVICE_START" "$service_name" "was_active=$was_active"

  echo -e "${GREEN}✓${NC} Started service: $service_name"
}

# ============================================================================
# COMMAND EXECUTION WITH TRACKING
# ============================================================================

wizard_run_command() {
  local command="$1"
  local description="${2:-$command}"

  log_state "Running command: $description"

  # Execute command
  if eval "$command" 2>&1 | tee -a "$WIZARD_STATE_LOG"; then
    wizard_track_action "COMMAND_RUN" "$description" "success"
    return 0
  else
    local exit_code=$?
    wizard_track_action "COMMAND_RUN" "$description" "failed:$exit_code"
    return $exit_code
  fi
}

# ============================================================================
# STATE CHECKPOINTS
# ============================================================================

wizard_checkpoint() {
  local checkpoint_name="$1"
  local timestamp=$(date +%s)

  log_state "Checkpoint: $checkpoint_name"

  echo "" >> "$WIZARD_STATE"
  echo "[CHECKPOINT:$checkpoint_name:$timestamp]" >> "$WIZARD_STATE"
  echo "" >> "$WIZARD_STATE"
}

# ============================================================================
# COMMIT (SUCCESS)
# ============================================================================

wizard_state_commit() {
  if [ -z "${WIZARD_STATE:-}" ]; then
    return
  fi

  log_state "Wizard completed successfully"

  # Update status
  sed -i 's/^status=in_progress/status=completed/' "$WIZARD_STATE" 2>/dev/null || true

  # Add completion metadata
  {
    echo ""
    echo "[COMPLETION]"
    echo "completed_at=$(date -Iseconds)"
    echo "completed_ts=$(date +%s)"
    echo "status=success"
  } >> "$WIZARD_STATE"

  echo -e "${GREEN}✓ Wizard state committed${NC}"

  # Optional: Clean up successful state files after 24 hours
  # This can be done by a cleanup service
}

# ============================================================================
# ROLLBACK (FAILURE)
# ============================================================================

wizard_state_rollback() {
  if [ -z "${WIZARD_STATE:-}" ]; then
    echo -e "${YELLOW}⚠ No wizard state to rollback${NC}"
    return
  fi

  if [ ! -f "$WIZARD_STATE" ]; then
    echo -e "${YELLOW}⚠ State file not found${NC}"
    return
  fi

  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}⚠ Rolling back wizard changes...${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  log_state "Starting rollback"

  # Parse actions in reverse order
  local actions=()
  while IFS='|' read -r action_type target backup timestamp; do
    [ -z "$action_type" ] && continue
    [[ "$action_type" =~ ^# ]] && continue
    [[ "$action_type" =~ ^\[ ]] && continue

    actions+=("$action_type|$target|$backup|$timestamp")
  done < <(grep -E '^[^#\[]' "$WIZARD_STATE" | tac)

  local rollback_count=0
  local rollback_errors=0

  # Rollback each action
  for action in "${actions[@]}"; do
    IFS='|' read -r action_type target backup timestamp <<< "$action"

    case "$action_type" in
      FILE_CREATE)
        if [ -f "$target" ]; then
          rm "$target"
          echo -e "${GREEN}✓${NC} Removed created file: $target"
          ((rollback_count++))
        fi
        ;;

      FILE_MODIFY)
        if [ -f "$backup" ]; then
          cp "$backup" "$target"
          echo -e "${GREEN}✓${NC} Restored modified file: $target"
          ((rollback_count++))
        else
          echo -e "${YELLOW}⚠${NC} Backup not found for: $target"
          ((rollback_errors++))
        fi
        ;;

      FILE_DELETE)
        if [ -f "$backup" ]; then
          cp "$backup" "$target"
          echo -e "${GREEN}✓${NC} Restored deleted file: $target"
          ((rollback_count++))
        else
          echo -e "${YELLOW}⚠${NC} Backup not found for: $target"
          ((rollback_errors++))
        fi
        ;;

      SERVICE_ENABLE)
        if [[ "$backup" =~ was_enabled=false ]]; then
          systemctl disable "$target" 2>/dev/null || true
          echo -e "${GREEN}✓${NC} Disabled service: $target"
          ((rollback_count++))
        fi
        ;;

      SERVICE_START)
        if [[ "$backup" =~ was_active=false ]]; then
          systemctl stop "$target" 2>/dev/null || true
          echo -e "${GREEN}✓${NC} Stopped service: $target"
          ((rollback_count++))
        fi
        ;;

      COMMAND_RUN)
        # Commands cannot be automatically rolled back
        echo -e "${BLUE}ⓘ${NC} Command was run: $target (manual review may be needed)"
        ;;
    esac
  done

  log_state "Rollback completed: $rollback_count actions reverted, $rollback_errors errors"

  # Update status
  {
    echo ""
    echo "[ROLLBACK]"
    echo "rolled_back_at=$(date -Iseconds)"
    echo "actions_reverted=$rollback_count"
    echo "errors=$rollback_errors"
    echo "status=rolled_back"
  } >> "$WIZARD_STATE"

  echo ""
  echo -e "${GREEN}✓ Rollback complete${NC}"
  echo "  Actions reverted: $rollback_count"
  if [ $rollback_errors -gt 0 ]; then
    echo -e "  ${YELLOW}Errors: $rollback_errors${NC}"
  fi
  echo ""
  echo "State file: $WIZARD_STATE"
  echo "Log file: $WIZARD_STATE_LOG"
}

# ============================================================================
# ERROR TRAP INTEGRATION
# ============================================================================

wizard_error_handler() {
  local exit_code=$?
  local line_number=$1

  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}✗ Wizard encountered an error${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Exit code: $exit_code"
  echo -e "Line number: $line_number"
  echo ""

  log_state "ERROR: Exit code $exit_code at line $line_number"

  wizard_state_rollback

  echo -e "${BLUE}ⓘ For details, see: $WIZARD_STATE_LOG${NC}"
  exit $exit_code
}

wizard_setup_error_trap() {
  trap 'wizard_error_handler $LINENO' ERR
}

# ============================================================================
# CLEANUP
# ============================================================================

wizard_cleanup_old_states() {
  local max_age_days="${1:-7}"

  if [ ! -d "$STATE_DIR" ]; then
    return
  fi

  echo "Cleaning up wizard states older than $max_age_days days..."

  # Find and remove old state files
  find "$STATE_DIR" -type f -name "*.state" -mtime +$max_age_days -delete
  find "$STATE_DIR" -type f -name "*.log" -mtime +$max_age_days -delete
  find "$STATE_DIR" -type f -name "backup-*" -mtime +$max_age_days -delete
  find "$STATE_DIR" -type f -name "deleted-*" -mtime +$max_age_days -delete

  echo "✓ Cleanup complete"
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

export -f wizard_state_init
export -f wizard_track_action
export -f wizard_create_file
export -f wizard_modify_file
export -f wizard_delete_file
export -f wizard_enable_service
export -f wizard_start_service
export -f wizard_run_command
export -f wizard_checkpoint
export -f wizard_state_commit
export -f wizard_state_rollback
export -f wizard_error_handler
export -f wizard_setup_error_trap
export -f wizard_cleanup_old_states
export -f log_state
