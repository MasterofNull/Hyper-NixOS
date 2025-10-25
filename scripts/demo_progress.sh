#!/usr/bin/env bash
#
# Progress Library Demo
# Demonstrates all features of the progress.sh library
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the progress library
if [[ -f "$SCRIPT_DIR/lib/progress.sh" ]]; then
    source "$SCRIPT_DIR/lib/progress.sh"
else
    echo "ERROR: Cannot find progress.sh library"
    exit 1
fi

# Demo functions
demo_section_headers() {
    show_section "Section Headers Demo"
    echo "This shows how to create section headers"
    
    show_subsection "Subsection Example"
    echo "Subsections provide hierarchical organization"
}

demo_status_messages() {
    show_section "Status Messages Demo"
    
    show_status "This is a status message"
    show_success "This is a success message"
    show_error "This is an error message"
    show_warning "This is a warning message"
    show_info "This is an info message"
}

demo_spinners() {
    show_section "Spinner Animations Demo"
    
    echo "Testing different spinner styles:"
    echo
    
    for style in braille dots arrow box circle simple; do
        show_subsection "Spinner style: $style"
        start_spinner "Processing with $style spinner" "$style"
        sleep 2
        stop_spinner success "Completed with $style spinner"
        echo
    done
}

demo_progress_bars() {
    show_section "Progress Bar Demo"
    
    echo "Simulating a task with 20 steps:"
    echo
    
    for i in $(seq 1 20); do
        show_progress "$i" 20 "Processing step $i/20"
        sleep 0.2
    done
    
    echo
    echo "Progress bar complete!"
}

demo_multi_step() {
    show_section "Multi-Step Progress Tracker Demo"
    
    init_progress_tracker 5
    
    sleep 0.5
    update_progress_tracker "Initializing system"
    sleep 1
    
    update_progress_tracker "Loading configuration"
    sleep 1
    
    update_progress_tracker "Validating dependencies"
    sleep 1
    
    update_progress_tracker "Applying changes"
    sleep 1
    
    update_progress_tracker "Finalizing"
    sleep 0.5
    
    finish_progress_tracker
    
    show_success "All steps completed!"
}

demo_step_indicators() {
    show_section "Step Indicator Demo"
    
    local total_steps=5
    
    for step in $(seq 1 $total_steps); do
        show_step "$step" "$total_steps" "Executing step $step"
        sleep 1
    done
    
    show_success "All steps executed!"
}

demo_error_reporting() {
    show_section "Error Reporting Demo"
    
    echo "Example of detailed error reporting:"
    echo
    
    # Create a fake error log
    local error_log=$(mktemp)
    cat > "$error_log" <<EOF
Error: Connection timeout
Failed to connect to remote server
Network unreachable (errno: 101)
Retry attempt 1/3 failed
Retry attempt 2/3 failed
Retry attempt 3/3 failed
EOF
    
    report_error "Failed to connect to remote server" \
                 "Check network connection and try again" \
                 "$error_log"
    
    rm -f "$error_log"
}

demo_run_with_spinner() {
    show_section "Run with Spinner Demo"
    
    echo "Running commands with automatic spinner:"
    echo
    
    run_with_spinner "Sleeping for 2 seconds" sleep 2
    
    echo
    echo "Simulating a failing command:"
    run_with_spinner "This will fail" false || echo "  (Failure handled gracefully)"
}

demo_utilities() {
    show_section "Utility Functions Demo"
    
    echo "Terminal width: $(get_terminal_width) columns"
    echo
    
    echo "Centered text example:"
    center_text "This text is centered"
    echo
    
    echo "Horizontal lines:"
    print_line "─" 50
    print_line "═" 50
    print_line "*" 50
}

demo_confirmation() {
    show_section "Confirmation Prompt Demo"
    
    if [[ -t 0 ]]; then
        if confirm "Would you like to see an example confirmation?"; then
            show_success "User confirmed!"
        else
            show_info "User declined"
        fi
    else
        show_info "Skipping interactive confirmation (not a TTY)"
    fi
}

# Main demo
main() {
    clear
    
    echo
    print_line "═" 70
    center_text "Hyper-NixOS Progress Library Demo" 70
    center_text "Showcasing visual feedback features" 70
    print_line "═" 70
    echo
    
    show_info "This demo showcases all features of the progress.sh library"
    show_info "Each section demonstrates different progress indicators"
    echo
    
    if [[ -t 0 ]]; then
        if ! confirm "Ready to start the demo?"; then
            show_info "Demo cancelled"
            exit 0
        fi
    fi
    
    echo
    
    # Run all demos
    demo_section_headers
    echo; sleep 1
    
    demo_status_messages
    echo; sleep 1
    
    demo_step_indicators
    echo; sleep 1
    
    demo_progress_bars
    echo; sleep 1
    
    demo_multi_step
    echo; sleep 1
    
    demo_spinners
    echo; sleep 1
    
    demo_run_with_spinner
    echo; sleep 1
    
    demo_error_reporting
    echo; sleep 1
    
    demo_utilities
    echo; sleep 1
    
    demo_confirmation
    echo
    
    # Final message
    show_section "Demo Complete"
    show_success "All progress library features demonstrated!"
    echo
    show_info "To use this library in your scripts:"
    echo '  source "$(dirname "$0")/lib/progress.sh"'
    echo
    show_info "For more information, see:"
    echo "  docs/dev/INSTALLER_PROGRESS_ENHANCEMENT_2025-10-15.md"
    echo
}

# Run the demo
main "$@"
