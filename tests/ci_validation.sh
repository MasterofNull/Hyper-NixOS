#!/usr/bin/env bash
#
# CI Validation Script
# Performs validation suitable for CI environment (no libvirt needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Hyper-NixOS CI Validation Suite                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_file() {
  local name="$1"
  local file="$2"
  
  echo -n "• $name... "
  if [[ -f "$ROOT_DIR/$file" ]]; then
    echo -e "${GREEN}✓${NC}"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo -e "${RED}✗ MISSING${NC}"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

check_dir() {
  local name="$1"
  local dir="$2"
  
  echo -n "• $name... "
  if [[ -d "$ROOT_DIR/$dir" ]]; then
    echo -e "${GREEN}✓${NC}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}✗ MISSING${NC}"
    ((FAILED++))
    return 1
  fi
}

echo "━━━ Core Files ━━━"
check_file "README" "README.md"
check_file "Credits" "CREDITS.md"
check_file "Enterprise Quick Start" "docs/user-guides/ENTERPRISE_QUICK_START.md"

echo ""
echo "━━━ Directories ━━━"
check_dir "Scripts" "scripts"
check_dir "Modules" "modules"
check_dir "Tests" "tests"
check_dir "Documentation" "docs"

echo ""
echo "━━━ Critical Scripts ━━━"
check_file "System installer" "scripts/system_installer.sh"
check_file "Menu script" "scripts/menu.sh"
check_file "Setup wizard" "scripts/setup_wizard.sh"
check_file "Test runner" "tests/run_all_tests.sh"

echo ""
echo "━━━ Configuration Files ━━━"
check_file "Main config" "configuration.nix"
check_file "Hardware config" "hardware-configuration.nix"
check_file "Security base" "modules/security/base.nix"
check_file "Security profiles" "modules/security/profiles.nix"
check_file "Monitoring prometheus" "modules/monitoring/prometheus.nix"
check_file "Cache optimization" "modules/core/cache-optimization.nix"

echo ""
echo "━━━ Additional Modules ━━━"
check_file "Centralized logging" "modules/monitoring/logging.nix"
check_file "Virtualization" "modules/virtualization/libvirt.nix"
check_file "GUI desktop" "modules/gui/desktop.nix"
check_file "Web dashboard" "modules/web/dashboard.nix"
check_file "Network firewall" "modules/network-settings/firewall.nix"
check_file "Storage encryption" "modules/storage-management/encryption.nix"

echo ""
echo "━━━ Management Scripts ━━━"
check_file "VM scheduler" "scripts/vm_scheduler.sh"
check_file "VM clone" "scripts/vm_clone.sh"
check_file "Security audit" "scripts/quick_security_audit.sh"
check_file "Health checks" "scripts/enhanced_health_checks.sh"

echo ""
echo "━━━ Documentation ━━━"
check_file "Script reference" "docs/SCRIPT_REFERENCE.md"
check_file "User guide" "docs/USER_GUIDE.md"
check_file "Educational philosophy" "docs/EDUCATIONAL_PHILOSOPHY.md"

echo ""
echo "━━━ GitHub Actions ━━━"
check_file "CI workflow" ".github/workflows/test.yml"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Sysctl Organization Validation                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -n "• Checking for duplicate sysctls... "
if "$ROOT_DIR/scripts/validate-sysctl-organization.sh" > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC}"
  ((PASSED++))
else
  echo -e "${RED}✗ DUPLICATES FOUND${NC}"
  "$ROOT_DIR/scripts/validate-sysctl-organization.sh"
  ((FAILED++))
fi

echo ""
echo "━━━ Bash Syntax Check ━━━"
syntax_errors=0
for script in "$ROOT_DIR"/scripts/*.sh; do
  if [[ -f "$script" ]]; then
    name=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
      echo -e "• $name... ${GREEN}✓${NC}"
      PASSED=$((PASSED + 1))
    else
      echo -e "• $name... ${RED}✗ SYNTAX ERROR${NC}"
      FAILED=$((FAILED + 1))
      syntax_errors=1
    fi
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                      VALIDATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All validation checks passed!${NC}"
  echo ""
  echo "The codebase is ready for:"
  echo "  • CI/CD pipeline"
  echo "  • NixOS deployment"
  echo "  • Production use"
  exit 0
else
  echo -e "${RED}✗ $FAILED validation checks failed${NC}"
  echo ""
  echo "Please fix the issues above before deploying"
  exit 1
fi
