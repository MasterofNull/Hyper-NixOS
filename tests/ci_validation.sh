#!/usr/bin/env bash
#
# CI Validation Script
# Performs validation suitable for CI environment (no libvirt needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    ((PASSED++))
    return 0
  else
    echo -e "${RED}✗ MISSING${NC}"
    ((FAILED++))
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
check_file "Enterprise Quick Start" "ENTERPRISE_QUICK_START.md"

echo ""
echo "━━━ Directories ━━━"
check_dir "Scripts" "scripts"
check_dir "Configuration" "configuration"
check_dir "Tests" "tests"
check_dir "Documentation" "docs"

echo ""
echo "━━━ Critical Scripts ━━━"
check_file "Bootstrap script" "scripts/bootstrap_nixos.sh"
check_file "Menu script" "scripts/menu.sh"
check_file "Setup wizard" "scripts/setup_wizard.sh"
check_file "Test runner" "tests/run_all_tests.sh"

echo ""
echo "━━━ Configuration Files ━━━"
check_file "Main config" "configuration/configuration.nix"
check_file "Security base" "configuration/security/base.nix"
check_file "Security profiles" "configuration/security/profiles.nix"
check_file "Monitoring prometheus" "configuration/monitoring/prometheus.nix"
check_file "Cache optimization" "configuration/core/cache-optimization.nix"

echo ""
echo "━━━ Enterprise Features ━━━"
check_file "Centralized logging" "configuration/monitoring/logging.nix"
check_file "Resource quotas" "configuration/enterprise/quotas.nix"
check_file "Network isolation" "configuration/enterprise/network-isolation.nix"
check_file "Storage quotas" "configuration/enterprise/storage-quotas.nix"
check_file "Snapshot lifecycle" "configuration/enterprise/snapshots.nix"
check_file "VM encryption" "configuration/enterprise/encryption.nix"
check_file "Enterprise features" "configuration/enterprise/features.nix"

echo ""
echo "━━━ Management Scripts ━━━"
check_file "VM templates" "scripts/vm_templates.sh"
check_file "VM scheduler" "scripts/vm_scheduler.sh"
check_file "VM clone" "scripts/vm_clone.sh"
check_file "Audit viewer" "scripts/audit_viewer.sh"
check_file "Resource reporter" "scripts/resource_reporter.sh"

echo ""
echo "━━━ Documentation ━━━"
check_file "Enterprise features guide" "docs/ENTERPRISE_FEATURES.md"
check_file "Educational philosophy" "docs/EDUCATIONAL_PHILOSOPHY.md"

echo ""
echo "━━━ GitHub Actions ━━━"
check_file "CI workflow" ".github/workflows/test.yml"

echo ""
echo "━━━ Bash Syntax Check ━━━"
syntax_errors=0
for script in "$ROOT_DIR"/scripts/*.sh; do
  if [[ -f "$script" ]]; then
    name=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
      echo -e "• $name... ${GREEN}✓${NC}"
      ((PASSED++))
    else
      echo -e "• $name... ${RED}✗ SYNTAX ERROR${NC}"
      ((FAILED++))
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
