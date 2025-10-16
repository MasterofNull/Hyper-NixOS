# Remote Installer Fix - October 16, 2025

## Issue Summary

**User Report:** "Invalid download method" error when using one-command remote installer

**Impact:** Critical - All remote installations via `curl | bash` were broken

## What Was Broken

When users ran:
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

They encountered:
```
==> Starting remote installation...
⚠ Running in non-interactive mode, using default: Tarball Download (fastest)
✗ Invalid download method
```

## Root Cause

The `prompt_download_method()` function returned a value using command substitution:
```bash
download_method=$(prompt_download_method)
```

But it was outputting informational messages to stdout instead of stderr:
```bash
print_info "For interactive mode..."  # Goes to stdout
echo "4"                               # Also goes to stdout
```

This caused the variable to capture BOTH outputs:
- Expected: `download_method="4"`
- Actual: `download_method="ℹ For interactive mode... 4"`

The validation failed because "ℹ For interactive mode... 4" is not a valid choice (1-4).

## The Fix

Changed all informational output in value-returning functions to explicitly write to stderr:

**Before:**
```bash
print_info "For interactive mode with more options, download and run: git clone && cd Hyper-NixOS && sudo ./install.sh"
```

**After:**
```bash
echo -e "${CYAN}ℹ${NC} For interactive mode with more options, download and run: git clone && cd Hyper-NixOS && sudo ./install.sh" >&2
```

## Files Changed

- ✅ `install.sh` - Fixed stdout/stderr separation in `prompt_download_method()`
- ✅ `docs/dev/INSTALLER_STDOUT_FIX_2025-10-16.md` - Technical documentation
- ✅ `docs/dev/PROJECT_DEVELOPMENT_HISTORY.md` - Updated with fix details
- ✅ `docs/COMMON_ISSUES_AND_SOLUTIONS.md` - Added troubleshooting entry
- ✅ `INSTALLER_FIX_SUMMARY_2025-10-16.md` - This summary

## Testing

✅ **Test 1:** Function returns clean value
```bash
result=$(prompt_download_method 2>/dev/null)
# Result: "4" ✓
```

✅ **Test 2:** Informational messages still display
```bash
result=$(prompt_download_method 2>&1 >/dev/null)
# Shows: "⚠ Running in non-interactive mode..." ✓
```

## Status

✅ **FIXED** - Remote installation now works correctly

Users can now successfully use:
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

## Key Lesson

**When bash functions return values via command substitution `$(function)`, ALL output except the return value MUST go to stderr.**

Pattern to follow:
```bash
# ✅ CORRECT
my_function() {
    echo "Info message" >&2  # Informational output to stderr
    echo "return_value"      # Only return value to stdout
}

# ❌ WRONG
my_function() {
    echo "Info message"      # Goes to stdout - contaminates return!
    echo "return_value"
}
```

## Related Issues

This is the second critical installer bug fix:
1. **2025-10-15:** Infinite loop bug (BASH_SOURCE handling)
2. **2025-10-16:** Invalid download method (stdout/stderr separation) ← This fix

Both are now resolved.
