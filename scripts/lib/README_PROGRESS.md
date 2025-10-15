# Progress Library

Visual feedback and progress indicators for Hyper-NixOS installer scripts.

## Quick Start

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/lib/progress.sh"

start_spinner "Processing..."
perform_long_operation
stop_spinner success "Complete!"
```

## Features

### 🔄 Spinners
Animated spinners for indeterminate operations:
- Multiple styles: braille, dots, arrow, box, circle, simple
- Auto-hides on non-TTY
- Proper cleanup on exit

### 📊 Progress Bars
Visual progress bars for trackable operations:
- Percentage display
- Customizable width
- Download tracking
- Git clone progress

### ✓ Status Messages
Colored status indicators:
- `show_success()` - Green checkmark
- `show_error()` - Red X
- `show_warning()` - Yellow warning
- `show_info()` - Cyan info
- `show_status()` - Blue arrow

### 📋 Step Tracking
Multi-step operation tracking:
- Step counter [n/total]
- Progress percentage
- Automatic completion

### 🎨 Formatting
Professional output formatting:
- Section headers
- Horizontal lines
- Centered text
- Terminal width detection

### ❌ Error Reporting
Enhanced error messages:
- Formatted error boxes
- Suggestions
- Error log excerpts
- Context information

## Function Reference

### Spinners

```bash
# Start animated spinner
start_spinner "Loading data" ["style"]
# Styles: braille (default), dots, arrow, box, circle, simple

# Stop spinner with status
stop_spinner [success|error|warning|info] ["message"]

# Update spinner message
update_spinner "New message"
```

### Progress Bars

```bash
# Show progress bar
show_progress <current> <total> ["message"]

# Track download with progress
track_download <url> <output_file> ["message"]

# Track git clone with progress
track_git_clone <url> <destination> ["message"]
```

### Multi-Step Progress

```bash
# Initialize tracker
init_progress_tracker <total_steps>

# Update progress
update_progress_tracker "Step description"

# Finish tracking
finish_progress_tracker
```

### Status Messages

```bash
show_status "Processing..."
show_success "Operation successful"
show_error "Operation failed"
show_warning "Potential issue detected"
show_info "Additional information"
```

### Section Formatting

```bash
# Show section header
show_section "Section Title"

# Show subsection
show_subsection "Subsection Title"

# Show step indicator
show_step <current> <total> "Step description"
```

### Error Reporting

```bash
# Report error with context
report_error "Error message" ["Suggestion"] ["error_log_file"]

# Run command with spinner
run_with_spinner "Description" command [args...]
```

### Utilities

```bash
# Get terminal width
width=$(get_terminal_width)

# Center text
center_text "Text to center" [width]

# Print horizontal line
print_line ["character"] [width]

# Confirmation prompt
if confirm "Proceed?"; then
    # User confirmed
fi
```

## Examples

### Basic Spinner

```bash
start_spinner "Installing packages"
apt-get install -y package1 package2 package3
stop_spinner success "Packages installed"
```

### Progress Bar

```bash
total=100
for ((i=1; i<=total; i++)); do
    show_progress $i $total "Processing items"
    process_item $i
done
```

### Multi-Step Operation

```bash
init_progress_tracker 3

update_progress_tracker "Downloading files"
download_files

update_progress_tracker "Extracting archives"
extract_archives

update_progress_tracker "Installing components"
install_components

finish_progress_tracker
```

### Error Handling

```bash
if ! critical_operation; then
    report_error "Critical operation failed" \
                 "Check system logs for details" \
                 "/var/log/error.log"
    exit 1
fi
```

### Download Tracking

```bash
track_download \
    "https://example.com/large-file.tar.gz" \
    "/tmp/large-file.tar.gz" \
    "Downloading package"
```

### Styled Output

```bash
show_section "Installation Process"

show_subsection "System Preparation"
show_status "Checking requirements..."
check_requirements
show_success "Requirements satisfied"

show_subsection "Package Installation"
show_step 1 3 "Installing core packages"
install_core_packages

show_step 2 3 "Installing optional packages"
install_optional_packages

show_step 3 3 "Configuring system"
configure_system
```

## Demo

Run the demo script to see all features:

```bash
./scripts/demo_progress.sh
```

## Terminal Compatibility

The library automatically detects terminal capabilities:
- **TTY**: Full visual features
- **Non-TTY**: Plain text fallback
- **Color**: ANSI color support detection
- **Unicode**: Graceful fallback to ASCII

## Best Practices

1. **Always source at script start:**
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/lib/progress.sh"
   ```

2. **Stop spinners before other output:**
   ```bash
   start_spinner "Working..."
   do_work
   stop_spinner success "Done"
   # Now safe to print
   ```

3. **Use appropriate status levels:**
   - `success` - Completed successfully
   - `error` - Failed
   - `warning` - Completed with warnings
   - `info` - Informational

4. **Clean up on exit:**
   ```bash
   trap 'stop_spinner 2>/dev/null || true' EXIT INT TERM
   ```

5. **Check for TTY when needed:**
   Library handles this automatically, but for manual checks:
   ```bash
   if [[ -t 1 ]]; then
       # Terminal features
   else
       # Plain text fallback
   fi
   ```

## Dependencies

- **Bash**: 4.0+ recommended
- **Terminal**: ANSI-compatible
- **Commands**: `tput` (optional, for width detection)

No external dependencies required!

## Color Reference

Available color variables:
- `$RED` - Error messages
- `$GREEN` - Success messages
- `$YELLOW` - Warnings
- `$BLUE` - Status and headers
- `$CYAN` - Info messages
- `$MAGENTA` - Subsections
- `$NC` - Reset to normal

## Documentation

For detailed documentation, see:
- `docs/dev/INSTALLER_PROGRESS_ENHANCEMENT_2025-10-15.md`

## License

Copyright (C) 2024-2025 MasterofNull
Part of Hyper-NixOS
