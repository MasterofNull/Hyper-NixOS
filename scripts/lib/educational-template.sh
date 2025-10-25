#!/bin/bash
# Educational Template Functions for Hyper-NixOS Scripts
# Implements Pillar 3: Education-First Design
#
# Usage: source this file at the beginning of any wizard or interactive script

# Color codes (import from ui.sh if available, otherwise define)
if [ -z "$BLUE" ]; then
  BLUE='\033[0;34m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  NC='\033[0m' # No Color
fi

# ============================================================================
# WHAT: Explain the immediate action being taken
# ============================================================================
explain_what() {
  local action="$1"
  local description="$2"

  echo ""
  echo -e "${BLUE}━━━ WHAT WE'RE DOING ━━━${NC}"
  echo -e "${BLUE}Action:${NC} $action"
  echo -e "${BLUE}Description:${NC} $description"
  echo ""
}

# ============================================================================
# WHY: Explain the reason and impact
# ============================================================================
explain_why() {
  local reason="$1"
  local impact="$2"

  echo -e "${YELLOW}━━━ WHY THIS MATTERS ━━━${NC}"
  echo -e "${YELLOW}Reason:${NC} $reason"
  echo -e "${YELLOW}Impact:${NC} $impact"
  echo ""
}

# ============================================================================
# HOW: Explain the technical implementation
# ============================================================================
explain_how() {
  local steps="$1"

  echo -e "${GREEN}━━━ HOW IT WORKS ━━━${NC}"
  echo -e "$steps"
  echo ""
}

# ============================================================================
# TRANSFERABLE SKILL: Highlight portable knowledge
# ============================================================================
show_transferable_skill() {
  local skill="$1"
  local applications="$2"

  echo -e "${MAGENTA}━━━ TRANSFERABLE SKILL ━━━${NC}"
  echo -e "${MAGENTA}Skill:${NC} $skill"
  echo -e "${MAGENTA}You can use this:${NC} $applications"
  echo ""
}

# ============================================================================
# LEARNING CHECKPOINT: Pause for comprehension
# ============================================================================
learning_checkpoint() {
  local topic="$1"
  local key_points="$2"
  local skip_prompt="${3:-false}"

  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}📚 LEARNING CHECKPOINT${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}Topic:${NC} $topic"
  echo ""
  echo -e "${CYAN}Key Points:${NC}"
  echo -e "$key_points"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ "$skip_prompt" != "true" ]; then
    echo ""
    read -p "Press Enter when you're ready to continue..."
  fi
  echo ""
}

# ============================================================================
# EDUCATIONAL CONTEXT: Provide broader context for decisions
# ============================================================================
educational_context() {
  local context_type="$1" # "concept", "decision", "alternative", "pitfall"
  local title="$2"
  local content="$3"

  local icon="💡"
  case "$context_type" in
    concept)      icon="📖" ;;
    decision)     icon="🤔" ;;
    alternative)  icon="🔀" ;;
    pitfall)      icon="⚠️" ;;
    tip)          icon="💡" ;;
  esac

  echo -e "${CYAN}${icon} ${title}${NC}"
  echo -e "$content"
  echo ""
}

# ============================================================================
# COMPARE OPTIONS: Help users understand trade-offs
# ============================================================================
compare_options() {
  local option1_name="$1"
  local option1_pros="$2"
  local option1_cons="$3"
  local option2_name="$4"
  local option2_pros="$5"
  local option2_cons="$6"

  echo -e "${YELLOW}━━━ COMPARING YOUR OPTIONS ━━━${NC}"
  echo ""
  echo -e "${GREEN}Option 1: $option1_name${NC}"
  echo -e "  ${GREEN}✓ Pros:${NC} $option1_pros"
  echo -e "  ${YELLOW}✗ Cons:${NC} $option1_cons"
  echo ""
  echo -e "${GREEN}Option 2: $option2_name${NC}"
  echo -e "  ${GREEN}✓ Pros:${NC} $option2_pros"
  echo -e "  ${YELLOW}✗ Cons:${NC} $option2_cons"
  echo ""
}

# ============================================================================
# SHOW EXAMPLE: Demonstrate a concept with example
# ============================================================================
show_example() {
  local title="$1"
  local example="$2"
  local explanation="$3"

  echo -e "${CYAN}━━━ EXAMPLE: $title ━━━${NC}"
  echo ""
  echo -e "${GREEN}$example${NC}"
  echo ""
  if [ -n "$explanation" ]; then
    echo -e "$explanation"
    echo ""
  fi
}

# ============================================================================
# LINK TO DOCS: Point users to deeper information
# ============================================================================
link_to_docs() {
  local topic="$1"
  local doc_path="$2"

  echo -e "${BLUE}📚 Want to learn more about $topic?${NC}"
  echo -e "${BLUE}   Read: $doc_path${NC}"
  echo ""
}

# ============================================================================
# PROGRESSIVE DISCLOSURE: Offer optional deep dive
# ============================================================================
progressive_disclosure() {
  local topic="$1"
  local simple_explanation="$2"
  local detailed_explanation="$3"

  echo -e "$simple_explanation"
  echo ""
  read -p "Want to learn more about $topic? (y/N): " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${CYAN}━━━ DEEP DIVE: $topic ━━━${NC}"
    echo -e "$detailed_explanation"
    echo ""
    read -p "Press Enter to continue..."
  fi
  echo ""
}

# ============================================================================
# COMMAND EXPLANATION: Break down a complex command
# ============================================================================
explain_command() {
  local command="$1"
  shift
  local explanations=("$@")

  echo -e "${GREEN}Command being run:${NC}"
  echo -e "  ${CYAN}$command${NC}"
  echo ""
  echo -e "${GREEN}What each part does:${NC}"

  for explanation in "${explanations[@]}"; do
    echo -e "  • $explanation"
  done
  echo ""
}

# ============================================================================
# BEST PRACTICE: Highlight industry standards
# ============================================================================
show_best_practice() {
  local practice="$1"
  local reasoning="$2"

  echo -e "${GREEN}✓ BEST PRACTICE${NC}"
  echo -e "  $practice"
  echo ""
  echo -e "${GREEN}Why this is recommended:${NC}"
  echo -e "  $reasoning"
  echo ""
}

# ============================================================================
# COMMON MISTAKE: Warn about typical pitfalls
# ============================================================================
warn_common_mistake() {
  local mistake="$1"
  local consequence="$2"
  local solution="$3"

  echo -e "${YELLOW}⚠️  COMMON MISTAKE TO AVOID${NC}"
  echo -e "  ${YELLOW}Mistake:${NC} $mistake"
  echo -e "  ${YELLOW}Why it's a problem:${NC} $consequence"
  echo -e "  ${GREEN}Do this instead:${NC} $solution"
  echo ""
}

# ============================================================================
# REAL WORLD SCENARIO: Connect to practical use cases
# ============================================================================
real_world_scenario() {
  local scenario_name="$1"
  local description="$2"

  echo -e "${CYAN}🌍 REAL-WORLD SCENARIO: $scenario_name${NC}"
  echo -e "$description"
  echo ""
}

# ============================================================================
# TRACK LEARNING PROGRESS: Integration with progress system
# ============================================================================
track_learning_milestone() {
  local category="$1"
  local milestone="$2"

  # If progress tracking is available, record it
  if command -v hv-track-progress >/dev/null 2>&1; then
    hv-track-progress record "${USER:-system}" "$category" "$milestone" 2>/dev/null || true
  fi
}

# ============================================================================
# EDUCATIONAL HEADER: Start of learning section
# ============================================================================
educational_header() {
  local section_name="$1"

  echo ""
  echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║$(printf "%63s" " " | sed "s/ /═/g")║${NC}"
  echo -e "${BLUE}║  📚 LEARNING SECTION: $(printf "%-40s" "$section_name")║${NC}"
  echo -e "${BLUE}║$(printf "%63s" " " | sed "s/ /═/g")║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ============================================================================
# QUIZ/SELF-CHECK: Optional comprehension check
# ============================================================================
self_check_question() {
  local question="$1"
  local correct_answer="$2"
  local explanation="$3"

  echo -e "${CYAN}📝 Self-Check Question:${NC}"
  echo -e "   $question"
  echo ""
  read -p "Your answer: " user_answer
  echo ""

  # Simple case-insensitive comparison
  if [[ "${user_answer,,}" == "${correct_answer,,}" ]] || \
     [[ "${user_answer,,}" =~ ${correct_answer,,} ]]; then
    echo -e "${GREEN}✓ Correct!${NC}"
  else
    echo -e "${YELLOW}Not quite. The answer is: $correct_answer${NC}"
  fi

  if [ -n "$explanation" ]; then
    echo ""
    echo -e "${CYAN}Explanation:${NC}"
    echo -e "$explanation"
  fi
  echo ""
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================
# Make all functions available to scripts that source this file
export -f explain_what
export -f explain_why
export -f explain_how
export -f show_transferable_skill
export -f learning_checkpoint
export -f educational_context
export -f compare_options
export -f show_example
export -f link_to_docs
export -f progressive_disclosure
export -f explain_command
export -f show_best_practice
export -f warn_common_mistake
export -f real_world_scenario
export -f track_learning_milestone
export -f educational_header
export -f self_check_question
