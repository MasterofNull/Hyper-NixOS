# VM Boot Selector - VM-First Boot Flow

## Overview

The boot flow now prioritizes VMs - making it faster to start your virtual machines.

## Boot Flow

### When VMs Exist

```
Boot → VM Boot Selector
       ├─ VM 1
       ├─ VM 2  
       ├─ VM 3
       └─ More Options → Main Menu
```

**Features:**
- Shows all your VMs
- Auto-selects last used VM
- Timer countdown (default 8 seconds)
- Starts VM immediately on selection
- "More Options" goes to main menu

### When No VMs Exist

```
Boot → Main Menu
```

Goes directly to main menu for setup.

---

## VM Boot Selector

**Location:** `/etc/hypervisor/scripts/vm_boot_selector.sh`

### Features

#### Auto-Selection with Timer
- Remembers your last selected VM
- Auto-selects after 8 seconds (configurable)
- Press any key to interrupt timer
- Select different VM or More Options

#### Last VM Memory
- Stores last selected VM in `/var/lib/hypervisor/last_vm`
- Automatically highlights on next boot
- Makes repeat starts instant

#### Configurable Timeout
Edit `/etc/hypervisor/config.json`:
```json
{
  "features": {
    "boot_selector_timeout_sec": 8
  }
}
```

---

## Main Menu Integration

### From VM Selector
Select "More Options" → Goes to Main Menu

### From Main Menu  
Select "← Back to VM Boot Selector" → Goes to VM Selector

### Navigation Flow

```
VM Boot Selector ←──────────────┐
    │                            │
    ├─ Start VM                  │
    │                            │
    └─ More Options              │
           ↓                     │
       Main Menu                 │
           ├─ VMs                │
           ├─ Setup/Tools        │
           └─ ← Back to VM ──────┘
              Selector
```

---

## Configuration

### Enable/Disable
The VM boot selector runs automatically when:
- Console menu is enabled at boot
- VMs exist in `/var/lib/hypervisor/vm_profiles/`

### Timeout Configuration

**Default:** 8 seconds

**Change timeout:**
Edit `/etc/hypervisor/config.json`:
```json
{
  "features": {
    "boot_selector_timeout_sec": 5
  }
}
```

**Disable auto-select:**
Set timeout to 0 or very high number:
```json
{
  "features": {
    "boot_selector_timeout_sec": 0
  }
}
```

---

## GUI Options Removed

### What Changed
Removed "Force GNOME on" option from `toggle_gui.sh`

**Reason:** Not needed - users who want GUI installed it during NixOS setup

**Remaining options:**
- `off` - Force console menu (override base system)
- `auto` - Use base system default  
- `status` - Show current configuration

### Commands

```bash
# Force console menu (even if base has GNOME)
sudo /etc/hypervisor/scripts/toggle_gui.sh off

# Use base system default (respect your install)
sudo /etc/hypervisor/scripts/toggle_gui.sh auto

# Check status
sudo /etc/hypervisor/scripts/toggle_gui.sh status
```

---

## Example Boot Flows

### Scenario 1: Regular User with VMs

```
1. Boot system
2. VM Boot Selector appears
3. Shows: 
   - web-server
   - database-vm
   - dev-environment
   - More Options
4. Last used: dev-environment (highlighted)
5. Timer: "Starting in 8... 7... 6..."
6. Press Enter or wait → Starts dev-environment
```

### Scenario 2: Exploring Options

```
1. Boot system
2. VM Boot Selector appears
3. Navigate to "More Options"
4. Press Enter
5. Main Menu appears
6. Select "Install VMs" or other tools
7. When done, select "← Back to VM Boot Selector"
8. Returns to VM list
```

### Scenario 3: First Time Setup

```
1. Boot system
2. No VMs exist → Main Menu loads
3. Select "More Options"
4. Select "Install VMs"
5. Complete setup wizard
6. VM created
7. Next boot → VM Boot Selector appears
```

---

## Files

### New Scripts
- `scripts/vm_boot_selector.sh` - VM boot selector with timer

### Modified Scripts
- `scripts/menu.sh` - Added "← Back to VM Boot Selector" option
- `scripts/toggle_gui.sh` - Removed "on" option (force GNOME)
- `scripts/first_boot_welcome.sh` - Updated welcome message

### Configuration
- `configuration/configuration.nix` - Updated boot flow comments
- `/var/lib/hypervisor/last_vm` - Stores last selected VM

---

## Benefits

✅ **Faster VM starts** - Auto-select with timer
✅ **Less navigation** - VMs shown first
✅ **Smart defaults** - Remembers your choice
✅ **Easy access to tools** - "More Options" always available
✅ **Bidirectional** - Can go back to VM selector from menu
✅ **Respects base system** - No forced GUI options

---

## Summary

**Old Flow:**
```
Boot → Main Menu → Select VM → Start
```

**New Flow:**
```
Boot → VM Selector (auto-select, timer) → VM Starts
        └─ More Options → Main Menu
                           └─ Back to VM Selector
```

**Result:** Faster, smarter, VM-first boot experience!
