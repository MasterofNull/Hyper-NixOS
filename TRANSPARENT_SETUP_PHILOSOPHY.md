# Transparent Setup Philosophy - Learn While You Build

**Core Principle:** "Every setup step is an opportunity to educate. Users should understand what they're doing, why they're doing it, and what impact their choices have."

---

## 🎓 Philosophy: Education Through Action

### The Goal
Users should finish setup not just with a working system, but with:
- ✅ Understanding of what was configured
- ✅ Knowledge of why each setting matters
- ✅ Ability to adjust settings later
- ✅ Confidence to troubleshoot issues
- ✅ Mental model of how the system works

### The Anti-Pattern
❌ "Click next until done" - Users complete setup but don't understand what happened  
❌ "Just works™" - Magic that users can't control or troubleshoot  
❌ Hidden complexity - Important details buried in documentation  

### The Pattern We Want
✅ **Transparent** - Show what's happening at each step  
✅ **Educational** - Explain why choices matter  
✅ **Empowering** - Give users control with understanding  
✅ **Progressive** - Start simple, reveal complexity as needed  

---

## 🛠️ Implementation Principles

### 1. Show, Don't Just Do

**Bad:**
```bash
echo "Configuring network..."
# (black box operations)
echo "Done!"
```

**Good:**
```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuring Network"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What we're doing:"
echo "  • Creating NAT network 'default'"
echo "  • Assigning subnet: 192.168.122.0/24"
echo "  • Enabling DHCP server"
echo "  • Configuring forwarding to your internet connection"
echo ""
echo "Why this matters:"
echo "  • VMs will get IPs automatically (192.168.122.2-254)"
echo "  • VMs can access internet through host"
echo "  • VMs are isolated from your local network (more secure)"
echo ""
echo "Working..."
virsh net-define /etc/libvirt/qemu/networks/default.xml
virsh net-start default
virsh net-autostart default
echo ""
echo "✓ Network configured successfully"
echo ""
echo "What you can do now:"
echo "  • Check network: virsh net-info default"
echo "  • See DHCP leases: virsh net-dhcp-leases default"
echo "  • View configuration: virsh net-dumpxml default"
```

### 2. Explain Every Choice

**Bad:**
```bash
$DIALOG --yesno "Enable hugepages?" 8 40
```

**Good:**
```bash
$DIALOG --yesno "Enable Hugepages?\n\n\
What are hugepages?\n\
  Hugepages are larger memory pages (2MB vs 4KB) that can\n\
  improve VM performance, especially for memory-intensive workloads.\n\n\
Benefits:\n\
  ✓ Better performance for large memory VMs\n\
  ✓ Reduced memory overhead\n\
  ✓ Lower CPU usage for memory management\n\n\
Trade-offs:\n\
  • Uses reserved memory (not available for other programs)\n\
  • Reduces flexibility of memory allocation\n\
  • Best for dedicated virtualization hosts\n\n\
Recommended for:\n\
  ✓ Servers running multiple VMs\n\
  ✓ VMs with 4GB+ memory\n\
  ✓ Systems with 16GB+ total RAM\n\n\
Not recommended for:\n\
  • Desktop systems with limited RAM\n\
  • Single VM setups\n\
  • Systems where you need memory flexibility\n\n\
Enable hugepages? [Current: disabled]" 25 78
```

### 3. Preview Before Applying

**Bad:**
```bash
# Just applies settings
echo "Applying configuration..."
apply_settings
```

**Good:**
```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuration Preview"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "We will apply these settings:"
echo ""
echo "Security:"
echo "  • Strict firewall: $STRICT_FIREWALL (blocks all except SSH and VM traffic)"
echo "  • Migration TCP: $MIGRATION_TCP (allows live VM migration)"
echo "  • AppArmor: enabled (confines QEMU processes)"
echo ""
echo "Performance:"
echo "  • Hugepages: $HUGEPAGES (reserves ${HUGEPAGE_SIZE}MB for VMs)"
echo "  • SMT: $SMT_STATUS (hyperthreading)"
echo ""
echo "Files that will be created:"
echo "  • /etc/hypervisor/configuration/security-local.nix"
echo "  • /etc/hypervisor/configuration/perf-local.nix"
echo ""
echo "What happens next:"
echo "  1. Configuration files will be written"
echo "  2. System will rebuild (may take 2-5 minutes)"
echo "  3. Changes take effect on next boot (or reboot now)"
echo ""
read -p "Continue with these settings? [Y/n]: " confirm
```

### 4. Teach As You Go

**Bad:**
```bash
# Silent progress
create_vm_disk "$disk_path" "$size"
```

**Good:**
```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating Virtual Disk"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 About VM Disks:"
echo "  Virtual machines use disk image files instead of physical disks."
echo "  We use qcow2 format because:"
echo "    • Takes only the space actually used (grows as needed)"
echo "    • Supports snapshots for backup/restore"
echo "    • Better performance than raw images"
echo ""
echo "Creating disk image:"
echo "  Path: $disk_path"
echo "  Format: qcow2 (QEMU Copy-On-Write v2)"
echo "  Maximum size: ${size}GB"
echo "  Initial size: ~200KB (grows with data)"
echo ""
echo "Creating disk image..."
if qemu-img create -f qcow2 "$disk_path" "${size}G"; then
  actual_size=$(du -h "$disk_path" | awk '{print $1}')
  echo "✓ Disk created successfully"
  echo ""
  echo "Current disk size: $actual_size (will grow as VM writes data)"
  echo "Maximum disk size: ${size}GB"
  echo ""
  echo "💡 Tip: The VM sees a ${size}GB disk, but it only uses space"
  echo "   on your host as files are written."
else
  echo "✗ Failed to create disk"
  echo ""
  echo "Troubleshooting:"
  echo "  • Check available space: df -h $(dirname "$disk_path")"
  echo "  • Check permissions: ls -ld $(dirname "$disk_path")"
fi
```

---

## 🎨 Transparency Patterns

### Pattern 1: "What → Why → How → Result"

```bash
setup_feature() {
  local feature_name=$1
  
  # WHAT: Describe the feature
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Setting up: $feature_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "What this is:"
  echo "  [Clear description of the feature]"
  echo ""
  
  # WHY: Explain the purpose
  echo "Why it's useful:"
  echo "  • [Benefit 1]"
  echo "  • [Benefit 2]"
  echo "  • [Benefit 3]"
  echo ""
  
  # HOW: Show what will happen
  echo "What we'll do:"
  echo "  1. [Step 1]"
  echo "  2. [Step 2]"
  echo "  3. [Step 3]"
  echo ""
  
  # Execute with feedback
  echo "Working..."
  do_the_actual_work
  
  # RESULT: Show outcome
  echo ""
  echo "✓ $feature_name configured"
  echo ""
  echo "Result:"
  echo "  • [What changed]"
  echo "  • [Where to find it]"
  echo "  • [How to verify]"
  echo ""
  echo "Next steps:"
  echo "  • [What user can do now]"
  echo ""
}
```

### Pattern 2: "Teach by Analogy"

```bash
explain_networking() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "VM Networking Explained"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Think of networking like buildings and roads:"
  echo ""
  echo "NAT Network (default):"
  echo "  🏢 VMs are like apartments in a building"
  echo "  🚪 They share one internet connection (the building's main door)"
  echo "  🔒 People outside can't directly reach apartments (secure)"
  echo "  ✓ Good for: Testing, development, desktop VMs"
  echo ""
  echo "Bridge Network:"
  echo "  🏠 VMs are like individual houses on a street"
  echo "  🚪 Each has its own front door (IP on your network)"
  echo "  👥 Anyone on the street can visit (accessible)"
  echo "  ✓ Good for: Servers, shared services, production"
  echo ""
  echo "Which would you like to use?"
}
```

### Pattern 3: "Show the Impact"

```bash
explain_choice_impact() {
  local choice=$1
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Impact of Your Choice"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "You chose: $choice"
  echo ""
  echo "This means:"
  echo ""
  echo "Immediately:"
  echo "  • [What happens right now]"
  echo ""
  echo "When you create VMs:"
  echo "  • [How it affects VM behavior]"
  echo ""
  echo "For security:"
  echo "  • [Security implications]"
  echo ""
  echo "For performance:"
  echo "  • [Performance implications]"
  echo ""
  echo "Files affected:"
  echo "  • [Config files that will change]"
  echo ""
  echo "You can change this later by:"
  echo "  • [How to modify the setting]"
  echo ""
}
```

### Pattern 4: "Guided Discovery"

```bash
interactive_learning() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Let's Check Your System"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Let's see what your system can do..."
  echo ""
  
  # Discover and explain as you go
  total_cpus=$(nproc)
  echo "CPU Cores: $total_cpus"
  echo "  What this means: You can run VMs with up to $total_cpus virtual CPUs"
  echo "  Recommendation: Leave 1-2 cores for the host system"
  echo "  So for VMs: Use $(( total_cpus - 2 )) or fewer vCPUs"
  echo ""
  
  total_ram=$(free -m | awk '/^Mem:/{print $2}')
  echo "Total RAM: ${total_ram}MB ($(( total_ram / 1024 ))GB)"
  echo "  What this means: This is shared between host and VMs"
  echo "  Recommendation: Allocate 50-70% to VMs, rest for host"
  echo "  Available for VMs: ~$(( total_ram * 6 / 10 ))MB"
  echo ""
  
  if [[ -c /dev/kvm ]]; then
    echo "Virtualization: ✓ Enabled (KVM available)"
    echo "  What this means: VMs will run at near-native speed"
    echo "  Technology: Hardware virtualization (Intel VT-x or AMD-V)"
  else
    echo "Virtualization: ✗ Not available"
    echo "  What this means: VMs will run slowly (software emulation)"
    echo "  How to fix: Enable VT-x/AMD-V in BIOS/UEFI"
  fi
  echo ""
  
  # Let them process the information
  echo "💡 Understanding your system helps you make better choices!"
  echo ""
  read -p "Press Enter to continue..."
}
```

---

## 📝 Enhanced Setup Wizard Example

Here's how the setup wizard should work with full transparency:

```bash
#!/usr/bin/env bash
# Enhanced, educational setup wizard

echo "═══════════════════════════════════════════════════════════════"
echo "  Hypervisor Setup Wizard"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Welcome! This wizard will guide you through setting up your"
echo "virtualization environment. We'll explain each step so you"
echo "understand what's happening and why."
echo ""
echo "What we'll cover:"
echo "  1. System check (verify your hardware)"
echo "  2. Network setup (how VMs connect)"
echo "  3. Storage setup (where VM disks live)"
echo "  4. Security options (protect your system)"
echo "  5. Performance tuning (optimize for your use case)"
echo ""
echo "Time required: ~5-10 minutes"
echo ""
read -p "Ready to begin? [Y/n]: " ready

# ═══════════════════════════════════════════════════════════════
# Step 1: System Discovery (Teach about the system)
# ═══════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1 of 5: System Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Let's check what your system can do for virtualization."
echo ""

# CPU Check with explanation
echo "🔍 Checking CPU..."
total_cpus=$(nproc)
echo "  Found: $total_cpus CPU cores"
echo ""
echo "  📚 What this means:"
echo "    • Each VM needs 1+ virtual CPUs (vCPUs)"
echo "    • More vCPUs = VM can do more parallel work"
echo "    • But: Leave some cores for the host (your OS)"
echo ""
echo "  💡 Recommendation for your system:"
echo "    • Available for VMs: $(( total_cpus - 2 )) vCPUs"
echo "    • Reserved for host: 2 vCPUs"
echo "    • Example: You could run 2 VMs with 2 vCPUs each"
echo ""

# RAM Check with explanation
echo "🔍 Checking Memory..."
total_ram=$(free -m | awk '/^Mem:/{print $2}')
available_ram=$(free -m | awk '/^Mem:/{print $7}')
echo "  Total RAM: ${total_ram}MB ($(( total_ram / 1024 ))GB)"
echo "  Currently available: ${available_ram}MB"
echo ""
echo "  📚 What this means:"
echo "    • VMs need memory allocation (like programs do)"
echo "    • More memory = VMs can do more (and run faster)"
echo "    • But: Host needs memory too"
echo ""
echo "  💡 Recommendation for your system:"
echo "    • Safe to allocate to VMs: $(( available_ram * 7 / 10 ))MB"
echo "    • Leave for host: $(( available_ram * 3 / 10 ))MB"
echo "    • Example: You could run 2 VMs with $(( available_ram * 35 / 100 ))MB each"
echo ""

# Virtualization Check with explanation
echo "🔍 Checking Hardware Virtualization..."
if [[ -c /dev/kvm ]]; then
  echo "  Status: ✓ Enabled (KVM available)"
  echo ""
  echo "  📚 What this means:"
  echo "    • Your CPU has virtualization support (Intel VT-x or AMD-V)"
  echo "    • It's enabled in BIOS/UEFI"
  echo "    • VMs will run at ~95% native speed (very fast!)"
  echo "    • Uses hardware acceleration for better performance"
  echo ""
  echo "  ✓ Great! Your system is ready for virtualization."
else
  echo "  Status: ✗ Not available"
  echo ""
  echo "  📚 What this means:"
  echo "    • Either your CPU doesn't support virtualization, or"
  echo "    • It's disabled in BIOS/UEFI settings"
  echo "    • VMs will run slowly (~10x slower than native)"
  echo ""
  echo "  ⚠ To fix (if your CPU supports it):"
  echo "    1. Reboot your computer"
  echo "    2. Enter BIOS/UEFI setup (usually Del, F2, or F12 at boot)"
  echo "    3. Find 'Virtualization Technology' or 'VT-x' or 'AMD-V'"
  echo "    4. Enable it"
  echo "    5. Save and reboot"
  echo ""
  read -p "Continue anyway (not recommended)? [y/N]: " continue_anyway
  [[ "$continue_anyway" =~ ^[Yy]$ ]] || exit 1
fi
echo ""

# IOMMU Check with explanation
echo "🔍 Checking IOMMU (for advanced features)..."
if dmesg | grep -qi 'iommu.*enabled'; then
  echo "  Status: ✓ Enabled"
  echo ""
  echo "  📚 What this means:"
  echo "    • IOMMU is a hardware feature for device isolation"
  echo "    • Allows GPU passthrough (giving VM direct GPU access)"
  echo "    • Enables advanced security features"
  echo "    • Not required for basic VMs, but unlocks advanced features"
  echo ""
  echo "  ✓ Great! You can use GPU passthrough and advanced features."
else
  echo "  Status: Not enabled (okay for basic use)"
  echo ""
  echo "  📚 What this means:"
  echo "    • Regular VMs will work fine"
  echo "    • But you can't do GPU passthrough (giving VM direct GPU)"
  echo "    • Not needed unless you want high-performance graphics in VMs"
  echo ""
  echo "  💡 To enable later (for GPU passthrough):"
  echo "    Add to configuration.nix:"
  echo "      boot.kernelParams = [ \"intel_iommu=on\" \"iommu=pt\" ];"
  echo "    (Use amd_iommu=on for AMD CPUs)"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "System Check Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary of your system:"
echo "  • CPUs for VMs: $(( total_cpus - 2 ))"
echo "  • RAM for VMs: ~$(( available_ram * 7 / 10 ))MB"
echo "  • Virtualization: $( [[ -c /dev/kvm ]] && echo "✓ Ready" || echo "✗ Not ready" )"
echo "  • Advanced features: $( dmesg | grep -qi 'iommu.*enabled' && echo "✓ Available" || echo "Basic only" )"
echo ""
read -p "Press Enter to continue to network setup..."

# ═══════════════════════════════════════════════════════════════
# Step 2: Network Setup (Teach about networking)
# ═══════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2 of 5: Network Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "VMs need network access. Let's understand your options:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Option 1: NAT Network (Recommended for most users)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🏢 Think of this like apartments in a building:"
echo "  • All VMs share the building's internet connection"
echo "  • VMs get private IPs (like apartment numbers)"
echo "  • People outside can't directly visit (secure)"
echo "  • VMs can browse internet and talk to each other"
echo ""
echo "Technical details:"
echo "  • VMs get IPs like 192.168.122.X"
echo "  • Host acts as router/gateway"
echo "  • Automatic DHCP (IP assignment)"
echo "  • Firewall protected by default"
echo ""
echo "Best for:"
echo "  ✓ Desktop VMs (browsing, development)"
echo "  ✓ Testing and learning"
echo "  ✓ When security is important"
echo "  ✓ Laptops (no network configuration needed)"
echo ""
echo "Not ideal for:"
echo "  • Running servers that others need to access"
echo "  • When you need VMs on your local network"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Option 2: Bridge Network (For servers)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🏠 Think of this like houses on a street:"
echo "  • Each VM gets its own address on your network"
echo "  • Anyone on your network can reach them"
echo "  • VMs appear as separate computers"
echo "  • Direct access from other devices"
echo ""
echo "Technical details:"
echo "  • VMs get IPs from your router (like 192.168.1.X)"
echo "  • Appears on network like physical computers"
echo "  • Requires bridging host network interface"
echo "  • More exposed (consider firewall)"
echo ""
echo "Best for:"
echo "  ✓ Web servers"
echo "  ✓ File servers"
echo "  ✓ Services others need to access"
echo "  ✓ Production environments"
echo ""
echo "Not ideal for:"
echo "  • Laptops (breaks when you change networks)"
echo "  • When you want isolation"
echo "  • Testing/development"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get user choice with defaults
read -p "Which type of network? [1=NAT (recommended), 2=Bridge]: " network_choice
network_choice=${network_choice:-1}

if [[ "$network_choice" == "1" ]]; then
  echo ""
  echo "You chose: NAT Network"
  echo ""
  echo "Setting up default NAT network..."
  echo ""
  echo "What we're doing:"
  echo "  1. Creating virtual network called 'default'"
  echo "  2. Assigning network range: 192.168.122.0/24"
  echo "     (This means IPs from 192.168.122.1 to 192.168.122.254)"
  echo "  3. Starting DHCP server (assigns IPs automatically)"
  echo "  4. Enabling NAT (forwards internet traffic)"
  echo "  5. Setting to auto-start on boot"
  echo ""
  
  if virsh net-info default &>/dev/null; then
    echo "Network 'default' already exists, ensuring it's started..."
    virsh net-start default 2>/dev/null || echo "  (already started)"
    virsh net-autostart default 2>/dev/null
  else
    echo "Creating network..."
    virsh net-define /etc/libvirt/qemu/networks/default.xml
    virsh net-start default
    virsh net-autostart default
  fi
  
  echo ""
  echo "✓ NAT network configured"
  echo ""
  echo "What this means for your VMs:"
  echo "  • VMs will automatically get IPs like 192.168.122.X"
  echo "  • They can access the internet"
  echo "  • They can talk to each other"
  echo "  • They're protected by host firewall"
  echo ""
  echo "To use this network in a VM:"
  echo "  • In VM profile, set: \"network\": { \"bridge\": \"default\" }"
  echo "  • Or leave unspecified (default is used automatically)"
  echo ""
  echo "To check network later:"
  echo "  • View info: virsh net-info default"
  echo "  • See VMs using it: virsh net-dhcp-leases default"
  echo ""
  
else
  echo ""
  echo "You chose: Bridge Network"
  echo ""
  echo "⚠️  Important: Bridge networking requires network configuration"
  echo ""
  echo "What we'll do:"
  echo "  1. Detect your active network interface"
  echo "  2. Create a bridge (br0)"
  echo "  3. Move your IP from the interface to the bridge"
  echo "  4. Your host will continue to work normally"
  echo "  5. VMs can use the bridge to get IPs from your router"
  echo ""
  echo "Impact on your system:"
  echo "  • Brief network interruption during setup (~5 seconds)"
  echo "  • Your host's IP won't change"
  echo "  • Network will work the same for you"
  echo "  • But VMs will appear as separate devices on your network"
  echo ""
  
  read -p "Continue with bridge setup? [Y/n]: " continue_bridge
  if [[ ! "$continue_bridge" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Setting up bridge network..."
    /etc/hypervisor/scripts/bridge_helper.sh || {
      echo ""
      echo "⚠️  Bridge setup failed or was cancelled"
      echo "   Falling back to NAT network..."
      echo ""
      network_choice=1
      # Setup default network as fallback
      virsh net-start default 2>/dev/null || true
      virsh net-autostart default 2>/dev/null || true
    }
  else
    echo "Skipping bridge setup, using NAT instead..."
    network_choice=1
    virsh net-start default 2>/dev/null || true
    virsh net-autostart default 2>/dev/null || true
  fi
fi

echo ""
read -p "Press Enter to continue to storage setup..."

# Continue with more steps...
# Each following the same pattern:
# - Explain what it is
# - Why it matters
# - Show options with pros/cons
# - Preview what will happen
# - Execute with feedback
# - Summarize result and next steps

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Setup Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "🎉 Congratulations! Your hypervisor is configured."
echo ""
echo "What we set up:"
echo "  ✓ System checked and optimized"
echo "  ✓ Network configured ($network_type)"
echo "  ✓ Storage ready at /var/lib/hypervisor"
echo "  ✓ Security settings applied"
echo "  ✓ Performance optimized for your hardware"
echo ""
echo "What you learned:"
echo "  • How virtualization works on your system"
echo "  • Network options and their trade-offs"
echo "  • Storage management for VMs"
echo "  • Security and performance settings"
echo ""
echo "Next steps:"
echo "  1. Download an OS ISO (Menu → More Options → ISO Manager)"
echo "  2. Create your first VM (Menu → More Options → Create VM)"
echo "  3. Start the VM (Menu → Select VM → Start)"
echo "  4. Connect to console (VM Menu → Launch Console)"
echo ""
echo "Need help?"
echo "  • Quickstart guide: /etc/hypervisor/docs/QUICKSTART_EXPANDED.md"
echo "  • Troubleshooting: /etc/hypervisor/docs/TROUBLESHOOTING.md"
echo "  • Run diagnostics: /etc/hypervisor/scripts/diagnose.sh"
echo ""
echo "📚 Remember: You can always run this wizard again to change settings."
echo ""
```

---

## 🎯 Key Principles Summary

### 1. **Transparency**
- Show exactly what's happening
- Explain why it's happening
- Preview before executing
- Confirm after completion

### 2. **Education**
- Teach concepts as they're used
- Use analogies and real-world examples
- Explain technical terms
- Build mental models

### 3. **Context**
- Show how choices affect the system
- Explain trade-offs clearly
- Relate to user's use case
- Provide recommendations with reasoning

### 4. **Empowerment**
- Give users control with understanding
- Show how to verify results
- Teach how to troubleshoot
- Explain how to change settings later

### 5. **Progressive Disclosure**
- Start with simple explanations
- Provide "learn more" options
- Don't overwhelm with details
- Reveal complexity as needed

---

## ✅ Implementation Checklist

To make setup truly transparent and educational:

- [ ] **Every wizard step explains** what, why, and how
- [ ] **Every choice shows impact** on system behavior
- [ ] **Every operation previews** what will happen
- [ ] **Every result summarizes** what changed
- [ ] **Every feature teaches** the underlying concept
- [ ] **Every error educates** on what went wrong
- [ ] **Every setting explains** when to use it
- [ ] **Every success guides** to next steps

---

## 🎓 The Outcome

After completing setup, users should be able to:

✅ **Understand their system**
- Know their hardware capabilities
- Understand resource allocation
- Grasp virtualization basics

✅ **Make informed choices**
- Choose appropriate settings
- Understand trade-offs
- Adjust for their use case

✅ **Troubleshoot issues**
- Know where to look
- Understand error messages
- Fix common problems

✅ **Grow their knowledge**
- Build on what they learned
- Explore advanced features
- Help others learn

---

**Philosophy in Action:**
> "The best setup wizard doesn't just set things up - it teaches users to be confident, capable system administrators of their own virtualization environment."

---

**Status:** Guide complete - Ready for implementation  
**Next:** Enhance existing wizards with these patterns  
**Impact:** Users finish setup understanding their system, not just having a working system
