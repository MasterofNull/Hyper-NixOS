# Actionable Fixes - Immediate Implementation Guide

This document provides specific code fixes that can be implemented immediately to address issues found in the audit.

---

## 1. CRITICAL: Fix Setup Wizard Config Generation

**File:** `scripts/setup_wizard.sh` (lines 64-78)

**Current Code (BROKEN):**
```bash
cat > /etc/hypervisor/configuration/security-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.security.strictFirewall = ${sf:+true}${sf:0:0}${sf/1/true}${sf/0/false};
  hypervisor.security.migrationTcp = ${mt:+true}${mt:0:0}${mt/1/true}${mt/0/false};
}
NIX
```

**Fixed Code:**
```bash
cat > /etc/hypervisor/configuration/security-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.security.strictFirewall = $( [[ $sf == 1 ]] && echo true || echo false );
  hypervisor.security.migrationTcp = $( [[ $mt == 1 ]] && echo true || echo false );
}
NIX

cat > /etc/hypervisor/configuration/perf-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.performance.enableHugepages = $( [[ $hp == 1 ]] && echo true || echo false );
  hypervisor.performance.disableSMT = $( [[ $smt == 1 ]] && echo true || echo false );
}
NIX
```

---

## 2. HIGH: Fix Password Input Security

**File:** `scripts/iso_manager.sh`

**Current Code (INSECURE):**
```bash
pass=$($DIALOG --passwordbox "Password (optional)" 10 60 3>&1 1>&2 2>&3 || echo "")
```

**Fixed Code:**
```bash
# Option 1: Use read -s for password input (more secure)
if [[ "$DIALOG" == "whiptail" ]] || [[ "$DIALOG" == "dialog" ]]; then
  # For TUI, use temporary file with restrictive permissions
  tmppass=$(mktemp -p /dev/shm)
  chmod 600 "$tmppass"
  $DIALOG --passwordbox "Password (optional)" 10 60 2>"$tmppass" || echo ""
  pass=$(cat "$tmppass" 2>/dev/null || echo "")
  shred -u "$tmppass" 2>/dev/null || rm -f "$tmppass"
else
  # For command line, use read -s
  echo -n "Password (optional): " >&2
  read -r -s pass
  echo "" >&2
fi
```

---

## 3. MEDIUM: Add VM Name Validation

**File:** `scripts/json_to_libvirt_xml_and_define.sh`

**Current Code:**
```bash
raw_name=$(jq -r '.name' "$PROFILE_JSON")
# Constrain name to safe subset for domain names (defense-in-depth)
if [[ ! "$raw_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  name=$(echo "$raw_name" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
else
  name="$raw_name"
fi
```

**Improved Code:**
```bash
raw_name=$(jq -r '.name' "$PROFILE_JSON")

# Validate VM name: 1-64 chars, alphanumeric + . _ -
# Must not start with . or -
if [[ -z "$raw_name" ]]; then
  echo "Error: VM name cannot be empty" >&2
  exit 1
fi

if [[ ${#raw_name} -gt 64 ]]; then
  echo "Error: VM name too long (max 64 characters): $raw_name" >&2
  exit 1
fi

if [[ ! "$raw_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Error: Invalid VM name: $raw_name" >&2
  echo "Name must start with alphanumeric and contain only: A-Z, a-z, 0-9, ., _, -" >&2
  exit 1
fi

name="$raw_name"
```

---

## 4. MEDIUM: Add Log Rotation

**File:** `configuration/configuration.nix`

**Add this section:**
```nix
  # Log rotation for hypervisor logs
  services.logrotate = {
    enable = true;
    settings = {
      "/var/lib/hypervisor/logs/*.log" = {
        rotate = 7;
        daily = true;
        compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip";
        compressext = ".gz";
        missingok = true;
        notifempty = true;
        sharedscripts = true;
        postrotate = ''
          systemctl reload hypervisor-menu.service 2>/dev/null || true
        '';
      };
      "/var/log/hypervisor/*.log" = {
        rotate = 7;
        daily = true;
        compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip";
        compressext = ".gz";
        missingok = true;
        notifempty = true;
      };
    };
  };
```

---

## 5. MEDIUM: Improve Error Messages

**File:** `scripts/json_to_libvirt_xml_and_define.sh`

**Current Code:**
```bash
require() {
  for b in jq virsh; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done
}
```

**Improved Code:**
```bash
require() {
  local missing=()
  for b in "$@"; do
    if ! command -v "$b" >/dev/null 2>&1; then
      missing+=("$b")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies: ${missing[*]}" >&2
    echo "" >&2
    echo "To install on NixOS:" >&2
    for dep in "${missing[@]}"; do
      case "$dep" in
        jq) echo "  nix-env -iA nixpkgs.jq" >&2 ;;
        virsh) echo "  Enable virtualisation.libvirtd in configuration.nix" >&2 ;;
        *) echo "  nix-env -iA nixpkgs.$dep" >&2 ;;
      esac
    done
    exit 1
  fi
}

require jq virsh qemu-img
```

**Add Better Error Context Throughout:**
```bash
# Before:
qemu-img create -f qcow2 "$qcow" "${disk_gb}G" >/dev/null

# After:
if ! qemu-img create -f qcow2 "$qcow" "${disk_gb}G" >/dev/null 2>&1; then
  echo "Error: Failed to create disk image" >&2
  echo "  Path: $qcow" >&2
  echo "  Size: ${disk_gb}G" >&2
  echo "" >&2
  echo "Possible causes:" >&2
  echo "  - Insufficient disk space (check: df -h /var/lib/hypervisor)" >&2
  echo "  - Permission denied (check: ls -ld /var/lib/hypervisor/disks)" >&2
  echo "  - Invalid size (must be > 0)" >&2
  exit 1
fi
```

---

## 6. MEDIUM: Add ISO Checksum Enforcement

**File:** `scripts/json_to_libvirt_xml_and_define.sh`

**Add after line 111:**
```bash
# Resolve ISO and verify checksum if available
if [[ -n "$iso_path" && ! -f "$iso_path" ]]; then
  # if relative, resolve from ISOS_DIR
  if [[ "$iso_path" != /* ]]; then
    iso_path="$ISOS_DIR/$iso_path"
  fi
fi

# ADDED: Verify ISO has been checksummed
if [[ -n "$iso_path" && -f "$iso_path" ]]; then
  checksum_file="${iso_path}.sha256.verified"
  if [[ ! -f "$checksum_file" ]]; then
    echo "Warning: ISO $iso_path has not been verified with checksums" >&2
    echo "For security, run ISO Manager to verify before use, or manually create:" >&2
    echo "  touch ${iso_path}.sha256.verified" >&2
    echo "" >&2
    if [[ "${HYPERVISOR_REQUIRE_ISO_VERIFICATION:-1}" == "1" ]]; then
      echo "Error: ISO verification required. Set HYPERVISOR_REQUIRE_ISO_VERIFICATION=0 to bypass (not recommended)." >&2
      exit 1
    fi
  fi
fi
```

**Update ISO Manager to Create Verification File:**

**File:** `scripts/iso_manager.sh`

After successful checksum verification (around line where checksums are validated), add:
```bash
# Mark ISO as verified
touch "${dest}.sha256.verified"
```

---

## 7. MEDIUM: Add Console Launcher to Menu

**File:** `scripts/menu.sh`

**Add this function after line 58:**
```bash
launch_console() {
  local domain="$1"
  
  # Get display URI
  local uri
  uri=$(virsh domdisplay "$domain" 2>/dev/null || echo "")
  
  if [[ -z "$uri" ]]; then
    $DIALOG --msgbox "Error: No display available for VM '$domain'\n\nEnsure VM is running and has graphics enabled." 10 60
    return 1
  fi
  
  # Check if remote-viewer is available
  if ! command -v remote-viewer >/dev/null 2>&1; then
    $DIALOG --msgbox "Error: remote-viewer not found\n\nInstall with: nix-env -iA nixpkgs.virt-viewer" 10 60
    return 1
  fi
  
  # Launch viewer in background
  log "Launching console for $domain (URI: $uri)"
  nohup remote-viewer "$uri" >/dev/null 2>&1 &
  
  $DIALOG --msgbox "Console viewer launched for '$domain'\n\nConnect with: $uri" 10 60
}
```

**Update VM selection menu to include console option:**

Find the section where VM is selected and started, add:
```bash
# After VM selection, show action menu
action=$($DIALOG --menu "VM: $name" 16 60 6 \
  start "Start VM" \
  console "Launch Console (SPICE/VNC)" \
  define "Define/Start from JSON" \
  edit "Edit Profile" \
  delete "Delete VM" \
  back "Back" 3>&1 1>&2 2>&3 || echo "back")

case "$action" in
  start)
    # ... existing start code ...
    ;;
  console)
    # Get domain name from profile
    domain=$(jq -r '.name' "$selected_profile")
    # Check if running
    if virsh domstate "$domain" 2>/dev/null | grep -q "running"; then
      launch_console "$domain"
    else
      $DIALOG --yesno "VM '$domain' is not running.\n\nStart it now?" 10 50
      if [[ $? -eq 0 ]]; then
        virsh start "$domain" && sleep 3 && launch_console "$domain"
      fi
    fi
    ;;
  # ... rest of cases ...
esac
```

---

## 8. LOW: Optimize JSON Parsing

**Multiple Files:** `scripts/*.sh`

**Pattern to Replace:**
```bash
# BEFORE (inefficient - multiple jq calls):
name=$(jq -r '.name' "$PROFILE_JSON")
cpus=$(jq -r '.cpus' "$PROFILE_JSON")
memory_mb=$(jq -r '.memory_mb' "$PROFILE_JSON")
disk_gb=$(jq -r '.disk_gb // 20' "$PROFILE_JSON")
arch=$(jq -r '.arch // "x86_64"' "$PROFILE_JSON")
```

**AFTER (efficient - single jq call):**
```bash
# Read multiple values at once
IFS=$'\t' read -r name cpus memory_mb disk_gb arch < <(
  jq -r '[.name, .cpus, .memory_mb, (.disk_gb // 20), (.arch // "x86_64")] | @tsv' "$PROFILE_JSON"
)
```

---

## 9. LOW: Add Diagnostic Command

**New File:** `scripts/diagnose.sh`

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"
export DIALOG

echo "═══════════════════════════════════════════════════════"
echo "  Hypervisor Diagnostic Report"
echo "═══════════════════════════════════════════════════════"
echo ""

# System info
echo "## System Information"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo ""

# KVM availability
echo "## Virtualization Support"
if [[ -e /dev/kvm ]]; then
  echo "✓ KVM device present: /dev/kvm"
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    echo "✓ KVM device accessible"
  else
    echo "✗ KVM device not accessible (check permissions)"
  fi
else
  echo "✗ KVM device missing"
  echo "  Cause: Virtualization may be disabled in BIOS"
  echo "  Fix: Enable Intel VT-x or AMD-V in BIOS"
fi
echo ""

# IOMMU
echo "## IOMMU Support"
if dmesg | grep -qi iommu 2>/dev/null; then
  echo "✓ IOMMU enabled"
else
  echo "✗ IOMMU not enabled"
  echo "  Fix: Add kernel parameters: intel_iommu=on iommu=pt"
fi
echo ""

# Libvirt
echo "## Libvirt Status"
if systemctl is-active --quiet libvirtd; then
  echo "✓ libvirtd is running"
  echo "  Default network: $(virsh net-info default 2>/dev/null | grep -E '^Active:' || echo 'N/A')"
else
  echo "✗ libvirtd is not running"
  echo "  Fix: systemctl start libvirtd"
fi
echo ""

# Storage
echo "## Storage Space"
df -h /var/lib/hypervisor 2>/dev/null || df -h /var/lib | head -2
echo ""
echo "Disk usage by directory:"
du -sh /var/lib/hypervisor/* 2>/dev/null || echo "No hypervisor directories yet"
echo ""

# Network bridges
echo "## Network Bridges"
if ip link show type bridge >/dev/null 2>&1; then
  ip -br link show type bridge | awk '{print "  " $0}'
else
  echo "  No bridges configured"
  echo "  Fix: Run bridge helper from menu"
fi
echo ""

# VMs
echo "## Virtual Machines"
vm_count=$(ls -1 /var/lib/hypervisor/vm_profiles/*.json 2>/dev/null | wc -l)
echo "Profiles: $vm_count"
running_vms=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
echo "Running: $running_vms"
if [[ $running_vms -gt 0 ]]; then
  echo ""
  virsh list --all
fi
echo ""

# AppArmor
echo "## Security"
if command -v aa-status >/dev/null 2>&1; then
  if aa-status >/dev/null 2>&1; then
    echo "✓ AppArmor is active"
    profiles=$(aa-status | grep -c "profiles are loaded" || echo "0")
    echo "  Profiles loaded: $profiles"
  else
    echo "✗ AppArmor not active"
  fi
else
  echo "✗ AppArmor not available"
fi
echo ""

# Recent errors
echo "## Recent Errors (last 24h)"
if [[ -f /var/lib/hypervisor/logs/menu.log ]]; then
  echo "Menu errors:"
  grep -i error /var/lib/hypervisor/logs/menu.log | tail -5 2>/dev/null || echo "  None"
fi
if journalctl -u libvirtd --since "24 hours ago" >/dev/null 2>&1; then
  echo ""
  echo "Libvirt errors:"
  journalctl -u libvirtd --since "24 hours ago" -p err | tail -5 || echo "  None"
fi
echo ""

echo "═══════════════════════════════════════════════════════"
echo "Diagnostic report complete"
echo "═══════════════════════════════════════════════════════"
```

**Make it executable and add to menu:**
```bash
chmod +x /etc/hypervisor/scripts/diagnose.sh
```

**Add to `scripts/menu.sh` in the More Options menu:**
```bash
    "__DIAGNOSE__" "Run System Diagnostics"
```

And handle it:
```bash
    "__DIAGNOSE__")
      bash "$SCRIPTS_DIR/diagnose.sh" | ${PAGER:-less}
      ;;
```

---

## 10. Documentation: Quick Start Expansion

**File:** `docs/quickstart.txt`

**Current Content:**
```
Hypervisor Quickstart

1) Download OS ISO or cloud image
   - TUI: More Options -> ISO manager (or Cloud image manager)
2) Create a VM profile
   - TUI: More Options -> Create VM (wizard)
   - Choose ISO or cloud image + cloud-init files
3) Deploy and launch
   - TUI: Define/Start from JSON, or end-to-end workflow
4) After install
   - Remove iso_path for faster boots; set autostart if desired
```

**Expanded Content:**
```
═══════════════════════════════════════════════════════════
  Hypervisor Quick Start Guide
═══════════════════════════════════════════════════════════

Complete these steps to create and run your first VM in ~10 minutes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1: Download an OS Installation ISO (3-5 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the boot menu:
  1. Select "More Options"
  2. Choose "ISO Manager"
  3. Select a distribution (e.g., "Ubuntu 24.04 LTS")
  4. Wait for download and automatic GPG verification
  
The ISO will be saved to: /var/lib/hypervisor/isos/

Troubleshooting:
  - Download fails? Check internet: ping 8.8.8.8
  - Slow download? Try a different mirror in ISO presets
  - Verification fails? Check system time: date

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2: Create a VM Profile (2 minutes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the boot menu:
  1. Select "More Options"
  2. Choose "Create VM (wizard)"
  3. Enter VM details:
     - Name: ubuntu-desktop (any name, alphanumeric + . _ -)
     - CPUs: 2 (or more)
     - Memory: 4096 MB (4GB minimum for desktop, 2GB for server)
     - Disk: 20 GB (minimum for Ubuntu)
  4. Select the ISO you downloaded
  5. Choose network: default or bridge
  6. Review and save

The profile will be saved to: /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json

You can edit this file later with: nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3: Start the VM (1 minute)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

From the main menu:
  1. Select your VM (e.g., "VM: ubuntu-desktop")
  2. Choose "Start VM" or "Define/Start from JSON"
  3. Wait for libvirt to start the VM (~10 seconds)

The VM is now running headless.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 4: Connect to the VM Console (1 minute)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Option A: SPICE Viewer (recommended)
  1. Install virt-viewer: nix-env -iA nixpkgs.virt-viewer
  2. Connect: remote-viewer spice://127.0.0.1:$(virsh domdisplay ubuntu-desktop | cut -d: -f4)

Option B: VNC Viewer
  1. Install vncviewer: nix-env -iA nixpkgs.tigervnc
  2. Find port: virsh domdisplay ubuntu-desktop
  3. Connect: vncviewer 127.0.0.1:<port>

Option C: Serial Console (text-only, if configured)
  virsh console ubuntu-desktop

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 5: Install the Guest OS (varies by OS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Follow the OS installer in the SPICE/VNC window.

Tips:
  - Choose "Erase disk and install" (safe, this is a virtual disk)
  - Enable SSH server during install for remote access
  - Install virtio drivers if prompted (for best performance)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 6: After Installation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Remove ISO for faster boots:
   nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json
   # Delete or comment out the "iso_path" line
   # Save with Ctrl+O, exit with Ctrl+X

2. Restart VM:
   virsh destroy ubuntu-desktop
   virsh start ubuntu-desktop

3. Optional: Enable autostart:
   nano /var/lib/hypervisor/vm_profiles/ubuntu-desktop.json
   # Add: "autostart": true
   virsh autostart ubuntu-desktop

4. Get VM IP address:
   virsh domifaddr ubuntu-desktop

5. SSH into VM (if SSH server installed):
   ssh user@<VM-IP>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Common Issues & Solutions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue: VM won't start
  Check: ls /dev/kvm (should exist)
  Check: systemctl status libvirtd (should be active)
  Check: df -h /var/lib/hypervisor (need >20GB free)
  Logs: journalctl -u libvirtd -n 50

Issue: No network in VM
  Check: ip link show br0 (if using bridge)
  Check: virsh net-info default (should be active)
  Fix: virsh net-start default

Issue: Can't connect to console
  Check: virsh domdisplay ubuntu-desktop (should show URI)
  Check: virsh domstate ubuntu-desktop (should be "running")
  Install: nix-env -iA nixpkgs.virt-viewer

Issue: Slow performance
  Enable: hugepages in VM profile
  Enable: CPU pinning for dedicated cores
  Check: htop (look for high CPU steal time)

For more help:
  - Run diagnostics: /etc/hypervisor/scripts/diagnose.sh
  - View logs: tail -f /var/lib/hypervisor/logs/menu.log
  - Read docs: ls /etc/hypervisor/docs/

═══════════════════════════════════════════════════════════
Next Steps
═══════════════════════════════════════════════════════════

Learn more:
  - docs/advanced_features.md - GPU passthrough, CPU pinning, etc.
  - docs/networking.txt - Bridge networking and zones
  - docs/storage.txt - Snapshots and backups
  - docs/workflows.txt - Common VM management workflows

Create more VMs:
  - Repeat steps 1-3 with different ISOs
  - Clone existing VMs with template manager
  - Use cloud images for faster deployment

═══════════════════════════════════════════════════════════
```

**Save this expanded quickstart:**
```bash
cat > /workspace/docs/quickstart_expanded.md << 'EOF'
[paste the expanded content above]
EOF
```

---

## Summary

These fixes address:
- ✅ Critical config generation bug
- ✅ Security issue with password handling  
- ✅ Input validation gaps
- ✅ Log rotation for maintenance
- ✅ Better error messages
- ✅ ISO verification enforcement
- ✅ Console launcher feature
- ✅ Performance optimization (JSON parsing)
- ✅ Diagnostic tool for troubleshooting
- ✅ Improved documentation

**Priority Order:**
1. Fix setup_wizard.sh (CRITICAL - broken config)
2. Add VM name validation (HIGH - security/stability)
3. Fix password input (HIGH - security)
4. Add log rotation (MEDIUM - maintenance)
5. Improve error messages (MEDIUM - UX)
6. Add diagnostic tool (MEDIUM - UX)
7. Add console launcher (LOW - feature)
8. Optimize JSON parsing (LOW - performance)
9. Expand documentation (LOW - education)

Implement these in order, testing each before moving to the next.
