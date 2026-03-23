#!/usr/bin/env bash
# Security Remediation Progress Check
# Part of Phase 06: Security Remediation
# Generated: 2026-03-23

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Security Remediation Progress Check${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${YELLOW}▶ $1${NC}"
    echo "────────────────────────────────────────"
}

check_shellcheck() {
    print_section "ShellCheck Analysis"

    local errors warnings notes

    cd "$REPO_ROOT" || exit 1

    # Count by severity - store output first to avoid multiple shellcheck runs
    local shellcheck_output
    shellcheck_output=$(find . -name "*.sh" -type f -print0 2>/dev/null | xargs -0 shellcheck --format=gcc 2>&1 || true)

    errors=$(echo "$shellcheck_output" | grep -c ': error:' 2>/dev/null || true)
    warnings=$(echo "$shellcheck_output" | grep -c ': warning:' 2>/dev/null || true)
    notes=$(echo "$shellcheck_output" | grep -c ': note:' 2>/dev/null || true)

    # Ensure we have clean integers
    errors=$(echo "${errors:-0}" | tr -cd '0-9')
    warnings=$(echo "${warnings:-0}" | tr -cd '0-9')
    notes=$(echo "${notes:-0}" | tr -cd '0-9')

    # Default to 0 if empty
    errors=${errors:-0}
    warnings=${warnings:-0}
    notes=${notes:-0}

    local total
    total=$((errors + warnings + notes))

    # Targets
    local target_errors=0
    local target_warnings=200
    local target_notes=300

    echo "Category      | Current | Target  | Status"
    echo "──────────────|─────────|─────────|────────"

    if [[ "$errors" -le "$target_errors" ]]; then
        echo -e "Errors        | ${GREEN}$errors${NC}       | $target_errors       | ${GREEN}✓ PASS${NC}"
    else
        echo -e "Errors        | ${RED}$errors${NC}      | $target_errors       | ${RED}✗ FAIL${NC}"
    fi

    if [[ "$warnings" -le "$target_warnings" ]]; then
        echo -e "Warnings      | ${GREEN}$warnings${NC}     | $target_warnings     | ${GREEN}✓ PASS${NC}"
    else
        echo -e "Warnings      | ${RED}$warnings${NC}     | $target_warnings     | ${RED}✗ WORK${NC}"
    fi

    if [[ "$notes" -le "$target_notes" ]]; then
        echo -e "Notes         | ${GREEN}$notes${NC}     | $target_notes     | ${GREEN}✓ PASS${NC}"
    else
        echo -e "Notes         | ${YELLOW}$notes${NC}     | $target_notes     | ${YELLOW}○ INFO${NC}"
    fi

    echo "──────────────|─────────|─────────|────────"
    echo "Total         | $total    | -       |"

    # Return error count for CI
    echo "$errors"
}

check_security_patterns() {
    print_section "Security Pattern Analysis"

    cd "$REPO_ROOT" || exit 1

    local eval_count rm_rf_count
    eval_count=$(grep -r "eval\s" --include="*.sh" . 2>/dev/null | wc -l || echo "0")
    rm_rf_count=$(grep -rn "rm -rf" --include="*.sh" . 2>/dev/null | grep -v '.bats' | wc -l || echo "0")

    echo "Pattern              | Count | Target | Status"
    echo "─────────────────────|───────|────────|────────"

    if [[ "$eval_count" -le 10 ]]; then
        echo -e "eval usages          | ${GREEN}$eval_count${NC}     | 10     | ${GREEN}✓ PASS${NC}"
    else
        echo -e "eval usages          | ${RED}$eval_count${NC}     | 10     | ${RED}✗ FAIL${NC}"
    fi

    echo -e "rm -rf patterns      | $rm_rf_count     | -      | ${YELLOW}○ AUDIT${NC}"
}

check_top_violations() {
    print_section "Top ShellCheck Violations"

    cd "$REPO_ROOT" || exit 1

    echo "Code    | Count | Description"
    echo "────────|───────|─────────────────────────────────────────────"

    find . -name "*.sh" -type f 2>/dev/null | \
        xargs shellcheck --format=gcc 2>&1 | \
        grep -oP '\[(SC[0-9]+)\]' | \
        sort | uniq -c | sort -rn | head -10 | \
        while read -r count code; do
            code_num="${code//[^0-9]/}"
            case "$code_num" in
                2155) desc="Declare and assign separately";;
                2162) desc="read without -r mangles backslashes";;
                2086) desc="Double quote to prevent globbing";;
                2034) desc="Unused variable";;
                1091) desc="Not following sourced files";;
                2126) desc="Consider grep -c";;
                2168) desc="local outside function";;
                2129) desc="Consider grouping redirections";;
                2199) desc="Arrays in [[ ]]";;
                2164) desc="cd without || exit";;
                *) desc="See shellcheck wiki";;
            esac
            printf "%-7s | %-5s | %s\n" "$code" "$count" "$desc"
        done
}

check_file_issues() {
    print_section "Files with Most Issues (Top 10)"

    cd "$REPO_ROOT" || exit 1

    echo "Issues | File"
    echo "───────|────────────────────────────────────────────────────"

    find . -name "*.sh" -type f 2>/dev/null | \
        xargs shellcheck --format=gcc 2>&1 | \
        grep -oP '^[^:]+' | \
        sort | uniq -c | sort -rn | head -10 | \
        while read -r count file; do
            printf "%-6s | %s\n" "$count" "$file"
        done
}

check_ai_harness() {
    print_section "AI Harness Status"

    if command -v aq-qa &>/dev/null; then
        local result
        result=$(aq-qa 0 --json 2>&1 | jq -r '.passed, .failed' 2>/dev/null || echo "0 0")
        local passed failed
        passed=$(echo "$result" | head -1)
        failed=$(echo "$result" | tail -1)

        if [[ "$failed" == "0" ]]; then
            echo -e "AI Harness: ${GREEN}$passed passed, $failed failed${NC}"
        else
            echo -e "AI Harness: ${YELLOW}$passed passed, $failed failed${NC}"
        fi
    else
        echo -e "AI Harness: ${YELLOW}aq-qa not available${NC}"
    fi
}

generate_summary() {
    print_section "Summary"

    cd "$REPO_ROOT" || exit 1

    # Use stored shellcheck output to avoid re-running
    local shellcheck_output
    shellcheck_output=$(find . -name "*.sh" -type f -print0 2>/dev/null | xargs -0 shellcheck --format=gcc 2>&1 || true)

    local errors
    errors=$(echo "$shellcheck_output" | grep -c ': error:' || true)
    errors="${errors:-0}"
    errors=$(echo "$errors" | tr -d '[:space:]')

    if [[ "$errors" -eq 0 ]]; then
        echo -e "${GREEN}✓ Slice 6.1 (Critical Errors): COMPLETE${NC}"
    else
        echo -e "${RED}✗ Slice 6.1 (Critical Errors): $errors errors remaining${NC}"
    fi

    local warnings
    warnings=$(echo "$shellcheck_output" | grep -c ': warning:' || true)
    warnings="${warnings:-0}"
    warnings=$(echo "$warnings" | tr -d '[:space:]')

    if [[ "$warnings" -le 200 ]]; then
        echo -e "${GREEN}✓ Slice 6.2 (Warnings): COMPLETE ($warnings/200)${NC}"
    else
        echo -e "${YELLOW}○ Slice 6.2 (Warnings): IN PROGRESS ($warnings/200)${NC}"
    fi

    local eval_count
    eval_count=$(grep -r "eval\s" --include="*.sh" . 2>/dev/null | wc -l || true)
    eval_count="${eval_count:-0}"
    eval_count=$(echo "$eval_count" | tr -d '[:space:]')

    if [[ "$eval_count" -le 10 ]]; then
        echo -e "${GREEN}✓ Slice 6.3 (Security Patterns): COMPLETE ($eval_count eval)${NC}"
    else
        echo -e "${YELLOW}○ Slice 6.3 (Security Patterns): IN PROGRESS ($eval_count eval)${NC}"
    fi
}

main() {
    print_header

    echo "Repository: $REPO_ROOT"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

    check_shellcheck
    check_security_patterns
    check_top_violations
    check_file_issues
    check_ai_harness
    generate_summary

    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Run 'shellcheck <file>' to see detailed issues per file${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
