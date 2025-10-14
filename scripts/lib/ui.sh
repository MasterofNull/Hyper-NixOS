#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS UI Library
# Provides consistent UI elements and formatting across all scripts
#

# Prevent multiple sourcing
if [[ -n "${_HYPERVISOR_UI_LOADED:-}" ]]; then
    return 0
fi
readonly _HYPERVISOR_UI_LOADED=1

# Color definitions (export for subshells)
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export BOLD='\033[1m'
export DIM='\033[2m'
export ITALIC='\033[3m'
export UNDERLINE='\033[4m'
export BLINK='\033[5m'
export REVERSE='\033[7m'
export STRIKE='\033[9m'
export NC='\033[0m' # No Color/Reset

# Unicode symbols (with ASCII fallbacks)
if [[ "${TERM:-}" =~ "256color" ]] || [[ "${COLORTERM:-}" == "truecolor" ]]; then
    export SYMBOL_SUCCESS="✓"
    export SYMBOL_ERROR="✗"
    export SYMBOL_WARNING="⚠"
    export SYMBOL_INFO="ℹ"
    export SYMBOL_ARROW="→"
    export SYMBOL_BULLET="•"
    export SYMBOL_ELLIPSIS="…"
else
    # ASCII fallbacks
    export SYMBOL_SUCCESS="[OK]"
    export SYMBOL_ERROR="[X]"
    export SYMBOL_WARNING="[!]"
    export SYMBOL_INFO="[i]"
    export SYMBOL_ARROW="->"
    export SYMBOL_BULLET="*"
    export SYMBOL_ELLIPSIS="..."
fi

# Print functions with consistent formatting
print_header() {
    local title="${1:-}"
    local width=${2:-60}
    local border=$(printf '=%.0s' $(seq 1 $width))
    echo -e "\n${BOLD}${BLUE}${border}${NC}"
    echo -e "${BOLD}${BLUE}$(printf "%-${width}s" " $title")${NC}"
    echo -e "${BOLD}${BLUE}${border}${NC}\n"
}

print_section() {
    local title="${1:-}"
    echo -e "\n${BOLD}${CYAN}=== $title ===${NC}"
}

print_success() {
    echo -e "${GREEN}${SYMBOL_SUCCESS}${NC} $*"
}

print_error() {
    echo -e "${RED}${SYMBOL_ERROR}${NC} $*" >&2
}

print_warning() {
    echo -e "${YELLOW}${SYMBOL_WARNING}${NC} $*"
}

print_info() {
    echo -e "${BLUE}${SYMBOL_INFO}${NC} $*"
}

print_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${DIM}[DEBUG] $*${NC}" >&2
    fi
}

# Formatted message with prefix
print_msg() {
    local prefix="${1:-INFO}"
    local message="${2:-}"
    local color="${3:-$NC}"
    echo -e "${color}[${prefix}]${NC} ${message}"
}

# Progress indicators
show_spinner() {
    local pid=$1
    local delay=${2:-0.1}
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    # ASCII fallback
    if [[ ! "${TERM:-}" =~ "256color" ]]; then
        spinstr='|/-\'
    fi
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " %c  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" $percent
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Ask for confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    local response
    
    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -r -p "$(echo -e "${YELLOW}${SYMBOL_WARNING}${NC} $prompt")" response
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Select from menu
select_option() {
    local prompt="${1:-Select an option:}"
    shift
    local options=("$@")
    local selected=0
    local key
    
    # Use standard select if not interactive
    if [[ ! -t 0 ]]; then
        PS3="$prompt "
        select opt in "${options[@]}"; do
            echo "$opt"
            return $((REPLY - 1))
        done
    fi
    
    # Interactive menu with arrow keys
    while true; do
        clear
        echo -e "${BOLD}$prompt${NC}\n"
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "${REVERSE}${SYMBOL_ARROW} ${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done
        
        # Read single character
        read -rsn1 key
        
        case "$key" in
            A) # Up arrow
                ((selected--))
                [[ $selected -lt 0 ]] && selected=$((${#options[@]} - 1))
                ;;
            B) # Down arrow
                ((selected++))
                [[ $selected -ge ${#options[@]} ]] && selected=0
                ;;
            "") # Enter
                echo "${options[$selected]}"
                return $selected
                ;;
            q|Q) # Quit
                return 255
                ;;
        esac
    done
}

# Show a banner
show_banner() {
    local text="${1:-Hyper-NixOS}"
    local version="${2:-v${HYPERVISOR_VERSION:-2.0}}"
    
    cat << EOF
${CYAN}
    __  __                                _   ___       ____  _____
   / / / /_  ______  ___  _____   ____   / | / (_)  __ / __ \/ ___/
  / /_/ / / / / __ \/ _ \/ ___/  / __ \ /  |/ / / |/_// / / /\__ \\ 
 / __  / /_/ / /_/ /  __/ /     / / / // /|  / />  < / /_/ /___/ /
/_/ /_/\__, / .___/\___/_/     /_/ /_//_/ |_/_/_/|_| \____//____/
      /____/_/                                       ${version}
${NC}
EOF
}

# Formatted table output
print_table_header() {
    local -a columns=("$@")
    local total_width=0
    
    # Calculate total width
    for col in "${columns[@]}"; do
        local width=${col#*:}
        ((total_width += width + 3))
    done
    
    # Print top border
    printf "+"
    for col in "${columns[@]}"; do
        local width=${col#*:}
        printf "%${width}s+" | tr ' ' '-'
    done
    echo
    
    # Print headers
    printf "|"
    for col in "${columns[@]}"; do
        local name=${col%:*}
        local width=${col#*:}
        printf " ${BOLD}%-$((width-2))s${NC} |" "$name"
    done
    echo
    
    # Print separator
    printf "+"
    for col in "${columns[@]}"; do
        local width=${col#*:}
        printf "%${width}s+" | tr ' ' '='
    done
    echo
}

print_table_row() {
    local -a columns=("$@")
    printf "|"
    for col in "${columns[@]}"; do
        printf " %-$((${#col}))s |" "$col"
    done
    echo
}

# Color output based on condition
colorize() {
    local condition="$1"
    local true_color="${2:-$GREEN}"
    local false_color="${3:-$RED}"
    local text="${4:-$condition}"
    
    if [[ "$condition" == "true" ]] || [[ "$condition" == "1" ]]; then
        echo -e "${true_color}${text}${NC}"
    else
        echo -e "${false_color}${text}${NC}"
    fi
}

# Export all functions
export -f print_header print_section print_success print_error print_warning
export -f print_info print_debug print_msg show_spinner show_progress
export -f confirm select_option show_banner print_table_header print_table_row
export -f colorize