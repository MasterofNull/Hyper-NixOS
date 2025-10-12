# First Boot Experience Improvements

## Summary of Changes

This document outlines the improvements made to fix the first boot experience and create a better user workflow.

## Problems Fixed

### 1. ❌ GNOME Loading Instead of Console Menu
**Root Cause**: `configuration/hardware-input.nix` unconditionally enabled `services.xserver.libinput`, which forced X server to start, which then loaded GNOME.

**Fix**: Wrapped all X server-related configurations with `lib.mkIf config.services.xserver.enable` to only enable input device support when GUI mode is explicitly requested.

**Files Changed**:
- `configuration/hardware-input.nix` - Conditional X server configuration
- `configuration/configuration.nix` - Updated comments to clarify GUI is disabled by default

### 2. ❌ Old First-Boot Wizard Exited Without Returning to Menu
**Previous Behavior**: Wizard showed completion message and exited, leaving user with no interface.

**Fix**: Replaced full wizard with lightweight welcome screen + comprehensive "Install VMs" workflow.

### 3. ❌ Confusing "First Boot vs Subsequent Boot" Behavior
**Previous Behavior**: System behaved differently on first boot vs subsequent boots.

**Fix**: Consistent behavior - always show main menu, with optional one-time welcome splash.

## New Architecture

### Boot Flow
```
System Boot
    ↓
Auto-login to console
    ↓
[First Boot Only] Welcome Screen (3 seconds, skippable)
    ↓
Main Hypervisor Menu
    ↓
User selects: "More Options" → "Install VMs"
    ↓
Comprehensive Installation Workflow
```

### Components

#### 1. First-Boot Welcome Screen (`scripts/first_boot_welcome.sh`)
- **Runs**: Only on first boot (marker file prevents reruns)
- **Duration**: 3 seconds, auto-dismisses
- **Purpose**: Orientation and guidance
- **Behavior**: 
  - Non-intrusive - can be skipped with ESC
  - Provides clear next steps
  - Points to "Install VMs" workflow
  - Never runs again after first display

#### 2. Install VMs Workflow (`scripts/install_vm_workflow.sh`)
- **Access**: Main Menu → More Options → Install VMs
- **Features**:
  - ✅ ISO download/selection (14+ verified distributions)
  - ✅ Network bridge setup (automatic detection)
  - ✅ VM creation wizard (full configuration)
  - ✅ Automatic VM launch after creation
  - ✅ Return to menu at any time (ESC/Cancel)
  - ✅ Comprehensive validation and hints
  - ✅ Progress saving (resume if interrupted)
  - ✅ Detailed logging
  
**Workflow Steps**:
1. Welcome & system status
2. ISO selection/download with presets
3. Network bridge configuration (optional)
4. VM profile creation with validation
5. Automatic VM launch
6. Return to main menu

## User Experience Improvements

### Consistency
- ✅ Same behavior every boot (no special first-boot mode)
- ✅ Console menu always loads (unless GUI explicitly enabled)
- ✅ Clear navigation with return-to-menu options

### Guidance
- ✅ Welcome screen provides orientation
- ✅ "Install VMs" clearly marked as RECOMMENDED
- ✅ Tooltips and hints throughout workflow
- ✅ Resource detection with smart defaults
- ✅ Validation before proceeding

### Flexibility
- ✅ Skip any step in workflow
- ✅ Return to menu anytime (ESC/Cancel)
- ✅ Can run workflow multiple times
- ✅ Individual tools still accessible separately

### Feedback
- ✅ Clear progress indicators
- ✅ Success/failure messages
- ✅ Comprehensive logging
- ✅ Helpful error messages

## Configuration Changes

### Defaults
```nix
enableMenuAtBoot = true;           # Console menu at boot (default)
enableGuiAtBoot = false;           # GUI disabled by default
enableWelcomeAtBoot = true;        # One-time welcome screen (default)
enableWizardAtBoot = false;        # Old wizard disabled
```

### To Enable GUI Mode
Create `/var/lib/hypervisor/configuration/gui-local.nix`:
```nix
{ config, lib, ... }:
{
  hypervisor.gui.enableAtBoot = true;
  hypervisor.menu.enableAtBoot = false;
}
```

### To Disable Welcome Screen
```nix
{ config, lib, ... }:
{
  hypervisor.firstBootWelcome.enableAtBoot = false;
}
```

## Menu Integration

### Main Menu
- Displays VM list
- Quick actions: Start VMs, More Options, Update, Exit

### More Options Menu (Updated)
```
0. 🚀 Install VMs - Complete guided workflow (RECOMMENDED)  ← NEW
1. Create VM (wizard only)
2. ISO manager (download/validate/attach)
3. Cloud image manager (cloud-init images)
4. Hardware detect & VFIO suggestions
... (other advanced options)
```

## Documentation Updates

### README.md
- ✅ Updated first boot experience description
- ✅ Removed outdated wizard references
- ✅ Added "Install VMs" workflow documentation
- ✅ Added troubleshooting for GNOME loading issue
- ✅ Clear instructions for enabling/disabling GUI mode

### Quick Reference Commands
```bash
# Re-show welcome screen
sudo rm /var/lib/hypervisor/.first_boot_welcome_shown

# Run Install VMs workflow
sudo bash /etc/hypervisor/scripts/install_vm_workflow.sh

# View logs
cat /var/lib/hypervisor/logs/first_boot.log      # Welcome screen
cat /var/lib/hypervisor/logs/install_vm.log      # Workflow

# Disable GUI and use console menu
sudo rm /var/lib/hypervisor/configuration/gui-local.nix
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

## Testing Recommendations

### First Boot Test
1. Fresh install/reboot
2. Should see: Welcome screen (3 seconds) → Main menu
3. Verify: No GNOME login screen
4. Verify: Welcome screen doesn't show on subsequent boots

### Install VMs Workflow Test
1. Select: More Options → Install VMs
2. Should see: Welcome with system info
3. Test: ISO download (select from 14 presets)
4. Test: Network bridge creation (optional)
5. Test: VM creation wizard
6. Test: ESC/Cancel returns to menu at any step
7. Verify: VM launches after creation
8. Verify: Returns to menu after completion

### GUI Mode Test
1. Create gui-local.nix with enableAtBoot = true
2. Rebuild system
3. Reboot
4. Verify: GNOME loads instead of console menu
5. Remove gui-local.nix and rebuild
6. Verify: Console menu returns

## Benefits

### For New Users
- Clear guidance from first boot
- Recommended path highlighted
- Can't miss the main workflow
- Less overwhelming (progressive disclosure)

### For Experienced Users
- Fast - skip welcome screen instantly
- Flexible - direct access to individual tools
- Consistent - same interface every time
- Powerful - all advanced options still available

### For Support
- Fewer "what do I do?" questions
- Clear recommended path
- Better error messages
- Comprehensive logging

## Rollback Instructions

If needed to restore old wizard:
```bash
# Edit configuration.nix
enableWelcomeAtBoot = false;
enableWizardAtBoot = true;

# Rebuild
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

## Future Enhancements (Optional)

Potential improvements for consideration:
1. **Interactive help system** - Context-sensitive F1 help
2. **Video tutorials** - Short clips for common tasks
3. **Progress tracking** - Show completed setup steps
4. **Quick start templates** - Pre-configured VM profiles for common use cases
5. **Automated testing** - Verify system readiness before VM creation

---

**Version**: 2.0  
**Date**: 2025-10-12  
**Status**: ✅ Implemented and Ready for Testing
