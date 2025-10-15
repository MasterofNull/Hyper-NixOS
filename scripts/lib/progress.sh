#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155
#
# Hyper-NixOS Progress Bar and Status Indicator Library
# Copyright (C) 2024-2025 MasterofNull
#
# Provides visual feedback for long-running operations with:
# - Spinner animations
# - Progress bars
# - Download progress tracking
# - Status indicators
# - Error handling and reporting
#

# Terminal control codes
if [[ -t 1 ]]; then
    readonly TERM_BOLD='\033[1m'
    readonly TERM_DIM='\033[2m'
    readonly TERM_UNDERLINE='\033[4m'
    readonly TERM_RESET='\033[0m'
    readonly TERM_CLEAR_LINE='\033[2K'
    readonly TERM_SAVE_CURSOR='\033[s'
    readonly TERM_RESTORE_CURSOR='\033[u'
    readonly TERM_HIDE_CURSOR='\033[?25l'
    readonly TERM_SHOW_CURSOR='\033[?25h'
    readonly TERM_MOVE_UP='\033[1A'
    readonly TERM_MOVE_DOWN='\033[1B'
else
    readonly TERM_BOLD=''
    readonly TERM_DIM=''
    readonly TERM_UNDERLINE=''
    readonly TERM_RESET=''
    readonly TERM_CLEAR_LINE=''
    readonly TERM_SAVE_CURSOR=''
    readonly TERM_RESTORE_CURSOR=''
    readonly TERM_HIDE_CURSOR=''
    readonly TERM_SHOW_CURSOR=''
    readonly TERM_MOVE_UP=''
    readonly TERM_MOVE_DOWN=''
fi

# Colors (reuse from common.sh if available, otherwise define)
if [[ -z "${GREEN:-}" ]]; then
    if [[ -t 1 ]]; then
        readonly RED='\033[0;31m'
        readonly GREEN='\033[0;32m'
        readonly YELLOW='\033[1;33m'
        readonly BLUE='\033[0;34m'
        readonly MAGENTA='\033[0;35m'
        readonly CYAN='\033[0;36m'
        readonly NC='\033[0m'
    else
        readonly RED=''
        readonly GREEN=''
        readonly YELLOW=''
        readonly BLUE=''
        readonly MAGENTA=''
        readonly CYAN=''
        readonly NC=''
    fi
fi

# Spinner characters
readonly SPINNER_CHARS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
readonly SPINNER_DOTS=('⠁' '⠂' '⠄' '⡀' '⢀' '⠠' '⠐' '⠈')
readonly SPINNER_ARROW=('←' '↖' '↑' '↗' '→' '↘' '↓' '↙')
readonly SPINNER_BOX=('◰' '◳' '◲' '◱')
readonly SPINNER_CIRCLE=('◐' '◓' '◑' '◒')
readonly SPINNER_SIMPLE=('|' '/' '-' '\\')

# Global spinner state
_SPINNER_PID=""
_SPINNER_RUNNING=false

# Progress bar configuration
readonly PROGRESS_BAR_WIDTH=50
readonly PROGRESS_BAR_CHAR="█"
readonly PROGRESS_BAR_EMPTY="░"

# ============================================================================
# Spinner Functions
# ============================================================================

# Start a spinner with a message
# Usage: start_spinner "Processing..."
start_spinner() {
    local message="${1:-Processing}"
    local style="${2:-braille}"
    
    # Don't start if not a terminal
    if [[ ! -t 1 ]]; then
        echo "$message..."
        return 0
    fi
    
    # Stop existing spinner if running
    stop_spinner 2>/dev/null || true
    
    # Select spinner characters
    local -n chars="SPINNER_CHARS"
    case "$style" in
        dots) chars="SPINNER_DOTS" ;;
        arrow) chars="SPINNER_ARROW" ;;
        box) chars="SPINNER_BOX" ;;
        circle) chars="SPINNER_CIRCLE" ;;
        simple) chars="SPINNER_SIMPLE" ;;
    esac
    
    # Hide cursor
    printf '%b' "$TERM_HIDE_CURSOR"
    
    # Start spinner in background
    (
        local i=0
        while true; do
            printf '%b\r%b%s%b %s' "$TERM_CLEAR_LINE" "$CYAN" "${chars[$i]}" "$NC" "$message"
            i=$(( (i + 1) % ${#chars[@]} ))
            sleep 0.1
        done
    ) &
    
    _SPINNER_PID=$!
    _SPINNER_RUNNING=true
    
    # Ensure cleanup on script exit
    trap 'stop_spinner 2>/dev/null || true' EXIT INT TERM
}

# Stop the spinner and show final status
# Usage: stop_spinner [success|error|warning] ["Final message"]
stop_spinner() {
    local status="${1:-success}"
    local message="${2:-}"
    
    if [[ "$_SPINNER_RUNNING" == "true" && -n "$_SPINNER_PID" ]]; then
        kill "$_SPINNER_PID" 2>/dev/null || true
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=""
        _SPINNER_RUNNING=false
        
        # Clear line and show final status
        printf '%b\r%b' "$TERM_CLEAR_LINE" "$TERM_SHOW_CURSOR"
        
        if [[ -n "$message" ]]; then
            case "$status" in
                success) printf '%b✓%b %s\n' "$GREEN" "$NC" "$message" ;;
                error)   printf '%b✗%b %s\n' "$RED" "$NC" "$message" ;;
                warning) printf '%b⚠%b %s\n' "$YELLOW" "$NC" "$message" ;;
                info)    printf '%b●%b %s\n' "$BLUE" "$NC" "$message" ;;
                *)       printf '%s\n' "$message" ;;
            esac
        fi
    fi
}

# Update spinner message while running
# Usage: update_spinner "New message"
update_spinner() {
    local message="${1:-}"
    
    if [[ "$_SPINNER_RUNNING" == "true" ]]; then
        # The spinner process will continue with the current message
        # For dynamic updates, we'd need a more complex IPC mechanism
        # For now, just print a status update
        if [[ -n "$message" ]]; then
            printf '%b\r%b●%b %s\n' "$TERM_CLEAR_LINE" "$BLUE" "$NC" "$message"
        fi
    fi
}

# ============================================================================
# Progress Bar Functions
# ============================================================================

# Show a progress bar
# Usage: show_progress <current> <total> ["message"]
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-Progress}"
    
    # Don't show progress bar if not a terminal
    if [[ ! -t 1 ]]; then
        return 0
    fi
    
    # Calculate percentage
    local percent=0
    if [[ $total -gt 0 ]]; then
        percent=$(( current * 100 / total ))
    fi
    
    # Calculate filled and empty portions
    local filled=$(( current * PROGRESS_BAR_WIDTH / total ))
    if [[ $filled -gt $PROGRESS_BAR_WIDTH ]]; then
        filled=$PROGRESS_BAR_WIDTH
    fi
    local empty=$(( PROGRESS_BAR_WIDTH - filled ))
    
    # Build progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="$PROGRESS_BAR_CHAR"
    done
    for ((i=0; i<empty; i++)); do
        bar+="$PROGRESS_BAR_EMPTY"
    done
    
    # Print progress bar
    printf '\r%b[%s] %3d%%%b %s' \
        "$GREEN" "$bar" "$percent" "$NC" "$message"
    
    # Newline if complete
    if [[ $current -ge $total ]]; then
        echo
    fi
}

# Track download progress
# Usage: track_download <url> <output_file>
track_download() {
    local url="$1"
    local output="$2"
    local message="${3:-Downloading}"
    
    if command -v curl >/dev/null 2>&1; then
        if [[ -t 1 ]]; then
            # Terminal: show progress bar
            curl -# -L -o "$output" "$url" 2>&1 | \
            while IFS= read -r line; do
                if [[ "$line" =~ ([0-9]+\.[0-9]+)% ]]; then
                    local percent="${BASH_REMATCH[1]%.*}"
                    show_progress "$percent" 100 "$message"
                fi
            done
        else
            # Non-terminal: silent download
            curl -sS -L -o "$output" "$url"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [[ -t 1 ]]; then
            # Terminal: show progress bar
            wget --progress=dot:giga -O "$output" "$url" 2>&1 | \
            while IFS= read -r line; do
                if [[ "$line" =~ ([0-9]+)% ]]; then
                    local percent="${BASH_REMATCH[1]}"
                    show_progress "$percent" 100 "$message"
                fi
            done
        else
            # Non-terminal: quiet download
            wget -q -O "$output" "$url"
        fi
    else
        echo "ERROR: Neither curl nor wget available" >&2
        return 1
    fi
}

# Track git clone progress
# Usage: track_git_clone <url> <destination> ["message"]
track_git_clone() {
    local url="$1"
    local dest="$2"
    local message="${3:-Cloning repository}"
    
    if [[ -t 1 ]]; then
        start_spinner "$message"
        
        # Clone with progress to stderr
        if git clone --progress "$url" "$dest" 2>&1 | \
           grep -oP '(?<=Receiving objects: )[0-9]+(?=%)' | \
           while read -r percent; do
               show_progress "$percent" 100 "$message"
           done
        then
            stop_spinner success "Repository cloned successfully"
            return 0
        else
            stop_spinner error "Failed to clone repository"
            return 1
        fi
    else
        # Non-terminal: quiet clone
        git clone -q "$url" "$dest"
    fi
}

# ============================================================================
# Status Indicator Functions
# ============================================================================

# Show step indicator
# Usage: show_step <current_step> <total_steps> "Step description"
show_step() {
    local current=$1
    local total=$2
    local description="${3:-}"
    
    printf '\n%b[%d/%d]%b %b%s%b\n' \
        "$CYAN" "$current" "$total" "$NC" \
        "$TERM_BOLD" "$description" "$TERM_RESET"
}

# Show a section header
# Usage: show_section "Section Title"
show_section() {
    local title="$1"
    local width=70
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo
    printf '%b' "$BLUE"
    printf '═%.0s' $(seq 1 $width)
    echo
    printf '%*s' $padding ''
    printf ' %s ' "$title"
    printf '%*s' $padding ''
    echo
    printf '═%.0s' $(seq 1 $width)
    printf '%b\n' "$NC"
}

# Show a subsection header
# Usage: show_subsection "Subsection Title"
show_subsection() {
    local title="$1"
    printf '\n%b▸ %s%b\n' "$MAGENTA" "$title" "$NC"
}

# Show status message
# Usage: show_status "message"
show_status() {
    printf '%b→%b %s\n' "$BLUE" "$NC" "$*"
}

# Show success message
# Usage: show_success "message"
show_success() {
    printf '%b✓%b %s\n' "$GREEN" "$NC" "$*"
}

# Show error message
# Usage: show_error "message"
show_error() {
    printf '%b✗%b %s\n' "$RED" "$NC" "$*" >&2
}

# Show warning message
# Usage: show_warning "message"
show_warning() {
    printf '%b⚠%b %s\n' "$YELLOW" "$NC" "$*" >&2
}

# Show info message
# Usage: show_info "message"
show_info() {
    printf '%b●%b %s\n' "$CYAN" "$NC" "$*"
}

# ============================================================================
# Multi-line Progress Tracking
# ============================================================================

# Initialize multi-step progress tracker
# Usage: init_progress_tracker <total_steps>
init_progress_tracker() {
    local total=$1
    export _PROGRESS_TOTAL=$total
    export _PROGRESS_CURRENT=0
    
    if [[ -t 1 ]]; then
        printf '%b' "$TERM_HIDE_CURSOR"
    fi
}

# Update progress tracker
# Usage: update_progress_tracker "Step description"
update_progress_tracker() {
    local description="$1"
    
    _PROGRESS_CURRENT=$(( _PROGRESS_CURRENT + 1 ))
    
    if [[ -t 1 ]]; then
        show_progress "$_PROGRESS_CURRENT" "$_PROGRESS_TOTAL" "$description"
    else
        echo "[$_PROGRESS_CURRENT/$_PROGRESS_TOTAL] $description"
    fi
}

# Finish progress tracker
# Usage: finish_progress_tracker
finish_progress_tracker() {
    if [[ -t 1 ]]; then
        printf '%b' "$TERM_SHOW_CURSOR"
        echo
    fi
    unset _PROGRESS_TOTAL
    unset _PROGRESS_CURRENT
}

# ============================================================================
# Error Handling and Reporting
# ============================================================================

# Report error with context
# Usage: report_error "Error message" ["Suggestion"]
report_error() {
    local message="$1"
    local suggestion="${2:-}"
    
    echo >&2
    printf '%b╔══════════════════════════════════════════════════════════════╗%b\n' "$RED" "$NC" >&2
    printf '%b║                         ERROR                                ║%b\n' "$RED" "$NC" >&2
    printf '%b╠══════════════════════════════════════════════════════════════╣%b\n' "$RED" "$NC" >&2
    printf '%b║%b %-60s %b║%b\n' "$RED" "$NC" "$message" "$RED" "$NC" >&2
    
    if [[ -n "$suggestion" ]]; then
        printf '%b║%b                                                             %b║%b\n' "$RED" "$NC" "$RED" "$NC" >&2
        printf '%b║%b %bSuggestion:%b %-48s %b║%b\n' "$RED" "$NC" "$YELLOW" "$NC" "$suggestion" "$RED" "$NC" >&2
    fi
    
    printf '%b╚══════════════════════════════════════════════════════════════╝%b\n' "$RED" "$NC" >&2
    echo >&2
}

# Show command execution with spinner
# Usage: run_with_spinner "Description" command [args...]
run_with_spinner() {
    local description="$1"
    shift
    local command=("$@")
    
    if [[ -t 1 ]]; then
        start_spinner "$description"
        
        local output
        local exit_code
        output=$(mktemp)
        
        if "${command[@]}" &>"$output"; then
            exit_code=0
            stop_spinner success "$description - Done"
        else
            exit_code=$?
            stop_spinner error "$description - Failed"
            
            # Show error output
            if [[ -s "$output" ]]; then
                echo "Error output:" >&2
                tail -n 20 "$output" >&2
            fi
        fi
        
        rm -f "$output"
        return $exit_code
    else
        echo "$description..."
        "${command[@]}"
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get terminal width
get_terminal_width() {
    if [[ -t 1 ]]; then
        tput cols 2>/dev/null || echo 80
    else
        echo 80
    fi
}

# Center text
# Usage: center_text "text"
center_text() {
    local text="$1"
    local width=$(get_terminal_width)
    local padding=$(( (width - ${#text}) / 2 ))
    
    printf '%*s%s\n' $padding '' "$text"
}

# Print horizontal line
# Usage: print_line [character] [width]
print_line() {
    local char="${1:-═}"
    local width="${2:-$(get_terminal_width)}"
    
    printf '%b' "$BLUE"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf '%b\n' "$NC"
}

# Confirm action with prompt
# Usage: confirm "Are you sure?" && do_something
confirm() {
    local prompt="${1:-Are you sure?}"
    local response
    
    printf '%b?%b %s (y/N): ' "$YELLOW" "$NC" "$prompt"
    read -r response
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# ============================================================================
# Export Functions
# ============================================================================

export -f start_spinner stop_spinner update_spinner
export -f show_progress track_download track_git_clone
export -f show_step show_section show_subsection
export -f show_status show_success show_error show_warning show_info
export -f init_progress_tracker update_progress_tracker finish_progress_tracker
export -f report_error run_with_spinner
export -f get_terminal_width center_text print_line confirm
