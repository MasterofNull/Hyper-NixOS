# Hyper-NixOS Installation Workflow

## Complete Installation Flow

This document describes the complete, step-by-step installation workflow for Hyper-NixOS, from bare metal to production-ready hypervisor.

---

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  STEP 1: Install Fresh NixOS System                                │
│  ─────────────────────────────────────                             │
│                                                                     │
│  • Boot NixOS installer ISO                                        │
│  • Partition disks (GPT + EFI)                                     │
│  • Generate hardware-configuration.nix                             │
│  • Install base NixOS system                                       │
│  • Reboot into fresh NixOS                                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  STEP 2: Optional Development Environment Setup                    │
│  ───────────────────────────────────────────                       │
│                                                                     │
│  ┌──────────────────────────────────────┐                         │
│  │  OPTIONAL: Install Dev Tools          │                         │
│  │  • git, vim, tmux, etc.               │                         │
│  │  • Development packages               │                         │
│  │  • Optional: VSCode, editors          │                         │
│  └──────────────────────────────────────┘                         │
│                                                                     │
│  Skip this step for minimal/production installs                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  STEP 3: Install Hyper-NixOS                                       │
│  ────────────────────────────                                      │
│                                                                     │
│  $ curl -L https://github.com/MasterofNull/Hyper-NixOS/raw/main/install.sh | sudo bash
│                                                                     │
│  OR for local installation:                                        │
│                                                                     │
│  $ git clone https://github.com/MasterofNull/Hyper-NixOS.git      │
│  $ cd Hyper-NixOS                                                  │
│  $ sudo ./install.sh                                               │
│                                                                     │
│  The installer will:                                               │
│  • Copy Hyper-NixOS to /etc/hypervisor                            │
│  • Migrate existing users                                          │
│  • Set up flake configuration                                      │
│  • Prepare for first boot                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  STEP 4: First Boot - System Setup Wizard                          │
│  ─────────────────────────────────────────                         │
│                                                                     │
│  System reboots and automatically launches:                        │
│                                                                     │
│  ╔═══════════════════════════════════════════════════════════════╗ │
│  ║  Hyper-NixOS Comprehensive Setup Wizard                      ║ │
│  ╚═══════════════════════════════════════════════════════════════╝ │
│                                                                     │
│  The wizard walks through:                                         │
│                                                                     │
│  1️⃣  Hardware Detection                                            │
│     • CPU: Architecture, vendor, virtualization                   │
│     • Platform: Laptop, desktop, or server                        │
│     • GPUs: NVIDIA, AMD, Intel                                    │
│     • Network: WiFi, Bluetooth, interfaces                        │
│                                                                     │
│  2️⃣  Feature Selection (Hardware-Aware)                            │
│     ✓ Available features shown in green                           │
│     ○ Unavailable features greyed out with reasons                │
│     • KVM virtualization                                           │
│     • GPU passthrough (if hardware supports)                      │
│     • SR-IOV networking (if IOMMU available)                      │
│     • Laptop features (if laptop detected)                        │
│     • And many more...                                             │
│                                                                     │
│  3️⃣  User & Privilege Configuration                                │
│     • Define VM users (can manage VMs, no sudo)                   │
│     • Define VM operators (advanced ops, limited sudo)            │
│     • Define system admins (full sudo access)                     │
│     • Set up privilege separation                                  │
│                                                                     │
│  4️⃣  GUI Environment (Optional)                                     │
│     • Headless (no GUI)                                            │
│     • GNOME                                                         │
│     • KDE Plasma                                                    │
│     • XFCE                                                          │
│     • i3 (tiling window manager)                                   │
│                                                                     │
│  5️⃣  VM Deployment (Optional)                                       │
│     • Pre-configured VM templates                                  │
│     • Operating systems available                                  │
│     • Resource allocation                                          │
│                                                                     │
│  6️⃣  Configuration Generation                                       │
│     • Generates NixOS configuration                                │
│     • Creates VM definitions                                       │
│     • Sets up networking                                           │
│                                                                     │
│  📝 SYSTEM STATE: Permissive Mode                                  │
│     • File permissions: 0755/0644 (relaxed)                       │
│     • Easy to configure and test                                   │
│     • Full access for troubleshooting                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  STEP 5: Optional System Hardening                                 │
│  ──────────────────────────────────                                │
│                                                                     │
│  At completion, wizard asks:                                       │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Optional: System Hardening                                │  │
│  │                                                            │  │
│  │  Now that setup is complete, you can optionally harden    │  │
│  │  the system to lock down security and restrict file       │  │
│  │  permissions.                                              │  │
│  │                                                            │  │
│  │  Would you like to harden the system now?                 │  │
│  │                                                            │  │
│  │  1) Yes - Run hardening wizard now (production)           │  │
│  │  2) No  - Keep permissive mode (testing) [DEFAULT]        │  │
│  │  3) Later - I'll run manually when ready                  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────┐         ┌─────────────────┐                  │
│  │  Option 1: YES  │         │ Option 2/3: NO  │                  │
│  └─────────────────┘         └─────────────────┘                  │
│          │                            │                             │
│          ▼                            ▼                             │
│  ┌──────────────────────┐    ┌──────────────────────┐             │
│  │ Hardening Wizard     │    │ Stay Permissive      │             │
│  │ Launches:            │    │                      │             │
│  │                      │    │ Skip hardening       │             │
│  │ Select profile:      │    │ Continue to Step 6   │             │
│  │ • Development 🟢     │    │                      │             │
│  │ • Balanced 🔵 ⭐     │    │ Can run later:       │             │
│  │ • Strict 🟡          │    │ sudo hv-harden       │             │
│  │ • Paranoid 🔴        │    └──────────────────────┘             │
│  │                      │                                           │
│  │ Applies:             │                                           │
│  │ • File permissions   │                                           │
│  │ • Firewall rules     │                                           │
│  │ • Audit logging      │                                           │
│  │ • Service hardening  │                                           │
│  └──────────────────────┘                                           │
│                                                                     │
│  📝 SYSTEM STATE AFTER HARDENING:                                  │
│     • Balanced: 0750/0640 (wheel group access)                    │
│     • Strict: 0750/0600 (admin group only)                        │
│     • Paranoid: 0700/0600 (root only)                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  STEP 6: Complete Installation and Switch                          │
│  ────────────────────────────────────────                          │
│                                                                     │
│  Final steps performed automatically:                              │
│                                                                     │
│  1️⃣  Apply NixOS Configuration                                     │
│     $ sudo nixos-rebuild switch --flake /etc/hypervisor           │
│                                                                     │
│  2️⃣  Create VMs (if selected)                                      │
│     • VM disk images created                                       │
│     • Network bridges configured                                   │
│     • VMs registered with libvirt                                  │
│                                                                     │
│  3️⃣  Mark Setup Complete                                           │
│     • Create /var/lib/hypervisor/.setup-complete                  │
│     • Setup wizard won't run again on boot                        │
│                                                                     │
│  4️⃣  System Reboot                                                 │
│     • 10-second countdown                                          │
│     • Reboot into configured system                                │
│                                                                     │
│  ✅ INSTALLATION COMPLETE!                                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  FINAL STATE: Production Hyper-NixOS System                        │
│  ──────────────────────────────────────────                        │
│                                                                     │
│  Your system is now:                                               │
│                                                                     │
│  ✅ Fully configured hypervisor                                    │
│  ✅ Hardware-optimized for your platform                           │
│  ✅ Privilege separation enabled (if configured)                   │
│  ✅ Security hardened (if selected)                                │
│  ✅ VMs ready to use (if created)                                  │
│  ✅ GUI environment (if selected)                                  │
│                                                                     │
│  Available commands:                                               │
│  • virsh list --all          - List VMs                           │
│  • virt-manager              - GUI VM management                   │
│  • hv                        - Hyper-NixOS CLI                     │
│  • hv-hardware-info          - View detected hardware              │
│  • hv-platform-info          - View platform details               │
│  • sudo hv-harden            - Adjust hardening (if needed)        │
│  • sudo hv-check-updates     - Check for NixOS updates             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Step-by-Step Guide

### Step 1: Install Fresh NixOS System

**Prerequisites**:
- NixOS installer ISO (latest stable: 24.05)
- Target hardware (physical or VM)
- Internet connection

**Procedure**:

1. **Boot NixOS installer ISO**
   ```bash
   # From BIOS/UEFI boot menu, select NixOS USB/ISO
   ```

2. **Partition disks** (GPT + EFI recommended)
   ```bash
   # Example for /dev/sda:
   sudo parted /dev/sda -- mklabel gpt
   sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
   sudo parted /dev/sda -- set 1 esp on
   sudo parted /dev/sda -- mkpart primary 512MiB 100%

   # Format partitions
   sudo mkfs.fat -F 32 -n boot /dev/sda1
   sudo mkfs.ext4 -L nixos /dev/sda2

   # Mount
   sudo mount /dev/disk/by-label/nixos /mnt
   sudo mkdir -p /mnt/boot
   sudo mount /dev/disk/by-label/boot /mnt/boot
   ```

3. **Generate NixOS configuration**
   ```bash
   sudo nixos-generate-config --root /mnt
   ```

4. **Install base NixOS**
   ```bash
   sudo nixos-install
   sudo reboot
   ```

5. **Reboot and login**
   ```bash
   # Login with root and password set during install
   # Or login with created user account
   ```

**Result**: Fresh NixOS system ready for Hyper-NixOS installation

---

### Step 2: Optional Development Environment Setup

**This step is OPTIONAL** - Skip for minimal/production installs.

**For development/testing environments**:

```nix
# Edit /etc/nixos/configuration.nix
environment.systemPackages = with pkgs; [
  # Essential tools
  git
  vim
  tmux
  wget
  curl

  # Development tools (optional)
  gcc
  python3
  nodejs

  # Editors (optional)
  vscode
  neovim

  # Utilities
  htop
  ncdu
  tree
];
```

**Apply configuration**:
```bash
sudo nixos-rebuild switch
```

**Result**: Development tools available (if desired)

---

### Step 3: Install Hyper-NixOS

**Method 1: Remote Install (Recommended)**

```bash
curl -L https://github.com/MasterofNull/Hyper-NixOS/raw/main/install.sh | sudo bash
```

**Method 2: Local Install**

```bash
# Clone repository
git clone https://github.com/MasterofNull/Hyper-NixOS.git
cd Hyper-NixOS

# Run installer
sudo ./install.sh
```

**What the installer does**:

1. Detects existing NixOS installation
2. Backs up current configuration
3. Copies Hyper-NixOS to `/etc/hypervisor`
4. Migrates existing users to `/etc/nixos/modules/users-migrated.nix`
5. Sets up flake configuration
6. Prepares first-boot wizard
7. Prompts for reboot

**Installer output**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Hyper-NixOS Installation Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Installation Directory: /etc/hypervisor
Backup Created: /etc/hypervisor/backups/backup-20250115-103000/
Users Migrated: 3 users

Next Steps:
1. Reboot your system
2. First-boot wizard will launch automatically
3. Follow wizard to configure your hypervisor

To reboot now: sudo reboot
To reboot later: reboot manually when ready

On first boot, you'll see the comprehensive setup wizard.
```

**Reboot**:
```bash
sudo reboot
```

**Result**: Hyper-NixOS installed, ready for first boot

---

### Step 4: First Boot - System Setup Wizard

**What happens**:

After reboot, the system automatically launches the **Comprehensive Setup Wizard** on TTY1.

#### 4.1: Welcome Screen

```
╦ ╦┬ ┬┌─┐┌─┐┬─┐   ╔╗╔┬─┐ ┬╔═╗╔═╗
╠═╣└┬┘├─┘├┤ ├┬┘───║║║│┌┴┬┘║ ║╚═╗
╩ ╩ ┴ ┴  └─┘┴└─   ╝╚╝┴┴ └─╚═╝╚═╝
Next-Generation Virtualization Platform

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Comprehensive Setup Wizard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Welcome to Hyper-NixOS!

This wizard will guide you through:
• Hardware detection and optimization
• Feature selection based on your hardware
• User and privilege configuration
• Optional GUI environment
• VM deployment
• System hardening (optional)

Press Enter to begin...
```

#### 4.2: Hardware Detection

```
Detecting Hardware...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Hardware Detected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Architecture:  x86_64
  CPU Vendor:    AMD
  Platform Type: desktop

  Capabilities:
  ✓ Hardware Virtualization (KVM)
  ✓ IOMMU / PCI Passthrough
  ✓ GPU Passthrough
  ✓ NVIDIA GPU Features

  System Resources:
  • RAM: 32 GB
  • CPUs: 16 cores
  • GPUs: NVIDIA RTX 3080, AMD Radeon RX 6800

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Press Enter to continue...
```

#### 4.3: Feature Selection (Hardware-Aware)

```
Feature Selection

Select features to enable:

Core Features:
  ✓ VM Management (required)
  ✓ Privilege Separation (recommended)

Virtualization Features:
  ✓ KVM Virtualization (available)
  ✓ GPU Passthrough (available - 2 GPUs detected)
  ✓ Nested Virtualization (available - VMX/SVM supported)
  ○ SR-IOV Networking (unavailable: IOMMU not enabled in BIOS)

Platform Features (Desktop):
  ✓ Multi-Monitor Support
  ✓ Gaming Optimizations
  ○ Touchpad Configuration (unavailable: No touchpad detected)
  ○ Battery Management (unavailable: No battery detected)

GPU Features:
  ✓ NVIDIA Drivers (NVIDIA RTX 3080 detected)
  ✓ AMD ROCm (AMD Radeon RX 6800 detected)

Network Features:
  ✓ WiFi Management (WiFi adapter detected)
  ✓ Bluetooth Management (Bluetooth adapter detected)

Select features with Space, Enter when done.
```

#### 4.4: User & Privilege Configuration

```
User Configuration

Define user roles for privilege separation:

VM Users (can manage VMs, no sudo needed):
  Enter usernames separated by spaces: alice bob charlie

VM Operators (advanced VM operations, limited sudo):
  Enter usernames separated by spaces: alice

System Admins (full sudo access for system changes):
  Enter usernames separated by spaces: admin

Allow passwordless VM operations? (y/N) [y]: y

Summary:
  • alice: VM User, VM Operator, System Admin
  • bob: VM User
  • charlie: VM User
  • admin: System Admin

VM operations will NOT require sudo password.
System changes WILL require sudo password.

Continue? (y/N):
```

#### 4.5: GUI Environment Selection

```
GUI Environment

Select desktop environment (optional):

  1) Headless (no GUI) - Recommended for servers
  2) GNOME - Modern, user-friendly
  3) KDE Plasma - Feature-rich, customizable
  4) XFCE - Lightweight, fast
  5) i3 - Tiling window manager (advanced)

Select (1-5) [1]: 3

✓ KDE Plasma selected
```

#### 4.6: VM Deployment (Optional)

```
VM Deployment

Would you like to deploy VMs now? (y/N): y

Available VM templates:
  1) Ubuntu 22.04 LTS Desktop
  2) Ubuntu 22.04 LTS Server
  3) Windows 11 Pro
  4) Arch Linux
  5) Custom (manual configuration)

Select VMs to create (comma-separated): 1,2,3

VM Configuration:

Ubuntu Desktop:
  • CPUs: 4 (recommended based on 16-core host)
  • RAM: 8 GB
  • Disk: 80 GB
  • GPU Passthrough: No

Ubuntu Server:
  • CPUs: 2
  • RAM: 4 GB
  • Disk: 40 GB
  • GPU Passthrough: No

Windows 11:
  • CPUs: 8
  • RAM: 16 GB
  • Disk: 120 GB
  • GPU Passthrough: Yes (NVIDIA RTX 3080)

Continue with these settings? (y/N):
```

#### 4.7: Configuration Summary

```
Configuration Summary

The following configuration will be applied:

Hardware:
  ✓ AMD Ryzen platform optimizations
  ✓ NVIDIA and AMD GPU drivers
  ✓ WiFi and Bluetooth support

Features:
  ✓ KVM virtualization
  ✓ GPU passthrough
  ✓ Nested virtualization
  ✓ Multi-monitor support
  ✓ Gaming optimizations

Users & Privileges:
  ✓ Privilege separation enabled
  ✓ VM operations: NO sudo required
  ✓ System changes: sudo REQUIRED

GUI:
  ✓ KDE Plasma desktop environment

VMs to Create:
  ✓ Ubuntu Desktop (4 CPUs, 8 GB RAM, 80 GB disk)
  ✓ Ubuntu Server (2 CPUs, 4 GB RAM, 40 GB disk)
  ✓ Windows 11 (8 CPUs, 16 GB RAM, 120 GB, GPU passthrough)

System State:
  📝 PERMISSIVE MODE (easy testing and configuration)

Apply configuration? (y/N):
```

**Result**: Configuration generated, system ready to apply

---

### Step 5: Optional System Hardening

**After configuration is applied**, wizard asks:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Optional: System Hardening
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Now that setup is complete, you can optionally harden the system
to lock down security and restrict file permissions.

Current State: Permissive (easy configuration and testing)
Hardening: Locks down permissions, requires sudo for system changes

Hardening is NOT mandatory and can be applied later.
You can always run: sudo hv-harden

Would you like to harden the system now?

  1) Yes - Run hardening wizard now (recommended for production)
  2) No  - Keep permissive mode (recommended for initial testing)
  3) Later - I'll run it manually when ready

Select option (1-3) [2]:
```

**Option 1: Yes - Run Hardening Wizard**

```
Launching system hardening wizard...

Select Hardening Profile:

  1) Development (minimal hardening, easy testing)
  2) Balanced (recommended for most users) ⭐
  3) Strict (production environments)
  4) Paranoid (maximum security)

Select profile (1-4) [2]: 2

Creating backup: pre-hardening-20250115-103000
✓ Backup created

Applying: Balanced

Applying Balanced Hardening Profile...
✓ File permissions set: 0750/0640
✓ Firewall rules applied
✓ Secure areas locked down
✓ Balanced hardening applied

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Hardening profile applied: Balanced
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Important Notes:
• Test all VM operations to ensure they still work
• Check that authorized users can access their VMs
• Review audit logs: journalctl -t audit

To reverse these changes: sudo hv-harden → Select 'Un-harden'
```

**Option 2/3: No / Later - Stay Permissive**

```
✓ System will remain in permissive mode
  This is recommended for initial testing and configuration.
  You can harden later with: sudo hv-harden
```

**Result**: System hardened (if selected) or stays permissive

---

### Step 6: Complete Installation and Switch

**Final automated steps**:

```
Applying Configuration...

[1/4] Running nixos-rebuild switch...
      This may take several minutes...
      ✓ NixOS configuration applied

[2/4] Creating VMs...
      • Creating Ubuntu Desktop VM...        ✓
      • Creating Ubuntu Server VM...         ✓
      • Creating Windows 11 VM...            ✓
      ✓ All VMs created successfully

[3/4] Marking setup complete...
      ✓ /var/lib/hypervisor/.setup-complete created

[4/4] Final configuration...
      ✓ Services enabled
      ✓ Network configured
      ✓ GUI environment ready

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Setup Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Your Hyper-NixOS system is ready!

After Reboot:
  1. System will boot into KDE Plasma
  2. VMs are ready to start
  3. Available commands:
     • virsh list --all - List VMs
     • virt-manager - GUI VM management
     • hv - Hyper-NixOS CLI

Admin GUI Access:
  • Desktop Environment: KDE Plasma
  • Login with your user account

System will reboot in 10 seconds...
Press Ctrl+C to cancel reboot
```

**System reboots automatically**

**Result**: Complete, production-ready Hyper-NixOS installation!

---

## Post-Installation Verification

After reboot, verify everything works:

### Check System Status

```bash
# View detected hardware
hv-hardware-info

# View platform information
hv-platform-info

# Check hardening status (if hardened)
cat /var/lib/hypervisor/hardening-state.json | jq .
```

### Check VMs

```bash
# List all VMs
virsh list --all

# Should show:
#  Id   Name              State
# -----------------------------------
#  -    ubuntu-desktop    shut off
#  -    ubuntu-server     shut off
#  -    windows-11        shut off

# Start a VM
virsh start ubuntu-desktop

# Connect to console
virt-viewer ubuntu-desktop
```

### Test Privilege Separation

```bash
# As regular user (no sudo)
virsh list --all          # ✓ Should work
virt-manager              # ✓ Should work

# System changes require sudo
nixos-rebuild switch      # ✗ Should require sudo
sudo nixos-rebuild switch # ✓ Works with sudo
```

### Check Services

```bash
# LibVirt
systemctl status libvirtd

# Network
systemctl status systemd-networkd

# GUI (if selected)
systemctl status display-manager
```

---

## Common Workflows

### Development Workflow

```bash
# 1. Install fresh NixOS
# 2. Install dev tools (Step 2)
# 3. Install Hyper-NixOS
# 4. Run setup wizard:
#    - Skip VMs (will create manually)
#    - Headless or minimal GUI
#    - Development profile
# 5. Stay in permissive mode
# 6. Develop and test
# 7. When ready: sudo hv-harden → Balanced
```

### Production Workflow

```bash
# 1. Install fresh NixOS
# 2. Skip dev tools
# 3. Install Hyper-NixOS
# 4. Run setup wizard:
#    - Select all needed features
#    - Configure users properly
#    - Deploy production VMs
#    - Balanced or Strict hardening
# 5. Test VMs start correctly
# 6. Reboot into production
```

### Testing/Lab Workflow

```bash
# 1. Install fresh NixOS
# 2. Optional dev tools
# 3. Install Hyper-NixOS
# 4. Run setup wizard:
#    - Enable all available features
#    - Multiple test VMs
#    - Permissive mode (no hardening)
# 5. Experiment freely
# 6. Re-run sudo hv-harden when done testing
```

---

## Troubleshooting

### Issue: Setup wizard doesn't launch on first boot

**Check**:
```bash
# Is setup marked as complete?
ls -la /var/lib/hypervisor/.setup-complete

# If it exists but shouldn't:
sudo rm /var/lib/hypervisor/.setup-complete
sudo reboot
```

### Issue: Can't access VMs after hardening

**Check privilege separation**:
```bash
# Check your groups
groups

# Should include: libvirtd, kvm, hypervisor-users

# If missing:
sudo usermod -aG libvirtd,kvm,hypervisor-users $USER
# Logout and login
```

### Issue: Want to re-run setup wizard

**Remove setup complete flag**:
```bash
sudo rm /var/lib/hypervisor/.setup-complete
sudo reboot
```

### Issue: Want to change hardening profile

**Run hardening wizard again**:
```bash
sudo hv-harden
# Select different profile
```

---

## Summary

**Complete workflow**:
1. ✅ Install NixOS → Fresh system
2. ✅ Optional dev env → Development tools (optional)
3. ✅ Install Hyper-NixOS → Installer copies files
4. ✅ First boot wizard → Configure everything
5. ✅ Optional hardening → Lock down security (optional)
6. ✅ Complete and switch → Production ready!

**Result**: Fully configured, hardware-optimized, optionally hardened hypervisor platform ready for production use!

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
