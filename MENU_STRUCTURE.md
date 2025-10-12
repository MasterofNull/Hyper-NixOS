# Menu Structure - Hierarchical Organization

## Overview

Menus are now organized hierarchically to avoid overly large option lists on any single page. Each menu has clear navigation back up the hierarchy.

---

## Menu Hierarchy

```
VM Boot Selector (if VMs exist)
├─ VM 1
├─ VM 2
├─ VM 3
└─ More Options → Main Menu

Main Menu
├─ VM List (actual VMs)
├─ VM Operations → (submenu)
├─ System Configuration → (submenu) [sudo]
├─ ← Back to VM Boot Selector
└─ Exit

VM Operations (submenu)
├─ Install VMs workflow
├─ Create VM wizard
├─ Edit VM profile
├─ Delete VM
├─ Define/Start from JSON
├─ Validate profile
│
├─ ISO manager
├─ Cloud image manager
│
├─ Snapshots & backups
├─ Clone/Template manager
├─ Resource optimizer
│
├─ Metrics & Health
├─ Health checks
├─ View logs
│
├─ Hardware detect
└─ ← Back to Main Menu

System Configuration (submenu)
├─ Network foundation setup [sudo]
├─ Bridge helper [sudo]
├─ Network helper [sudo]
├─ Zone manager [sudo]
│
├─ VFIO configure [sudo]
├─ Per-VM firewall [sudo]
│
├─ Update Hypervisor [sudo]
├─ Security audit [sudo]
├─ Preflight check [sudo]
│
├─ Docs & Help
├─ Interactive tutorial
├─ Help assistant
└─ ← Back to Main Menu
```

---

## Navigation Flow

### Boot to VM

```
Boot → VM Selector
       ├─ Select VM → VM Starts
       └─ More Options → Main Menu
```

### Explore VM Operations

```
Main Menu
   └─ VM Operations →
         ├─ Create VM → VM Operations
         ├─ ISO manager → VM Operations
         └─ ← Back → Main Menu
```

### Configure System

```
Main Menu
   └─ System Configuration →
         ├─ Network setup [sudo] → System Configuration
         ├─ VFIO configure [sudo] → System Configuration  
         └─ ← Back → Main Menu
```

### Return to VM Selector

```
Main Menu
   └─ ← Back to VM Boot Selector → VM Selector
```

---

## Main Menu

**Displays:**
- List of VMs (for quick start)
- VM Operations → (submenu)
- System Configuration → (submenu) [sudo]
- Owner filter toggle
- ← Back to VM Boot Selector
- Start GNOME session [sudo]
- Exit

**Size:** ~10-15 items (manageable)

**Navigation:**
- Start VM directly from list
- Enter submenus for more options
- Back to VM selector
- Exit

---

## VM Operations Submenu

**Purpose:** All VM-related tasks that don't require sudo

**Categories:**

### VM Creation & Management
- Install VMs workflow (complete guided)
- Create VM wizard (profiles only)
- Edit VM profile
- Delete VM
- Define/Start from JSON
- Validate profile

### Image Management
- ISO manager (download/verify)
- Cloud image manager

### VM Maintenance
- Snapshots & backups
- Clone/Template manager
- Resource optimizer

### Monitoring & Diagnostics
- Metrics & Health diagnostics
- Health checks
- View logs

### Hardware
- Hardware detect & VFIO suggestions

**Size:** ~16 items organized in groups

**All operations:** Non-sudo (except where polkit required)

**Navigation:** ← Back to Main Menu

---

## System Configuration Submenu

**Purpose:** System-level configuration requiring sudo

**Categories:**

### Network Configuration
- Network foundation setup [sudo]
- Bridge helper [sudo]
- Network helper (firewall/DHCP) [sudo]
- Zone manager [sudo]

### Hardware Configuration
- VFIO configure (bind & Nix) [sudo]
- Per-VM firewall [sudo]

### System Maintenance
- Update Hypervisor [sudo]
- Security audit [sudo]
- Preflight check [sudo]

### Help & Documentation
- Docs & Help (read-only, no sudo)
- Interactive tutorial (no sudo)
- Help assistant (no sudo)

**Size:** ~12 items organized in groups

**Most operations:** Require sudo (clearly marked)

**Navigation:** ← Back to Main Menu

---

## Menu Sizes

All menus kept under 20 items:

- **VM Boot Selector:** VMs + 1 option (More Options)
- **Main Menu:** VMs + 8 options
- **VM Operations:** 16 items in organized groups
- **System Configuration:** 12 items in organized groups

**Result:** No overly large menus, easy to navigate

---

## Visual Grouping

Empty entries create visual separation:

```nix
local choices=(
  1 "Create VM wizard"
  2 "Edit VM profile"
  3 "Delete VM"
  "" ""                    # Visual separator
  10 "ISO manager"
  11 "Cloud image manager"
  "" ""                    # Visual separator
  20 "Snapshots & backups"
)
```

**Benefits:**
- Easier to scan
- Logical grouping
- Professional appearance

---

## Navigation Patterns

### Universal Back Option
Every submenu has:
```
99 "← Back to [Parent Menu]"
```

**Consistent position:** Always at bottom
**Consistent ID:** Always 99
**Clear label:** Shows where you're going back to

### Breadcrumb in Title

Menu titles show context:
```
"Hyper-NixOS - Main Menu"
"Hyper-NixOS - VM Operations"
"Hyper-NixOS - System Configuration"
```

### sudo Markers

Operations requiring sudo clearly marked:
```
"Network foundation setup [sudo]"
"VFIO configure [sudo]"
```

**Not marked:** Operations that work without sudo

---

## Implementation Details

### Menu Functions

```bash
menu_vm_main()           # Main menu with VMs + options
menu_vm_operations()     # VM operations submenu (no sudo)
menu_system_config()     # System configuration submenu (sudo)
```

### Loop Structure

```bash
# Main menu loop
while true; do
  choice=$(menu_vm_main || true)
  case "$choice" in
    "__VM_OPS__")
      # VM Operations submenu loop
      while true; do
        vops=$(menu_vm_operations || true)
        case "$vops" in
          # Handle operations
          99|"") break;;  # Back to main menu
        esac
      done
      ;;
  esac
done
```

### Empty Entries

Skip processing for visual separators:
```bash
"") continue;;  # Skip empty entries
```

---

## Benefits

✅ **No overly large menus** - Each menu under 20 items
✅ **Clear organization** - Related items grouped
✅ **Easy navigation** - Consistent back buttons
✅ **Visual clarity** - Grouped with separators
✅ **Sudo awareness** - Clear [sudo] markers
✅ **Context aware** - Breadcrumb titles
✅ **Logical flow** - Common tasks easier to reach

---

## Example User Flows

### Quick VM Start
```
1. Boot
2. VM Selector appears
3. Last VM auto-selected
4. Timer counts down → VM starts
```

### Create First VM
```
1. Boot → VM Selector (no VMs)
2. More Options → Main Menu
3. VM Operations →
4. Install VMs workflow
5. Complete setup
6. VM created and started
```

### Configure Networking
```
1. Main Menu
2. System Configuration →
3. Network foundation setup [sudo]
4. Complete wizard
5. ← Back to Main Menu
```

### Browse Options
```
1. Main Menu
2. VM Operations → (browse)
3. ← Back to Main Menu
4. System Configuration → (browse)
5. ← Back to Main Menu
6. ← Back to VM Selector
```

---

## Summary

**Structure:**
- Hierarchical with 3 levels (Boot Selector → Main → Submenus)
- Each menu kept manageable (<20 items)
- Clear navigation up and down hierarchy

**Organization:**
- VM Operations (no sudo)
- System Configuration (sudo required)
- Visual grouping with separators

**Navigation:**
- Consistent "← Back to [Parent]" at bottom
- Breadcrumb titles
- Multiple exit points

**Result:** Clean, organized, easy-to-navigate menu system!
