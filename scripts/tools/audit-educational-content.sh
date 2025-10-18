#!/bin/bash
# Educational Content Compliance Auditor
# Checks all scripts for educational content requirements

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📚 Educational Content Compliance Audit${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Counters
total_scripts=0
compliant_scripts=0
partial_scripts=0
noncompliant_scripts=0

# Educational markers to check for
MARKERS=(
  "explain_what"
  "explain_why"
  "explain_how"
  "show_transferable_skill"
  "learning_checkpoint"
)

ALT_MARKERS=(
  "WHAT WE'RE DOING"
  "WHY THIS MATTERS"
  "HOW IT WORKS"
  "TRANSFERABLE SKILL"
  "LEARNING"
)

check_script_education() {
  local script="$1"
  local script_name=$(basename "$script")

  ((total_scripts++))

  # Count modern markers (from educational-template.sh)
  local modern_count=0
  for marker in "${MARKERS[@]}"; do
    if grep -q "$marker" "$script" 2>/dev/null; then
      ((modern_count++))
    fi
  done

  # Count legacy markers (inline education)
  local legacy_count=0
  for marker in "${ALT_MARKERS[@]}"; do
    if grep -q "$marker" "$script" 2>/dev/null; then
      ((legacy_count++))
    fi
  done

  # Check if sources educational template
  local sources_template=false
  if grep -q "educational-template.sh" "$script" 2>/dev/null; then
    sources_template=true
  fi

  # Determine compliance level
  local status=""
  local color=""

  if $sources_template && [ $modern_count -ge 3 ]; then
    # Fully compliant - uses template and has multiple educational markers
    status="✓ COMPLIANT"
    color="$GREEN"
    ((compliant_scripts++))
  elif [ $modern_count -ge 2 ] || [ $legacy_count -ge 2 ]; then
    # Partially compliant - has some educational content
    status="◐ PARTIAL"
    color="$YELLOW"
    ((partial_scripts++))
  else
    # Non-compliant - missing educational content
    status="✗ MISSING"
    color="$RED"
    ((noncompliant_scripts++))
  fi

  # Output with details
  printf "${color}%-12s${NC} %-40s " "$status" "$script_name"

  # Show markers found
  if $sources_template; then
    printf "${GREEN}[uses template]${NC} "
  fi
  if [ $modern_count -gt 0 ]; then
    printf "${BLUE}modern:%d${NC} " "$modern_count"
  fi
  if [ $legacy_count -gt 0 ]; then
    printf "${YELLOW}legacy:%d${NC} " "$legacy_count"
  fi

  echo ""
}

# Check wizard scripts (highest priority)
echo -e "${BLUE}Checking Wizards:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

wizard_count=0
while IFS= read -r -d '' wizard; do
  [ -f "$wizard" ] || continue
  check_script_education "$wizard"
  ((wizard_count++))
done < <(find "$SCRIPT_DIR" -type f -name "*wizard*.sh" -print0 2>/dev/null || true)

if [ $wizard_count -eq 0 ]; then
  echo "No wizards found"
fi
echo ""

# Check setup scripts
echo -e "${BLUE}Checking Setup Scripts:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_count=0
while IFS= read -r -d '' script; do
  [ -f "$script" ] || continue
  check_script_education "$script"
  ((setup_count++))
done < <(find "$SCRIPT_DIR/setup" -type f -name "*.sh" -print0 2>/dev/null || true)

if [ $setup_count -eq 0 ]; then
  echo "No setup scripts found"
fi
echo ""

# Check tutorial scripts
echo -e "${BLUE}Checking Tutorials:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

tutorial_count=0
while IFS= read -r -d '' tutorial; do
  [ -f "$tutorial" ] || continue
  check_script_education "$tutorial"
  ((tutorial_count++))
done < <(find "$SCRIPT_DIR/tutorials" -type f -name "*.sh" -print0 2>/dev/null || true)

if [ $tutorial_count -eq 0 ]; then
  echo "No tutorial scripts found (this is a gap!)"
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total scripts checked: $total_scripts"
echo -e "  ${GREEN}Fully compliant:       $compliant_scripts${NC}"
echo -e "  ${YELLOW}Partially compliant:   $partial_scripts${NC}"
echo -e "  ${RED}Non-compliant:         $noncompliant_scripts${NC}"
echo ""

# Calculate compliance percentage
if [ $total_scripts -gt 0 ]; then
  full_compliance_pct=$((compliant_scripts * 100 / total_scripts))
  any_compliance_pct=$(( (compliant_scripts + partial_scripts) * 100 / total_scripts ))

  echo "  Full compliance:       ${full_compliance_pct}%"
  echo "  Partial compliance:    ${any_compliance_pct}%"
  echo ""
fi

# Recommendations
echo -e "${BLUE}Recommendations:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $noncompliant_scripts -gt 0 ]; then
  echo -e "${YELLOW}•${NC} Add educational content to $noncompliant_scripts non-compliant scripts"
  echo "  Template: scripts/lib/educational-template.sh"
fi

if [ $partial_scripts -gt 0 ]; then
  echo -e "${YELLOW}•${NC} Enhance $partial_scripts partially compliant scripts"
  echo "  Add 'source \$(dirname \"\$0\")/lib/educational-template.sh'"
fi

if [ $tutorial_count -eq 0 ]; then
  echo -e "${RED}•${NC} Create interactive tutorials (currently missing!)"
  echo "  Priority: networking, storage, security, backup, monitoring"
fi

echo ""

# Exit status
if [ $compliant_scripts -eq $total_scripts ] && [ $total_scripts -gt 0 ]; then
  echo -e "${GREEN}✓ All scripts are educationally compliant!${NC}"
  exit 0
elif [ $any_compliance_pct -ge 70 ]; then
  echo -e "${YELLOW}⚠ Good progress, but more work needed${NC}"
  exit 0
else
  echo -e "${RED}✗ Significant educational content gaps${NC}"
  exit 1
fi
