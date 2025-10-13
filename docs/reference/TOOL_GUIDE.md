# Complete Tool Guide - When, Where, and Why to Use Each Tool

**Your comprehensive guide to mastering the hypervisor toolkit**

---

## 📚 How to Use This Guide

Each tool is explained with:
- **🎯 Purpose** - What the tool does
- **⏰ When to Use** - Situations where you need this tool
- **📍 Where It Fits** - In your workflow
- **🎓 Why It Matters** - The value it provides
- **🚀 Quick Start** - Get started in 30 seconds
- **💡 Pro Tips** - Advanced usage
- **⚠️ Common Mistakes** - What to avoid
- **🔗 Related Tools** - Other tools that work together

---

## Table of Contents

### Essential Tools (Start Here)
1. [Main Menu](#1-main-menu) - Your central hub
2. [VM Dashboard](#2-vm-dashboard) - See everything at once
3. [System Diagnostics](#3-system-diagnostics) - Troubleshoot issues

### VM Management
4. [VM Action Menu](#4-vm-action-menu) - Manage individual VMs
5. [Create VM Wizard](#5-create-vm-wizard) - Build new VMs
6. [Bulk Operations](#6-bulk-operations) - Manage multiple VMs

### Setup & Configuration
7. [Setup Wizard](#7-setup-wizard) - First-time configuration
8. [ISO Manager](#8-iso-manager) - Download and verify OS images
9. [Bridge Helper](#9-bridge-helper) - Configure networking

### Monitoring & Health
10. [Health Monitor](#10-health-monitor) - Automated health checks
11. [Metrics Exporter](#11-metrics-exporter) - Prometheus integration
12. [Enhanced Health Checks](#12-enhanced-health-checks) - Deep diagnostics

### Advanced Features
13. [VFIO Workflow](#13-vfio-workflow) - GPU passthrough
14. [Snapshots & Backups](#14-snapshots--backups) - Data protection
15. [Network Zones](#15-network-zones) - Network isolation

---

## Essential Tools (Start Here)

### 1. Main Menu

**📍 Location:** `/etc/hypervisor/scripts/menu.sh`  
**🎯 Purpose:** Central hub for all hypervisor operations

#### ⏰ When to Use
- **Always** - This is your starting point
- After boot (appears automatically if enabled)
- When you need to manage VMs
- When you're not sure which tool to use

#### 📍 Where It Fits in Your Workflow
```
System Boot → Main Menu → Choose Operation → Specific Tool → Back to Menu
```

#### 🎓 Why It Matters
- **Discoverability** - All features in one place
- **Consistency** - Familiar interface for all operations
- **Safety** - Guided operations prevent mistakes
- **Efficiency** - Quick access to common tasks

#### 🚀 Quick Start
```bash
# Launch menu
/etc/hypervisor/scripts/menu.sh

# Or wait for it at boot (if enabled)
```

#### What You'll See
```
═══════════════════════════════════════════
  Hypervisor - VMs
═══════════════════════════════════════════

  VM: ubuntu-desktop
  VM: windows-11
  VM: test-server
  
  Start GNOME management session
  More Options
  Update Hypervisor
  Exit
```

#### 💡 Pro Tips
- **Keyboard shortcuts** - Number keys to select items
- **Tab/Arrow keys** - Navigate menu items
- **Space** - Select checkboxes
- **Enter** - Confirm selection
- **Esc** - Cancel/back

#### ⚠️ Common Mistakes
- ❌ Exiting menu instead of returning to it (use "Back" options)
- ❌ Not exploring "More Options" (many useful tools there)
- ❌ Forgetting you can run tools directly from command line

#### 🔗 Related Tools
- **VM Action Menu** - Appears when you select a VM
- **More Options Menu** - Access to advanced features
- **VM Dashboard** - Alternative overview interface

---

### 2. VM Dashboard

**📍 Location:** `/etc/hypervisor/scripts/vm_dashboard.sh`  
**🎯 Purpose:** Real-time visual overview of all VMs and host resources

#### ⏰ When to Use
- **Monitoring** - Want to see all VMs at once
- **Resource Planning** - Check overall resource usage
- **Quick Status** - See what's running without commands
- **Bulk Actions** - Need to start/stop multiple VMs

#### 📍 Where It Fits in Your Workflow
```
Need Overview → VM Dashboard → See All VMs + Resources → Take Action
```

#### 🎓 Why It Matters
- **Visibility** - See entire environment at a glance
- **Speed** - No need to run multiple commands
- **Understanding** - Resource usage shown visually
- **Quick Actions** - Bulk operations built-in

#### 🚀 Quick Start
```bash
# Launch dashboard
/etc/hypervisor/scripts/vm_dashboard.sh

# Or from menu:
# Main Menu → More Options → VM Dashboard
```

#### What You'll See
```
═══════════════════════════════════════════════════════════════════════
  Hypervisor Dashboard - Real-time VM Status
═══════════════════════════════════════════════════════════════════════

  System: hypervisor  |  Time: 2025-10-11 10:30:00  |  Refresh: 5s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  HOST RESOURCES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Uptime: 2 days, 3 hours      Load Avg: 1.2, 1.5, 1.3
  Memory: 8.2G / 16G     [████████████████████░░░░░░░░░░░░░░░░░░░░] 51%
  Disk:   120G / 500G    (24% used)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VIRTUAL MACHINES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  NAME                 STATE      vCPUs     MEMORY     DISK I/O    NETWORK
  ----                 -----      -----     ------     --------    -------
  ▶ ubuntu-desktop     running        2   2048K/4096K   Active      Active
  ▶ windows-11         running        4   4096K/8192K   Active      Active
  ■ test-server        stopped        -          -         -           -

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  QUICK ACTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [R] Refresh  [S] Start all  [T] Stop all  [D] Diagnostics  [Q] Quit
```

#### 💡 Pro Tips
- **Auto-refresh** - Dashboard updates every 5 seconds
- **Color coding** - Green=running, Red=stopped, Yellow=paused
- **Visual bars** - Quick resource usage assessment
- **Instant actions** - Press S to start all stopped VMs

#### ⏰ Best Times to Use
- **Morning** - Check what's running before starting work
- **After changes** - Verify VMs started correctly
- **During incidents** - Quick overview of system state
- **Before maintenance** - See what needs to be stopped

#### 🔗 Related Tools
- **Bulk Operations** - For more complex multi-VM tasks
- **System Diagnostics** - For detailed health analysis
- **Main Menu** - For individual VM management

---

### 3. System Diagnostics

**📍 Location:** `/etc/hypervisor/scripts/diagnose.sh`  
**🎯 Purpose:** Comprehensive health check and troubleshooting assistant

#### ⏰ When to Use
- **Something's wrong** - VMs won't start, network issues, etc.
- **Before asking for help** - Gather information first
- **After changes** - Verify system health
- **Periodic check** - Weekly health verification
- **Before production** - Validate system is ready

#### 📍 Where It Fits in Your Workflow
```
Problem Occurs → Run Diagnostics → Review Output → Follow Recommendations → Problem Solved
```

Or:
```
Regular Maintenance → Run Diagnostics → Verify Health → Take Preventive Actions
```

#### 🎓 Why It Matters
- **Self-Service** - Fix issues without external help
- **Time Saving** - Automated checks vs manual investigation
- **Comprehensive** - Checks everything in one run
- **Actionable** - Tells you exactly how to fix issues
- **Learning** - Teaches you about system components

#### 🚀 Quick Start
```bash
# Run diagnostics
/etc/hypervisor/scripts/diagnose.sh

# Or from menu:
# More Options → System Diagnostics

# Save to file
/etc/hypervisor/scripts/diagnose.sh > /tmp/diagnostics.txt
```

#### What It Checks

1. **System Information**
   - Hostname, kernel version, architecture
   - Uptime and load average
   - WHY: Understanding system environment

2. **Virtualization Support**
   - KVM device availability
   - CPU virtualization flags (VT-x/AMD-V)
   - WHY: VMs won't work without this

3. **IOMMU Support**
   - IOMMU enabled status
   - WHY: Needed for GPU passthrough

4. **Libvirt Status**
   - Daemon running status
   - Default network state
   - WHY: Core service for VM management

5. **Storage Space**
   - Available disk space
   - Usage by directory
   - WHY: VMs need space for disks

6. **Network Bridges**
   - Configured bridges
   - WHY: Understand network topology

7. **Virtual Machines**
   - Profile count, running count
   - Current states
   - WHY: Know your environment

8. **Security**
   - AppArmor status
   - Audit daemon status
   - WHY: Verify security is active

9. **Dependencies**
   - Required tools installed
   - WHY: Tools need dependencies

10. **Recent Errors**
    - Last 24h errors from logs
    - WHY: Identify problems quickly

11. **Recommendations**
    - Actionable suggestions
    - WHY: Know what to fix

#### 💡 Pro Tips
- **Run after boot** - Verify system is healthy
- **Pipe to less** - For easier reading: `diagnose.sh | less`
- **Save reports** - For tracking issues over time
- **Share with support** - When asking for help

#### ⏰ Recommended Schedule
- **Daily** - Quick glance (30 seconds)
- **Weekly** - Full review (5 minutes)
- **After updates** - Verify no regressions
- **Before major changes** - Baseline health status

#### Example Output and What It Means

```
✓ KVM device present: /dev/kvm
  → GOOD: Hardware virtualization available
  → MEANS: VMs will run fast (near-native speed)

✗ IOMMU not enabled
  → NOT CRITICAL: Basic VMs work fine
  → MEANS: Can't do GPU passthrough yet
  → TO FIX: Add kernel parameters (shown in output)

⚠ Disk usage at 85%
  → WARNING: Getting low on space
  → MEANS: May not be able to create new VMs soon
  → ACTION: Clean up old ISOs or run nix-collect-garbage
```

#### 🔗 Related Tools
- **Health Monitor** - Continuous background checking
- **VM Dashboard** - Real-time resource monitoring
- **Preflight Check** - Pre-operation validation

---

## VM Management Tools

### 4. VM Action Menu

**📍 Location:** Appears when you select a VM from main menu  
**🎯 Purpose:** Comprehensive management interface for individual VMs

#### ⏰ When to Use
- **Every time you select a VM** - Replaces direct start
- **Need VM info** - Check status and resources
- **VM operations** - Start, stop, console, edit, etc.
- **Learning** - Discover what you can do with a VM

#### 📍 Where It Fits in Your Workflow
```
Main Menu → Select VM → Action Menu → Choose Operation → Execute → Back to Menu
```

#### 🎓 Why It Matters
- **Discoverability** - See all available actions
- **Safety** - Confirmations for destructive operations
- **Efficiency** - Common tasks one click away
- **Learning** - Shows capabilities without memorizing commands

#### 🚀 Quick Start
```
1. From main menu, select any VM
2. Action menu appears automatically
3. Choose numbered option
4. Follow prompts
```

#### Available Actions Explained

**1. Start/Resume VM**
- ⏰ WHEN: VM is stopped or paused
- 📍 WHERE: Beginning of work session
- 🎓 WHY: Powers on the VM, runs OS
- 💡 TIP: Check diagnostics first if fails repeatedly

**2. Launch Console (SPICE/VNC)**
- ⏰ WHEN: Need to see VM display, install OS
- 📍 WHERE: After starting VM, during installation
- 🎓 WHY: Access graphical interface, like a monitor
- 💡 TIP: Installs remote-viewer if missing
- ⚠️ NOTE: Auto-starts VM if stopped

**3. View VM Status**
- ⏰ WHEN: Want detailed info (vCPUs, memory, state)
- 📍 WHERE: Troubleshooting, verifying config
- 🎓 WHY: Shows complete VM configuration
- 💡 TIP: Same as `virsh dominfo VM-NAME`

**4. Edit Profile**
- ⏰ WHEN: Need to change VM settings
- 📍 WHERE: Before restarting VM with new config
- 🎓 WHY: Modify hardware, add features
- ⚠️ WARNING: Stop VM before editing major settings
- 💡 TIP: Changes apply on next VM start

**5. Stop VM (graceful shutdown)**
- ⏰ WHEN: Done using VM, before host shutdown
- 📍 WHERE: End of work session, before maintenance
- 🎓 WHY: Allows OS to shut down cleanly, saves data
- 💡 TIP: Wait 30-60s for shutdown, then verify
- ⚠️ NOTE: VM OS must support ACPI shutdown

**6. Force Stop VM**
- ⏰ WHEN: VM frozen, unresponsive, emergency
- 📍 WHERE: When graceful stop fails or hangs
- 🎓 WHY: Immediate stop like pulling power plug
- ⚠️ WARNING: Can cause data loss! Use only when necessary
- 💡 TIP: Try graceful stop first (option 5)

**7. Delete VM**
- ⏰ WHEN: VM no longer needed
- 📍 WHERE: Cleanup, freeing resources
- 🎓 WHY: Removes VM from libvirt, deletes disk
- ⚠️ WARNING: Permanent! Cannot be undone!
- 💡 TIP: Take snapshot first if unsure
- 📝 NOTE: Profile file is kept (can recreate VM)

**8. Clone VM**
- ⏰ WHEN: Need similar VM, testing, templates
- 📍 WHERE: Creating development environments, backups
- 🎓 WHY: Faster than creating from scratch
- 💡 TIP: Creates profile copy, disk created on first start
- 📝 NOTE: Not a backup! Disk is fresh, no data copied

**9. Back to Main Menu**
- ⏰ WHEN: Done with this VM, need different operation
- 📍 WHERE: After completing any action
- 🎓 WHY: Return to central hub

#### 💡 Pro Tips
- **State shown** - Top of menu shows "running" or "stopped"
- **Safe operations** - Destructive actions require confirmation
- **Quick clone** - Fast way to duplicate VMs for testing
- **Edit anytime** - Can edit while VM is running (applies after restart)

#### 🔗 Related Tools
- **Bulk Operations** - For managing multiple VMs
- **VM Dashboard** - For overview of all VMs
- **Main Menu** - Parent menu

---

### 5. Create VM Wizard

**📍 Location:** `/etc/hypervisor/scripts/create_vm_wizard.sh`  
**🎯 Purpose:** Interactive guide for creating new VMs with best practices

#### ⏰ When to Use
- **First VM** - Learn the process interactively
- **New VM needed** - Easier than manual JSON editing
- **Unsure of settings** - Wizard provides recommendations
- **Want guidance** - Interactive help throughout

#### 📍 Where It Fits in Your Workflow
```
Decide to Create VM → Run Wizard → Answer Questions → VM Profile Created → Start VM
```

#### 🎓 Why It Matters
- **Guided creation** - Step-by-step with explanations
- **Validation** - Ensures settings are valid
- **Recommendations** - Suggests appropriate values
- **Learning** - Teaches VM configuration concepts
- **Error prevention** - Catches issues before they happen

#### 🚀 Quick Start
```bash
# Launch wizard
/etc/hypervisor/scripts/create_vm_wizard.sh /var/lib/hypervisor/vm_profiles /var/lib/hypervisor/isos

# Or from menu:
# More Options → Create VM (wizard)
```

#### Wizard Steps Explained

**Step 1: VM Name**
- ⏰ WHEN: Beginning
- 🎓 WHY: Identifies your VM in all tools
- 💡 TIP: Use descriptive names (ubuntu-desktop, win11-gaming)
- ⚠️ RULES: Alphanumeric, dots, underscores, hyphens only
- 📝 EXAMPLE: `ubuntu-web-server` ✓, `my vm` ✗ (space)

**Step 2: CPU Count (vCPUs)**
- ⏰ WHEN: After name
- 🎓 WHY: Determines how much work VM can do in parallel
- 💡 TIP: Start with 2, increase if VM is slow
- 📊 GUIDANCE: 
  - Desktop OS: 2-4 vCPUs
  - Server: 1-2 vCPUs
  - Gaming: 4+ vCPUs
  - Your system has: X CPUs available

**Step 3: Memory (RAM)**
- ⏰ WHEN: After CPUs
- 🎓 WHY: More memory = VM can do more, runs faster
- 💡 TIP: Leave at least 2-4GB for host
- 📊 GUIDANCE:
  - Ubuntu Desktop: 4096 MB (4GB minimum)
  - Ubuntu Server: 2048 MB (2GB comfortable)
  - Windows 11: 8192 MB (8GB recommended)
  - Your system has: X MB available

**Step 4: Disk Size**
- ⏰ WHEN: After memory
- 🎓 WHY: Storage for OS and applications
- 💡 TIP: Generous sizing, grows as needed (qcow2)
- 📊 GUIDANCE:
  - Ubuntu: 20-30 GB
  - Windows: 40-60 GB
  - Server (minimal): 10-20 GB

**Step 5: Select ISO**
- ⏰ WHEN: After disk size
- 🎓 WHY: OS installer to boot from
- 💡 TIP: Download ISOs first via ISO Manager
- 📝 NOTE: Can be removed after OS installation

**Step 6: Network Type**
- ⏰ WHEN: After ISO selection
- 🎓 WHY: How VM connects to network
- 💡 OPTIONS:
  - `default` (NAT) - For testing, desktops (recommended)
  - `br0` (Bridge) - For servers, services
- 📚 LEARN: See networking guide for details

**Step 7: Review & Save**
- ⏰ WHEN: Final step
- 🎓 WHY: Verify settings before creating
- 💡 TIP: Profile saved to `/var/lib/hypervisor/vm_profiles/`
- 📝 NOTE: Can edit manually later with nano/vim

#### 💡 Pro Tips
- **Recommendations shown** - Based on your hardware
- **Defaults provided** - Sensible starting points
- **Can restart wizard** - If you make a mistake
- **Profile is JSON** - Can copy/edit for similar VMs

#### ⚠️ Common Mistakes
- ❌ Too little memory - OS won't perform well
- ❌ Too much memory - Host becomes slow
- ❌ Forgetting ISO - VM won't boot without it
- ❌ Wrong network - Can't access VM as expected

#### 🔗 Related Tools
- **ISO Manager** - Download ISOs first
- **VM Action Menu** - Start VM after creation
- **Edit Profile** - Modify settings later

---

### 6. Bulk Operations

**📍 Location:** `/etc/hypervisor/scripts/bulk_operations.sh`  
**🎯 Purpose:** Manage multiple VMs at once efficiently

#### ⏰ When to Use
- **Multiple VMs** - Start/stop many at once
- **Batch operations** - Snapshot all VMs
- **Environment management** - Stop entire dev environment
- **Maintenance** - Bulk configuration changes

#### 📍 Where It Fits in Your Workflow
```
Need to Act on Multiple VMs → Bulk Operations → Select VMs → Choose Action → Confirm → Execute
```

#### 🎓 Why It Matters
- **Efficiency** - One operation instead of many
- **Consistency** - Same action to all selected VMs
- **Time Saving** - Bulk snapshot 10 VMs in one command
- **Error Reduction** - Less chance to forget a VM

#### 🚀 Quick Start
```bash
# Launch bulk operations
/etc/hypervisor/scripts/bulk_operations.sh

# Or from menu:
# More Options → Bulk Operations
```

#### Available Operations

**1. Start Multiple VMs**
- ⏰ WHEN: Beginning of day, after host reboot
- 🎓 WHY: Get entire environment running quickly
- 💡 TIP: Check dashboard after to verify all started
- 📝 USE CASE: Start all development VMs at once

**2. Stop Multiple VMs (graceful)**
- ⏰ WHEN: End of day, before host shutdown/reboot
- 🎓 WHY: Clean shutdown prevents data corruption
- 💡 TIP: Wait 1-2 minutes for all to shut down
- ⚠️ NOTE: VMs shut down in parallel, not sequential

**3. Force Stop Multiple VMs**
- ⏰ WHEN: VMs frozen, emergency shutdown needed
- 🎓 WHY: Immediate stop when graceful fails
- ⚠️ WARNING: Risk of data loss! Use only when necessary
- 💡 TIP: Try graceful stop first

**4. Snapshot Multiple VMs**
- ⏰ WHEN: Before risky changes, end of project phase
- 🎓 WHY: Backup point you can restore to
- 💡 TIP: Name snapshots descriptively (pre-update, working-state)
- 📝 USE CASE: Snapshot all VMs before system update

**5. Configure Autostart**
- ⏰ WHEN: Setting up production environment
- 🎓 WHY: VMs start automatically on host boot
- 💡 TIP: Only autostart essential VMs
- ⚠️ NOTE: Adds to boot time (starts sequentially)

**6. Delete Multiple VMs**
- ⏰ WHEN: Cleaning up, removing old environment
- 🎓 WHY: Free disk space, remove unused VMs
- ⚠️ WARNING: PERMANENT! Double confirmation required
- 💡 TIP: Snapshot or backup first if unsure

#### 💡 Pro Tips
- **Checklist interface** - Select which VMs with checkboxes
- **Visual feedback** - Shows state of each VM
- **Confirmation required** - For destructive operations
- **Results summary** - Shows success/failure count
- **Logged operations** - All actions logged to file

#### ⏰ Common Scenarios

**Scenario 1: Daily Startup**
```
Morning → Bulk Operations → Start Multiple VMs
→ Select dev environment VMs → Start → Verify in dashboard
```

**Scenario 2: Pre-Update Backup**
```
Before Update → Bulk Operations → Snapshot Multiple VMs
→ Select all VMs → Name: "pre-update-2025-10-11" → Create
```

**Scenario 3: Environment Cleanup**
```
Project Complete → Bulk Operations → Stop Multiple VMs
→ Select project VMs → Graceful stop → Wait for shutdown
→ Bulk Operations → Delete Multiple VMs → Confirm → Free space
```

#### ⚠️ Common Mistakes
- ❌ Force stop without trying graceful first
- ❌ Deleting without confirming which VMs selected
- ❌ Forgetting to wait for graceful shutdown completion
- ❌ Not taking snapshots before bulk delete

#### 🔗 Related Tools
- **VM Dashboard** - See what needs bulk action
- **VM Action Menu** - For individual VM operations
- **Snapshots & Backups** - For individual backups

---

## Setup & Configuration Tools

### 7. Setup Wizard

**📍 Location:** `/etc/hypervisor/scripts/setup_wizard.sh`  
**🎯 Purpose:** Initial system configuration with guided best practices

#### ⏰ When to Use
- **First boot** - Runs automatically if enabled
- **Reconfiguration** - Change system-wide settings
- **After hardware changes** - Detect new capabilities
- **Learning** - Understand configuration options

#### 📍 Where It Fits in Your Workflow
```
Fresh Install → First Boot → Setup Wizard → Configure Everything → Ready to Use
```

Or:
```
Need to Change Settings → Run Setup Wizard → Update Configuration → Rebuild System
```

#### 🎓 Why It Matters
- **Guided setup** - Step-by-step with explanations
- **Best practices** - Recommends secure defaults
- **Hardware detection** - Finds capabilities automatically
- **Educational** - Explains each choice and its impact
- **Safe defaults** - Secure out of the box

#### 🚀 Quick Start
```bash
# Run setup wizard
/etc/hypervisor/scripts/setup_wizard.sh

# Or from menu:
# Main Menu → Run first-boot setup wizard now
```

#### Wizard Sections Explained

**Section 1: Welcome**
- 🎓 WHAT: Introduction and overview
- 📚 LEARN: What the wizard will configure
- ⏰ TIME: ~5-10 minutes total

**Section 2: Network Bridge**
- ⏰ WHEN: Need VMs on local network
- 🎓 WHY: Allows VMs to get IPs from your router
- 💡 RECOMMENDED: Skip for first-time users (use NAT)
- 📚 LEARN: Difference between NAT and Bridge networking

**Section 3: ISO Download**
- ⏰ WHEN: Need OS installer
- 🎓 WHY: Can't install OS without ISO
- 💡 RECOMMENDED: Yes - download Ubuntu or your choice
- 📚 LEARN: Auto-verification with GPG/checksums

**Section 4: First VM Creation**
- ⏰ WHEN: Ready to create first VM
- 🎓 WHY: Hands-on learning, get started quickly
- 💡 RECOMMENDED: Yes - guided through process
- 📚 LEARN: VM profile creation, resource allocation

**Section 5: Security Settings**
- ⏰ WHEN: Configuring system-wide security
- 🎓 WHY: Protect host and VMs
- 💡 RECOMMENDED: Enable strict firewall
- 📚 LEARN: Firewall concepts, security trade-offs
- ⚠️ NOTE: Can adjust later in configuration files

**Section 6: Performance Settings**
- ⏰ WHEN: Optimizing for your workload
- 🎓 WHY: Balance performance vs flexibility
- 💡 RECOMMENDED FOR SERVERS: Enable hugepages
- 💡 RECOMMENDED FOR SECURITY: Disable SMT
- 📚 LEARN: Memory management, side-channel mitigation
- ⚠️ NOTE: Requires system rebuild to apply

**Section 7: VFIO Detection**
- ⏰ WHEN: Want GPU passthrough
- 🎓 WHY: Gives VM direct GPU access
- 💡 RECOMMENDED: Skip unless needed (advanced)
- 📚 LEARN: VFIO, IOMMU, hardware passthrough
- ⚠️ NOTE: Requires IOMMU enabled in BIOS

**Section 8: Preflight Checks**
- ⏰ WHEN: Automatic (runs at end)
- 🎓 WHY: Verify system is ready
- 📚 LEARN: System capabilities, what's available

**Section 9: Review & Apply**
- ⏰ WHEN: Final step
- 🎓 WHY: Preview changes before applying
- 💡 TIP: Shows exactly what files will be created
- ⚠️ NOTE: May require reboot for some settings

#### What Gets Configured

**Files Created:**
- `/etc/hypervisor/configuration/security-local.nix`
- `/etc/hypervisor/configuration/perf-local.nix`

**Settings Applied:**
- Network bridge (if chosen)
- Downloaded ISOs (if chosen)
- First VM profile (if created)
- Security options (firewall, migration ports)
- Performance options (hugepages, SMT)

#### 💡 Pro Tips
- **Run multiple times** - Safe to re-run, updates settings
- **Skip what you don't need** - All steps optional
- **Review files** - Check generated configs before rebuild
- **Learn as you go** - Each step explains concepts

#### ⏰ When NOT to Use
- ❌ Making small changes - Edit config files directly
- ❌ Just creating a VM - Use VM creation wizard instead
- ❌ In automation - Use direct commands instead

#### ⚠️ Common Mistakes
- ❌ Skipping network setup then wondering why VMs have no network
- ❌ Enabling strict firewall without understanding it
- ❌ Not downloading ISO then confused VM won't boot
- ❌ Forgetting to rebuild after changing settings

#### 🔗 Related Tools
- **Bridge Helper** - Standalone network bridge creation
- **ISO Manager** - Standalone ISO download
- **Create VM Wizard** - Standalone VM creation
- **Preflight Check** - Standalone hardware check

---

### 8. ISO Manager

**📍 Location:** `/etc/hypervisor/scripts/iso_manager.sh`  
**🎯 Purpose:** Download, verify, and manage OS installation images

#### ⏰ When to Use
- **Before creating VM** - Need OS installer
- **Trying new OS** - Download different distributions
- **Verification** - Ensure ISO authenticity
- **Cleanup** - Remove old ISOs to free space

#### 📍 Where It Fits in Your Workflow
```
Need New OS → ISO Manager → Download & Verify → Use in VM Profile → Install OS
```

#### 🎓 Why It Matters
- **Security** - Auto-verifies checksums and GPG signatures
- **Convenience** - No manual download and verification
- **Organization** - All ISOs in one location
- **Trust** - Ensures ISOs are authentic, not tampered

#### 🚀 Quick Start
```bash
# Launch ISO Manager
/etc/hypervisor/scripts/iso_manager.sh

# Or from menu:
# More Options → ISO Manager
```

#### Available Operations

**1. Download from Preset List**
- ⏰ WHEN: Want common distributions (Ubuntu, Debian, Fedora)
- 🎓 WHY: Presets include verification URLs
- 💡 BENEFIT: Automatic GPG/checksum verification
- 📚 LEARN: Official sources, mirror selection
- ✅ RECOMMENDED: Start here for common OSes

**2. Download from URL**
- ⏰ WHEN: Need specific version or distribution
- 🎓 WHY: Flexibility for any ISO
- 💡 TIP: Get URL from official website
- ⚠️ NOTE: Manual checksum verification recommended

**3. Validate ISO Checksum**
- ⏰ WHEN: Downloaded ISO manually, want to verify
- 🎓 WHY: Ensures ISO not corrupted or tampered
- 💡 TIP: Get SHA256 from official website
- ✅ CREATES: `.sha256.verified` marker file

**4. GPG Verify Signature**
- ⏰ WHEN: Want cryptographic verification
- 🎓 WHY: Stronger than checksum (proves authenticity)
- 💡 TIP: For critical/production environments
- 📚 LEARN: Digital signatures, web of trust

**5. Import GPG Key**
- ⏰ WHEN: Before GPG verification
- 🎓 WHY: Need public key to verify signatures
- 💡 TIP: Get key from official distribution page

**6. List ISOs**
- ⏰ WHEN: Want to see what you have
- 🎓 WHY: Find ISO paths for VM profiles
- 💡 TIP: Shows verification status

**7. Scan Local Storage**
- ⏰ WHEN: Have ISOs elsewhere on system
- 🎓 WHY: Find and import existing ISOs
- 💡 TIP: Useful after manual downloads

**8. Mount Network Share**
- ⏰ WHEN: ISOs on NFS/CIFS server
- 🎓 WHY: Access ISOs without downloading
- 💡 TIP: For shared ISO libraries

#### 💡 Pro Tips
- **Auto-verification** - Presets verify automatically
- **Marker files** - `.sha256.verified` shows verified ISOs
- **Security default** - ISO verification required (can bypass)
- **Storage location** - All ISOs in `/var/lib/hypervisor/isos/`

#### 📚 What You Learn
- **ISO verification** - Why and how to verify
- **GPG signatures** - Public key cryptography basics
- **Checksums** - Hash functions and integrity
- **Mirrors** - Distribution delivery networks

#### ⏰ Common Workflows

**Workflow 1: First-Time User**
```
ISO Manager → Download from Preset → Select Ubuntu 24.04
→ Auto-download & verify → Use in VM → Success!
```

**Workflow 2: Specific Version**
```
Find ISO URL on Official Site → ISO Manager → Download from URL
→ Paste URL → Download → Validate Checksum → Use in VM
```

**Workflow 3: Security-Conscious**
```
ISO Manager → Download Preset → Import GPG Key
→ GPG Verify Signature → Double verification → Use in VM
```

#### ⚠️ Common Mistakes
- ❌ Using unverified ISOs (security risk)
- ❌ Not checking disk space before download
- ❌ Downloading wrong architecture (x86_64 vs aarch64)
- ❌ Forgetting ISO path when creating VM

#### 🔗 Related Tools
- **Create VM Wizard** - Uses ISOs you download
- **System Diagnostics** - Shows disk space for ISOs
- **Image Manager** - For cloud images (similar concept)

---

## Monitoring & Health Tools

### 10. Health Monitor

**📍 Location:** `/etc/hypervisor/scripts/health_monitor.sh`  
**🎯 Purpose:** Automated continuous health monitoring with alerting

#### ⏰ When to Use
- **Production environments** - Always running
- **Critical VMs** - Monitor important workloads
- **Proactive monitoring** - Catch issues before users notice
- **Compliance** - Track system health over time

#### 📍 Where It Fits in Your Workflow
```
Setup → Enable Health Monitor Daemon → Runs Continuously → Alerts on Issues → You Respond
```

#### 🎓 Why It Matters
- **Proactive** - Find problems before they impact users
- **Automated** - No manual checks needed
- **Actionable** - Clear alerts with solutions
- **Historical** - Track health over time

#### 🚀 Quick Start
```bash
# One-time health check
/etc/hypervisor/scripts/health_monitor.sh check

# Continuous monitoring (daemon mode)
/etc/hypervisor/scripts/health_monitor.sh daemon &

# Or as systemd service (recommended for production)
```

#### What It Monitors

**Host Health:**
- ✅ KVM device availability
- ✅ Libvirtd service status
- ✅ Disk space (alerts at 90%)
- ✅ Memory usage (alerts at 95%)

**VM Health:**
- ✅ Autostart VMs actually running
- ✅ Guest agent responsiveness
- ✅ Memory pressure
- ✅ Unexpected state changes

**Issues Detected:**
- 🔴 Critical - Immediate action needed
- 🟡 Warning - Attention recommended
- 🔵 Info - FYI, no action needed

#### 💡 Pro Tips
- **JSON output** - Machine-readable health state
- **Integration ready** - Works with alert handlers
- **Logged** - All checks logged to file
- **Customizable** - Edit thresholds in script

#### ⏰ Recommended Usage

**Development:**
- Check manually when issues arise
- Run before major changes

**Production:**
- Run as daemon (continuous monitoring)
- Integrate with alerting system
- Review logs weekly

#### Health State File

```bash
# View current health
cat /var/lib/hypervisor/health_state.json | jq

# Example healthy state:
{
  "timestamp": "2025-10-11T10:30:00+00:00",
  "status": "healthy",
  "issues": {
    "critical": 0,
    "warning": 0,
    "info": 0
  },
  "host_issues": [],
  "vm_issues": []
}

# Example with issues:
{
  "status": "degraded",
  "issues": {
    "critical": 1,
    "warning": 2
  },
  "host_issues": ["Critical: Disk usage at 92%"],
  "vm_issues": [
    "VM ubuntu-desktop: High memory usage: 96%",
    "VM test-server: Configured for autostart but not running"
  ]
}
```

#### 🔗 Related Tools
- **System Diagnostics** - One-time comprehensive check
- **Metrics Exporter** - Continuous metrics collection
- **VM Dashboard** - Real-time status view

---

### 11. Metrics Exporter (Prometheus)

**📍 Location:** `/etc/hypervisor/scripts/prom_exporter_enhanced.sh`  
**🎯 Purpose:** Export system and VM metrics in Prometheus format

#### ⏰ When to Use
- **Production monitoring** - Always running
- **Performance tracking** - Historical data
- **Capacity planning** - Understand trends
- **Integration** - Feed monitoring systems

#### 📍 Where It Fits in Your Workflow
```
Setup → Start Exporter Daemon → Metrics Collected → Prometheus Scrapes → Grafana Displays
```

#### 🎓 Why It Matters
- **Visibility** - See trends over time
- **Alerting** - Automated problem detection
- **Planning** - Data-driven decisions
- **Standards** - Industry-standard format (Prometheus)

#### 🚀 Quick Start
```bash
# Single run (generate metrics once)
/etc/hypervisor/scripts/prom_exporter_enhanced.sh /tmp/metrics.prom
cat /tmp/metrics.prom

# Daemon mode (continuous)
PROM_DAEMON=true \
PROM_INTERVAL=15 \
/etc/hypervisor/scripts/prom_exporter_enhanced.sh &

# Metrics written to:
/var/lib/hypervisor/metrics/hypervisor.prom
```

#### Metrics Collected

**Host Metrics:**
- 📊 Uptime
- 📊 Memory (total/free/available/buffers/cached)
- 📊 CPU count
- 📊 Load average (1/5/15 minute)
- 📊 Disk space (total/used/available)

**VM Metrics (per VM):**
- 📊 State (running/stopped)
- 📊 vCPU count
- 📊 Memory usage
- 📊 CPU time
- 📊 Disk I/O (read/write bytes)
- 📊 Network I/O (RX/TX bytes)

**Service Metrics:**
- 📊 Libvirt status
- 📊 Network status

#### 💡 Pro Tips
- **Lightweight** - <1% CPU overhead
- **File-based** - Easy to integrate
- **Timestamped** - Metrics include timestamps
- **Extensible** - Easy to add custom metrics

#### ⏰ Usage Scenarios

**Scenario 1: Local Monitoring**
```bash
# Run exporter
PROM_DAEMON=true /etc/hypervisor/scripts/prom_exporter_enhanced.sh &

# Watch metrics update
watch -n 5 cat /var/lib/hypervisor/metrics/hypervisor.prom
```

**Scenario 2: Prometheus Integration**
```bash
# Configure Prometheus (see MONITORING_SETUP.md)
# Point to metrics file
# Metrics auto-scraped every 15s
# View in Prometheus UI: http://localhost:9090
```

**Scenario 3: Grafana Dashboards**
```bash
# Setup: Prometheus → Grafana → Import Dashboards
# Result: Visual graphs of all metrics
# Benefit: See trends, set alerts
```

#### 🔗 Related Tools
- **Health Monitor** - Qualitative health checks
- **VM Dashboard** - Real-time TUI view
- **Grafana** - Visual dashboards

---

## Advanced Tools

### 13. VFIO Workflow

**📍 Location:** `/etc/hypervisor/scripts/vfio_workflow.sh`  
**🎯 Purpose:** Set up GPU/device passthrough for VMs

#### ⏰ When to Use
- **Gaming VMs** - Need GPU for performance
- **Graphics work** - 3D rendering, video editing
- **AI/ML** - GPU compute in VMs
- **Specialized hardware** - USB devices, sound cards

#### ⏰ When NOT to Use
- ❌ First-time users - Advanced feature
- ❌ Basic VMs - Virtual GPU works fine
- ❌ No IOMMU - Hardware requirement not met
- ❌ Single GPU - Need second GPU for host

#### 📍 Where It Fits in Your Workflow
```
Have Spare GPU → VFIO Workflow → Detect Devices → Configure Passthrough
→ Update VM Profile → Start VM → GPU Works in VM
```

#### 🎓 Why It Matters
- **Performance** - Near-native GPU performance in VM
- **Functionality** - Some apps require real GPU
- **Gaming** - Play games in Windows VM
- **Professional** - CAD, video editing, rendering

#### 📚 What You Learn
- **IOMMU groups** - Hardware isolation
- **VFIO drivers** - Kernel modules for passthrough
- **Device IDs** - PCI device identification
- **Host/guest separation** - Driver binding

#### 🚀 Quick Start
```bash
# Run VFIO workflow
/etc/hypervisor/scripts/vfio_workflow.sh

# Or from setup wizard:
# Setup → Detect hardware and prepare VFIO
```

#### Prerequisites Explained

**1. IOMMU Enabled**
- 📚 WHAT: Hardware feature for device isolation
- ⏰ CHECK: `dmesg | grep -i iommu`
- 🔧 ENABLE: Add kernel parameter `intel_iommu=on` or `amd_iommu=on`
- 🎓 WHY: Required for secure device passthrough

**2. Multiple GPUs (Usually)**
- 📚 WHAT: One for host, one for VM
- ⏰ CHECK: `lspci | grep VGA`
- 🎓 WHY: Host needs display too
- 💡 NOTE: Can use single GPU with special setup (Looking Glass)

**3. VFIO Kernel Modules**
- 📚 WHAT: Drivers that allow passthrough
- ⏰ CHECK: `lsmod | grep vfio`
- 🔧 LOAD: Automatically configured by workflow
- 🎓 WHY: Binds device to VFIO instead of host driver

#### Workflow Steps

**Step 1: Detect Devices**
- Shows all PCI devices
- Highlights GPUs and audio devices
- Displays IOMMU groups
- 🎓 TEACHES: PCI addressing, device types

**Step 2: Select Devices**
- Choose which devices to pass through
- Shows devices in same IOMMU group
- Warns about conflicts
- 🎓 TEACHES: IOMMU group isolation

**Step 3: Generate Configuration**
- Creates Nix configuration snippet
- Configures kernel modules
- Sets up device binding
- 🎓 TEACHES: Nix configuration, kernel module loading

**Step 4: Update VM Profile**
- Adds hostdevs to JSON profile
- Configures VM for passthrough
- 🎓 TEACHES: VM device configuration

#### 💡 Pro Tips
- **Looking Glass** - Share GPU between host and VM
- **Audio passthrough** - Pass through with GPU
- **USB controller** - Pass entire USB controller for peripherals
- **Test with live USB** - Before full installation

#### ⚠️ Common Pitfalls
- ❌ GPU in wrong IOMMU group (can't isolate)
- ❌ Forgetting to rebuild after config change
- ❌ Not unbinding from host driver first
- ❌ Passing device host needs (like boot GPU)

#### 🔗 Related Tools
- **Looking Glass** - GPU sharing setup
- **Preflight Check** - IOMMU detection
- **VM Profile Editor** - Modify hostdevs

---

## Learning Path by Experience Level

### For New Users (First Week)

**Day 1: Getting Started**
1. ✅ **System Diagnostics** - Understand your system
2. ✅ **Setup Wizard** - Configure everything
3. ✅ **ISO Manager** - Download first ISO
4. ✅ **Create VM Wizard** - Make first VM
5. ✅ **VM Action Menu** - Start and connect to console

**Day 2-3: Daily Operations**
1. ✅ **VM Dashboard** - Monitor running VMs
2. ✅ **VM Action Menu** - Stop/start VMs
3. ✅ **Main Menu** - Navigate interface

**Day 4-7: Expanding Skills**
1. ✅ **Bulk Operations** - Manage multiple VMs
2. ✅ **Snapshots** - Create backup points
3. ✅ **Troubleshooting Guide** - Fix common issues

### For Intermediate Users (Month 1)

**Week 2: Optimization**
1. ✅ **Performance Tuning** - CPU pinning, hugepages
2. ✅ **Network Zones** - Isolate VM networks
3. ✅ **Resource Limits** - Prevent resource hogging

**Week 3: Automation**
1. ✅ **Bulk Operations** - Automate daily tasks
2. ✅ **Health Monitor** - Set up automated monitoring
3. ✅ **Metrics** - Track performance over time

**Week 4: Advanced Features**
1. ✅ **Cloud Images** - Fast VM deployment
2. ✅ **Templates** - Reusable configurations
3. ✅ **Monitoring** - Grafana dashboards

### For Advanced Users (Month 2+)

**Advanced Features:**
1. ✅ **VFIO Workflow** - GPU passthrough
2. ✅ **SEV/SNP** - Memory encryption
3. ✅ **Live Migration** - Move VMs between hosts
4. ✅ **Custom AppArmor** - Fine-grained security

**Integration:**
1. ✅ **CI/CD** - Automated testing
2. ✅ **Monitoring Stack** - Full observability
3. ✅ **Backup Automation** - Scheduled backups
4. ✅ **API Usage** - Script everything

---

## Tool Comparison Matrix

| Tool | Speed | Complexity | Learning Curve | Best For |
|------|-------|------------|----------------|----------|
| **VM Dashboard** | ⚡⚡⚡ | ⭐ | Low | Quick overview |
| **VM Action Menu** | ⚡⚡ | ⭐ | Low | Individual VM ops |
| **Main Menu** | ⚡⚡ | ⭐ | Low | General navigation |
| **System Diagnostics** | ⚡ | ⭐⭐ | Low | Troubleshooting |
| **Bulk Operations** | ⚡ | ⭐⭐ | Medium | Multi-VM management |
| **Create VM Wizard** | ⚡ | ⭐⭐ | Low | Guided VM creation |
| **ISO Manager** | ⚡ | ⭐⭐ | Low | ISO management |
| **Setup Wizard** | ⚡ | ⭐⭐⭐ | Medium | Initial configuration |
| **Health Monitor** | ⚡⚡⚡ | ⭐⭐⭐ | Medium | Production monitoring |
| **VFIO Workflow** | ⚡ | ⭐⭐⭐⭐⭐ | High | GPU passthrough |

**Legend:**
- ⚡ Speed: How fast it runs
- ⭐ Complexity: How complex to use
- Learning Curve: Time to proficiency

---

## Quick Reference by Task

### "I want to..."

**...create my first VM**
→ ISO Manager + Create VM Wizard + VM Action Menu

**...see all my VMs at once**
→ VM Dashboard

**...fix a problem**
→ System Diagnostics

**...start multiple VMs**
→ Bulk Operations → Start Multiple

**...backup VMs before update**
→ Bulk Operations → Snapshot Multiple

**...check if system is healthy**
→ Health Monitor (check mode) or System Diagnostics

**...monitor production VMs**
→ Health Monitor (daemon) + Metrics Exporter + Grafana

**...pass GPU to Windows VM**
→ VFIO Workflow (requires IOMMU)

**...understand network setup**
→ Setup Wizard (explains options) or Bridge Helper

**...learn the system**
→ Follow tool guides in order above

---

## Getting Help

### In-Tool Help

Most tools have built-in help:
```bash
# Show help
tool.sh --help
tool.sh -h

# Examples:
/etc/hypervisor/scripts/vm_dashboard.sh --help
/etc/hypervisor/scripts/bulk_operations.sh --help
```

### Documentation

- **This guide** - Understanding tools
- **QUICKSTART_EXPANDED.md** - First VM tutorial
- **TROUBLESHOOTING.md** - Problem solving
- **MONITORING_SETUP.md** - Advanced monitoring

### Learning Resources

- **Try in safe environment** - Test VMs won't hurt production
- **Read tool output** - Explanations provided
- **Check logs** - `/var/lib/hypervisor/logs/`
- **Experiment** - Best way to learn!

---

**Remember: Every tool is designed to teach while you use it. Read the messages, follow the prompts, and you'll quickly become proficient!**
