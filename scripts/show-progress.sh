#!/bin/bash
# Display user's learning progress in a friendly format
set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

USER_NAME="${1:-$USER}"

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}║          ${BOLD}🎓 Your Hyper-NixOS Learning Journey${NC}${CYAN}              ║${NC}"
echo -e "${CYAN}║                                                               ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if progress tracking is available
if ! command -v hv-track-progress >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ Progress tracking not enabled${NC}"
  echo "Enable in configuration:"
  echo "  hypervisor.education.progressTracking.enable = true;"
  exit 1
fi

# Show statistics
echo -e "${BLUE}${BOLD}Progress Statistics${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
hv-track-progress stats "$USER_NAME"

echo ""
echo -e "${GREEN}${BOLD}Recent Activity${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
hv-track-progress show "$USER_NAME" 10

echo ""
echo -e "${MAGENTA}${BOLD}Next Steps${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "• Continue following your learning path"
echo -e "• Run: ${BOLD}hv help${NC} to see available tutorials"
echo -e "• View full curriculum: ${BOLD}cat /usr/share/doc/hypervisor/LEARNING_PATH.md${NC}"
echo ""

# Motivational message based on progress
total_items=$(hv-track-progress stats "$USER_NAME" 2>/dev/null | grep "Total items" | grep -o '[0-9]*' || echo 0)

if [ "$total_items" -eq 0 ]; then
  echo -e "${CYAN}💡 Tip: Start with 'hv discover' to begin your journey!${NC}"
elif [ "$total_items" -lt 10 ]; then
  echo -e "${CYAN}💡 You're making progress! ${GREEN}$((10 - total_items))${CYAN} more items until your first achievement!${NC}"
elif [ "$total_items" -lt 25 ]; then
  echo -e "${CYAN}🌟 Great work! ${GREEN}$((25 - total_items))${CYAN} more to reach Competent Curator!${NC}"
elif [ "$total_items" -lt 50 ]; then
  echo -e "${CYAN}🚀 Excellent progress! ${GREEN}$((50 - total_items))${CYAN} more to Advanced Architect!${NC}"
else
  echo -e "${CYAN}💎 Outstanding! You're well on your way to mastery!${NC}"
fi

echo ""
