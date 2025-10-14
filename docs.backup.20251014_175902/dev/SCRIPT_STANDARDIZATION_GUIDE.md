# Hyper-NixOS Script Standardization Guide

## 📚 Overview

This guide documents the standardization of scripts in Hyper-NixOS through shared libraries. By consolidating common functionality, we've reduced code duplication by approximately 40% and improved consistency across the project.

## 🎯 Standardization Goals

1. **Eliminate Duplication**: Remove repeated code patterns
2. **Ensure Consistency**: Uniform behavior across all scripts
3. **Improve Maintainability**: Fix bugs and add features in one place
4. **Enhance Security**: Centralized security checks and validation
5. **Better UX**: Professional, consistent user interface

## 📁 Shared Libraries

### 1. `/etc/hypervisor/scripts/lib/common.sh`

The core library providing:
- Logging functions with levels
- Permission and privilege management
- Error handling and cleanup
- File operations (backup, directory creation)
- Configuration management
- Process management
- Retry mechanisms

**Key Functions:**
```bash
init_script "script-name" [require_root] [load_libs]
log_info "message"
log_error "message"
log_warn "message"
check_root [require] [allow_sudo]
backup_file "/path/to/file"
retry_with_backoff 3 2 command args
```

### 2. `/etc/hypervisor/scripts/lib/ui.sh`

UI and formatting library providing:
- Color definitions (exported globally)
- Print functions with consistent formatting
- Progress indicators and spinners
- User interaction (confirmations, menus)
- Table formatting
- Banner display

**Key Functions:**
```bash
print_header "Title"
print_success "Operation completed"
print_error "Something failed"
print_warning "Be careful"
print_info "Information"
show_progress $current $total
confirm "Continue?" [default]
select_option "Choose:" "${options[@]}"
```

### 3. `/etc/hypervisor/scripts/lib/system.sh`

System detection and information library providing:
- Hardware detection (CPU, RAM, disk, GPU)
- Capability detection (virtualization, IOMMU, AVX)
- Network information
- System requirements checking
- JSON export of system info

**Key Functions:**
```bash
detect_system_resources
check_requirements $min_ram_mb $min_cpus $min_disk_gb
get_system_summary
get_system_json
recommend_system_tier
```

## 🔄 Migration Process

### Before Migration

```bash
#!/usr/bin/env bash

# Duplicated color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Duplicated logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Duplicated root check
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Run as root${NC}"
        exit 1
    fi
}

# Main logic
check_root
log "Starting..."
echo -e "${GREEN}✓${NC} Done"
```

### After Migration

```bash
#!/usr/bin/env bash

# Source common libraries
source /etc/hypervisor/scripts/lib/common.sh || {
    echo "ERROR: Failed to load common library" >&2
    exit 1
}

# Initialize script
init_script "my-script" true  # true = requires root

# Main logic using library functions
log_info "Starting..."
print_success "Done"
```

## 🛠️ Migration Tool

Use the automated migration tool to help convert scripts:

```bash
# Analyze scripts in a directory
/etc/hypervisor/scripts/tools/migrate-to-libraries.sh /path/to/scripts

# Dry run to see what would change
/etc/hypervisor/scripts/tools/migrate-to-libraries.sh --dry-run ./scripts

# Migrate without backups (not recommended)
/etc/hypervisor/scripts/tools/migrate-to-libraries.sh --no-backup ./scripts
```

## 📋 Standardization Checklist

When creating or updating scripts:

- [ ] Source required libraries at the beginning
- [ ] Use `init_script()` for standard initialization
- [ ] Replace custom colors with library constants
- [ ] Use library logging functions
- [ ] Replace custom error handling with library functions
- [ ] Use `print_*` functions for user output
- [ ] Leverage system detection instead of custom code
- [ ] Use retry mechanisms for network operations
- [ ] Implement proper cleanup with registered handlers

## 🎨 UI Standards

### Color Usage

- **Green** (`$GREEN`): Success messages, positive status
- **Red** (`$RED`): Errors, failures, critical warnings
- **Yellow** (`$YELLOW`): Warnings, cautions, important notices
- **Blue** (`$BLUE`): Information, headers, neutral status
- **Cyan** (`$CYAN`): Section headers, highlights
- **Bold** (`$BOLD`): Emphasis, headers

### Message Formatting

```bash
print_success "Operation completed"          # ✓ Operation completed
print_error "Failed to connect"             # ✗ Failed to connect
print_warning "Low disk space"              # ⚠ Low disk space
print_info "Processing file..."             # ℹ Processing file...
print_header "Installation"                 # === Installation ===
```

## 🔒 Security Standards

### Permission Checking

```bash
# Script requires root
init_script "installer" true

# Script checks but doesn't require root
init_script "checker" false
if [[ $EUID -ne 0 ]]; then
    print_warning "Some features require root"
fi

# Custom permission check
if ! check_vm_group_membership; then
    print_error "User must be in libvirtd group"
    exit $EXIT_PERMISSION_DENIED
fi
```

### Safe Operations

```bash
# Always backup before modifying
backup_file "/etc/important.conf"

# Create directories safely
create_directory "/var/lib/myapp" "myuser:mygroup" "750"

# Validate input
validate_vm_name "$user_input" || exit 1
```

## 📊 Benefits Achieved

### Code Reduction
- **274** color definition blocks removed
- **76** logging function duplicates eliminated
- **41** permission check variants consolidated
- **~40%** average reduction in script size

### Consistency Improvements
- Uniform error messages across all scripts
- Consistent logging format with timestamps
- Standardized UI elements and formatting
- Predictable script behavior

### Maintenance Benefits
- Bug fixes applied globally
- New features available to all scripts
- Reduced testing surface area
- Easier onboarding for contributors

## 🚀 Best Practices

### 1. Always Initialize

```bash
# Good
init_script "my-script" false

# Better - with all options
init_script "my-script" true true  # require_root, load_libs
```

### 2. Use Appropriate Logging

```bash
log_info "Normal operation message"
log_warn "Something might be wrong"
log_error "Operation failed"
log_debug "Detailed debug info"  # Only shown with DEBUG=true
```

### 3. Handle Errors Gracefully

```bash
# Register cleanup
_register_cleanup "rm -f /tmp/myfile.$$"

# Use retry for network operations
retry_with_backoff 3 2 curl -sf https://example.com || {
    print_error "Failed to download after retries"
    exit 1
}
```

### 4. Provide User Feedback

```bash
# For long operations
for i in {1..100}; do
    do_something
    show_progress $i 100
done

# For background tasks
long_task &
show_spinner $!
```

## 🔍 Troubleshooting

### Library Not Found

```bash
# Fallback pattern
HYPERVISOR_SCRIPTS="${HYPERVISOR_SCRIPTS:-/etc/hypervisor/scripts}"
source "${HYPERVISOR_SCRIPTS}/lib/common.sh" 2>/dev/null || {
    echo "ERROR: Cannot load common library" >&2
    echo "Please ensure Hyper-NixOS libraries are installed" >&2
    exit 1
}
```

### Color Output Issues

```bash
# Force colors even in non-TTY
export FORCE_COLOR=1

# Disable colors for scripts/logs
export NO_COLOR=1
```

### Performance Concerns

The libraries use caching where appropriate:
- System detection results are cached
- Required binaries are checked once
- Color definitions are exported to subshells

## 📈 Future Enhancements

1. **Localization Support**: Add message translation
2. **Plugin System**: Allow custom library extensions
3. **Testing Framework**: Automated testing for library functions
4. **Performance Metrics**: Built-in timing and profiling
5. **Remote Execution**: Support for distributed operations

## 📚 Related Documentation

- [Code Duplication Analysis](./CODE_DUPLICATION_ANALYSIS.md)
- [Library Migration Example](../lib/migration-example.sh)
- [Common Library Reference](../lib/common.sh)
- [UI Library Reference](../lib/ui.sh)
- [System Library Reference](../lib/system.sh)