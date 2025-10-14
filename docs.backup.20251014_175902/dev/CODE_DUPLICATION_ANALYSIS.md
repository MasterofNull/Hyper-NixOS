# Code Duplication Analysis for Hyper-NixOS

## 📊 Summary

Analysis of the Hyper-NixOS codebase reveals significant code duplication across scripts. By consolidating these into shared libraries, we can reduce redundancy, improve maintainability, and ensure consistency.

## 🔁 Major Duplication Patterns

### 1. Color Definitions (274 instances)

Nearly every script defines the same color codes:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color
```

**Scripts affected**: 40+ scripts across the codebase

### 2. Logging Functions (76 instances)

Multiple variations of logging functions exist:

```bash
# Variation 1: Simple echo with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Variation 2: ISO timestamp
log() {
    echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

# Variation 3: With log levels
log() {
    printf '%s [%s] %s\n' "$(date -Iseconds)" "${1:-INFO}" "${2:-}" >> "${LOG_FILE}"
}
```

**Common functions**: `log()`, `msg()`, `error()`, `warn()`, `success()`, `info()`

### 3. Root/Permission Checks (41 instances)

Various implementations of permission checking:

```bash
# Variation 1: Simple root check
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# Variation 2: With sudo elevation
require_root() {
    if [[ $EUID -ne 0 ]]; then
        exec sudo -E "$0" "$@"
    fi
}

# Variation 3: With options
check_root() {
    if [[ $EUID -ne 0 ]] && [[ "$1" != "--no-root" ]]; then
        echo "Run with sudo or use --no-root"
        exit 1
    fi
}
```

### 4. System Detection Functions

Multiple scripts implement their own system detection:

```bash
# CPU detection
SYSTEM_CPUS=$(nproc)

# Memory detection
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
SYSTEM_RAM=$((MEM_KB / 1024))

# Architecture detection
SYSTEM_ARCH=$(uname -m)
```

### 5. Error Handling Patterns

Common error handling setup:

```bash
set -euo pipefail
trap 'error_handler $?' ERR
```

### 6. Dialog/TUI Functions

Multiple implementations of dialog selection:

```bash
use_dialog() {
    if command -v dialog >/dev/null 2>&1; then
        echo "dialog"
    elif command -v whiptail >/dev/null 2>&1; then
        echo "whiptail"
    fi
}
```

## 📁 Existing Shared Libraries

### scripts/lib/common.sh

Already contains:
- Logging functions with levels
- Dependency checking
- VM name validation
- Permission management
- Error handling
- Security phase checks

### scripts/lib/TEMPLATE_PRIVILEGE_AWARE.sh

Template for privilege-aware scripts with:
- Standard privilege checking
- Phase permission validation
- Error codes

## 🎯 Proposed Consolidation

### 1. Create `scripts/lib/ui.sh`

Consolidate all UI-related functions:

```bash
#!/usr/bin/env bash
# UI Library for Hyper-NixOS

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m'

# UI functions
print_header() {
    local title="$1"
    echo -e "${BOLD}${BLUE}=== $title ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

# Progress indicators
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
```

### 2. Create `scripts/lib/system.sh`

Consolidate system detection and checks:

```bash
#!/usr/bin/env bash
# System Detection Library

# Cache for system info
declare -g SYSTEM_INFO_CACHED=false
declare -g SYSTEM_RAM_MB=0
declare -g SYSTEM_CPUS=0
declare -g SYSTEM_ARCH=""
declare -g SYSTEM_DISK_GB=0

# Detect system resources
detect_system_resources() {
    if [[ "$SYSTEM_INFO_CACHED" == "true" ]]; then
        return 0
    fi
    
    # RAM
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    SYSTEM_RAM_MB=$((mem_kb / 1024))
    
    # CPUs
    SYSTEM_CPUS=$(nproc)
    
    # Architecture
    SYSTEM_ARCH=$(uname -m)
    
    # Disk space
    SYSTEM_DISK_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    
    # GPU detection
    if lspci 2>/dev/null | grep -E "(VGA|3D)" | grep -iE "(nvidia|amd|intel)" > /dev/null; then
        SYSTEM_GPU="available"
    else
        SYSTEM_GPU="none"
    fi
    
    SYSTEM_INFO_CACHED=true
}

# Check minimum requirements
check_requirements() {
    local min_ram_mb="${1:-2048}"
    local min_cpus="${2:-2}"
    local min_disk_gb="${3:-20}"
    
    detect_system_resources
    
    local errors=()
    
    if [[ $SYSTEM_RAM_MB -lt $min_ram_mb ]]; then
        errors+=("Insufficient RAM: ${SYSTEM_RAM_MB}MB < ${min_ram_mb}MB required")
    fi
    
    if [[ $SYSTEM_CPUS -lt $min_cpus ]]; then
        errors+=("Insufficient CPUs: ${SYSTEM_CPUS} < ${min_cpus} required")
    fi
    
    if [[ $SYSTEM_DISK_GB -lt $min_disk_gb ]]; then
        errors+=("Insufficient disk: ${SYSTEM_DISK_GB}GB < ${min_disk_gb}GB required")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            print_error "$error"
        done
        return 1
    fi
    
    return 0
}
```

### 3. Enhance `scripts/lib/common.sh`

Add missing common functions:

```bash
# Enhanced root checking with options
check_root() {
    local require_root="${1:-true}"
    local allow_sudo_elevation="${2:-true}"
    
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    
    if [[ "$require_root" == "false" ]]; then
        return 0
    fi
    
    if [[ "$allow_sudo_elevation" == "true" ]] && command -v sudo >/dev/null 2>&1; then
        log_info "Elevating privileges with sudo..."
        exec sudo -E "$0" "$@"
    else
        print_error "This operation requires root privileges"
        exit 1
    fi
}

# Standard script initialization
init_script() {
    local script_name="${1:-$(basename "$0" .sh)}"
    local require_root="${2:-false}"
    
    # Set up logging
    init_logging "$script_name"
    
    # Source UI library
    source "${HYPERVISOR_SCRIPTS}/lib/ui.sh" 2>/dev/null || true
    
    # Check root if required
    if [[ "$require_root" == "true" ]]; then
        check_root
    fi
    
    # Log script start
    log_info "Starting $script_name"
}
```

## 🔧 Implementation Plan

### Phase 1: Create Core Libraries
1. Create `scripts/lib/ui.sh` with all UI functions
2. Create `scripts/lib/system.sh` with system detection
3. Enhance `scripts/lib/common.sh` with missing utilities

### Phase 2: Update Critical Scripts
1. Update installation scripts
2. Update feature management scripts
3. Update monitoring scripts

### Phase 3: Gradual Migration
1. Update remaining scripts to use libraries
2. Remove duplicated code
3. Test thoroughly

### Phase 4: Documentation
1. Document library functions
2. Create migration guide
3. Update development guidelines

## 📈 Benefits

1. **Code Reduction**: ~40% reduction in script size
2. **Consistency**: Uniform UI and behavior across scripts
3. **Maintainability**: Fix bugs in one place
4. **Performance**: Cached system detection
5. **Security**: Centralized security checks

## ⚠️ Risks and Mitigations

### Risk 1: Breaking Changes
**Mitigation**: Keep backward compatibility during transition

### Risk 2: Missing Library
**Mitigation**: Scripts should gracefully handle missing libraries

### Risk 3: Performance Impact
**Mitigation**: Use caching for expensive operations

## 🎯 Success Metrics

- Number of duplicate functions eliminated
- Lines of code reduced
- Script initialization time improved
- Bug reports related to inconsistent behavior reduced

## 📝 Example Migration

### Before:
```bash
#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Run as root${NC}"
        exit 1
    fi
}

# Script logic
```

### After:
```bash
#!/usr/bin/env bash

# Source common libraries
source /etc/hypervisor/scripts/lib/common.sh
source /etc/hypervisor/scripts/lib/ui.sh

# Initialize script
init_script "my-script" true  # true = requires root

# Script logic using library functions
print_success "Operation completed"
```

## 🚀 Next Steps

1. Review and approve consolidation plan
2. Create library files
3. Begin phased migration
4. Monitor for issues
5. Document lessons learned