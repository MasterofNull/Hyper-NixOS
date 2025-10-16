# Installer Tarball Default - Quick Summary

## What Changed

**Tarball download is now the #1 option and default method** for Hyper-NixOS installation.

## New Menu Order

```
1) Download Tarball     [DEFAULT] ← NEW: Moved from #4 to #1
2) Git Clone (HTTPS)              ← Was #1, now #2
3) Git Clone (SSH)                ← Was #2, now #3
4) Git Clone (Token)              ← Was #3, now #4
```

## Why This Change

1. **Fastest**: Tarball download is quicker than git clone
2. **No Dependencies**: Doesn't require git installation
3. **Most Reliable**: Fewer potential failure points
4. **Better UX**: Default should be the recommended option

## How to Use

### Default (Tarball)
Just press Enter when prompted, or use piped installation:
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

### Specify Method via Environment Variable
```bash
# Tarball (default)
HYPER_INSTALL_METHOD=tarball curl ... | sudo -E bash

# Git HTTPS
HYPER_INSTALL_METHOD=https curl ... | sudo -E bash

# Git SSH
HYPER_INSTALL_METHOD=ssh curl ... | sudo -E bash

# Git Token
HYPER_INSTALL_METHOD=token curl ... | sudo -E bash
```

### Manual Selection
When prompted, enter:
- `1` for Tarball (recommended, fastest)
- `2` for Git HTTPS (public access)
- `3` for Git SSH (requires GitHub key)
- `4` for Git Token (for private repos)

## Bug Fix Included

Also fixed input reading issue where user selections weren't being captured correctly in piped mode.

**Problem**: Info messages were mixing with user input  
**Solution**: All output in prompt function now goes to stderr  
**Result**: User input is captured cleanly

## Testing

✅ Tarball at position #1  
✅ Default is #1 (tarball)  
✅ Input reading works in piped mode  
✅ All case statements updated  
✅ Environment variables work  
✅ Documentation updated

---

**Date**: 2025-10-16  
**Status**: Complete  
**See**: INSTALLER_TARBALL_DEFAULT_FIX_2025-10-16.md for detailed changes
