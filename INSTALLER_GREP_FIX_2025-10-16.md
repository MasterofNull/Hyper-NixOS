# Quick Installer Fix - Grep Regex Error (2025-10-16)

## ✅ Issue Fixed

**Problem**: Remote installer failed with error:
```
grep: lookbehind assertion is not fixed length
✗ Failed to clone repository from https://github.com/MasterofNull/Hyper-NixOS.git
```

**Cause**: Invalid regex pattern with variable-length lookbehind (`\s+` inside `(?<=...)`)

**Solution**: Replaced lookbehind with `\K` pattern (keep/drop mechanism)

## Changes Made

### Fixed Regex Pattern

**Before (broken)**:
```bash
grep --line-buffered -oP '(?<=Receiving objects:\s+)\d+(?=%)'
```

**After (working)**:
```bash
grep --line-buffered -oP 'Receiving objects:\s+\K\d+(?=%)'
```

### Files Modified

- `install.sh` - Lines 637, 681, 713 (all three git clone methods)
  - HTTPS clone
  - SSH clone  
  - Token authentication clone

### Additional Improvements

- Changed `tail -n 10 "$clone_output"` to `cat "$clone_output"` for better error visibility

## Test Results

✅ Pattern validated with test cases:
```bash
echo "Receiving objects:   45%" | grep -oP 'Receiving objects:\s+\K\d+(?=%)'
# Output: 45 ✓

echo -e "Receiving objects:  23%\nReceiving objects: 100%" | grep -oP 'Receiving objects:\s+\K\d+(?=%)'  
# Output: 23
#         100 ✓
```

## Ready to Use

The installer is now fixed and ready to use:

```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

**What you'll see**:
- ✅ Proper progress tracking during git clone
- ✅ No "lookbehind assertion" errors
- ✅ Complete error details if something fails

## Documentation

Full technical details: [`docs/dev/INSTALLER_GREP_REGEX_FIX_2025-10-16.md`](docs/dev/INSTALLER_GREP_REGEX_FIX_2025-10-16.md)

## Quick Reference: `\K` Pattern

The `\K` escape in PCRE tells grep to "drop everything matched before this point":

```bash
# Extract numbers after "Value: "
echo "Value: 123" | grep -oP 'Value:\s+\K\d+'
# Output: 123

# Works with variable-length prefixes (unlike lookbehind)
echo "Value:    456" | grep -oP 'Value:\s+\K\d+'  
# Output: 456
```

---

**Status**: ✅ Fixed and tested  
**Date**: 2025-10-16  
**Impact**: Critical - Unblocks remote installation
