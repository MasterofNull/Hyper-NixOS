#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Help Assistant - Context-aware help and guidance system
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"

# Show main help menu
main_help_menu() {
  while true; do
    local choice
    choice=$($DIALOG --title "Help & Learning" --menu \
"Get help, learn the system, or start a tutorial.\n\n\
Choose by topic or situation:" 24 80 15 \
      "1" "🆕 I'm brand new - where do I start?" \
      "2" "📚 Interactive Tutorial (hands-on learning)" \
      "3" "🔍 Troubleshooting Guide (something's wrong)" \
      "4" "📖 Tool Guide (what each tool does)" \
      "5" "🚀 Quick Start (create first VM in 15 min)" \
      "6" "❓ Common Questions (FAQ)" \
      "7" "🎯 Specific Topics" \
      "8" "📊 Show me examples" \
      "9" "🔧 Command Reference (cheat sheet)" \
      "10" "📺 Visual Guides (with diagrams)" \
      "11" "🎓 Learning Path by Experience" \
      "12" "💡 Pro Tips and Tricks" \
      "13" "⚠️  Common Mistakes to Avoid" \
      "14" "🆘 Emergency Recovery" \
      "15" "Back to Main Menu" \
      3>&1 1>&2 2>&3) || break
    
    case "$choice" in
      1) help_brand_new ;;
      2) /etc/hypervisor/scripts/interactive_tutorial.sh || true ;;
      3) less /etc/hypervisor/docs/TROUBLESHOOTING.md ;;
      4) less /etc/hypervisor/docs/TOOL_GUIDE.md ;;
      5) less /etc/hypervisor/docs/QUICKSTART_EXPANDED.md ;;
      6) help_faq ;;
      7) help_specific_topics ;;
      8) help_examples ;;
      9) less /etc/hypervisor/docs/QUICK_REFERENCE.md ;;
      10) help_visual_guides ;;
      11) help_learning_paths ;;
      12) help_pro_tips ;;
      13) help_common_mistakes ;;
      14) help_emergency ;;
      15|*) break ;;
    esac
  done
}

# Help for brand new users
help_brand_new() {
  $DIALOG --msgbox "🆕 Welcome! Here's your roadmap:\n\n\
STEP 1: Understand Your System (5 min)\n\
  → Run: System Diagnostics\n\
  → Learn: What your hardware can do\n\n\
STEP 2: Download an OS (10 min)\n\
  → Run: ISO Manager\n\
  → Download: Ubuntu or your choice\n\n\
STEP 3: Create a VM (10 min)\n\
  → Run: Create VM Wizard\n\
  → Follow: Step-by-step prompts\n\n\
STEP 4: Start & Connect (5 min)\n\
  → Select VM → Launch Console\n\
  → Install: Your OS\n\n\
STEP 5: Learn More\n\
  → Try: Interactive Tutorial\n\
  → Read: QUICKSTART_EXPANDED.md\n\n\
⏱️  Total time to first VM: ~30 minutes\n\n\
Press OK to return to help menu." 28 70
}

# FAQ
help_faq() {
  while true; do
    local q
    q=$($DIALOG --title "Frequently Asked Questions" --menu "Choose a question:" 24 78 15 \
      "1" "What is a VM (Virtual Machine)?" \
      "2" "Do I need special hardware?" \
      "3" "How many VMs can I run?" \
      "4" "What's the difference between NAT and Bridge?" \
      "5" "Why do I need to verify ISOs?" \
      "6" "Can I run Windows VMs?" \
      "7" "What is VFIO/GPU passthrough?" \
      "8" "How do I backup my VMs?" \
      "9" "Can I move VMs to another computer?" \
      "10" "How do I update the hypervisor?" \
      "11" "Where are my VM files stored?" \
      "12" "What if something breaks?" \
      "13" "How do I get better performance?" \
      "14" "Is this secure?" \
      "15" "Back" \
      3>&1 1>&2 2>&3) || break
    
    case "$q" in
      1)
        $DIALOG --msgbox "What is a VM (Virtual Machine)?\n\n\
A VM is a computer inside your computer!\n\n\
🎓 Think of it like:\n\
  • Your host = Apartment building\n\
  • Each VM = Separate apartment\n\
  • Each has its own OS, apps, files\n\
  • They share the building's resources\n\n\
Benefits:\n\
  ✓ Test software safely (isolated)\n\
  ✓ Run multiple OSes (Linux + Windows)\n\
  ✓ Learning environment (mistakes don't matter)\n\
  ✓ Server consolidation (many servers, one box)\n\n\
Technical:\n\
  • Uses KVM for hardware virtualization\n\
  • Near-native performance (~95% speed)\n\
  • Strong isolation for security" 26 70
        ;;
      2)
        local has_kvm=""
        [[ -c /dev/kvm ]] && has_kvm="✓ Yes! You have it!" || has_kvm="✗ Not available"
        
        $DIALOG --msgbox "Do I need special hardware?\n\n\
For BASIC VMs:\n\
  Required:\n\
    • CPU with virtualization support\n\
      (Intel VT-x or AMD-V)\n\
    • Virtualization enabled in BIOS\n\
  Your system: $has_kvm\n\n\
For ADVANCED features (GPU passthrough):\n\
  Required:\n\
    • IOMMU support (Intel VT-d or AMD-Vi)\n\
    • IOMMU enabled in BIOS\n\
    • Spare GPU (usually)\n\n\
How to check:\n\
  • Run: System Diagnostics\n\
  • Look for: KVM device, IOMMU status\n\n\
Most modern CPUs (2010+) have virtualization!" 26 70
        ;;
      3)
        local total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
        local total_cpus=$(nproc)
        local suggested_vms=$((total_ram_mb / 2048))
        
        $DIALOG --msgbox "How many VMs can I run?\n\n\
Depends on your resources!\n\n\
Your system:\n\
  • CPUs: $total_cpus cores\n\
  • RAM: ${total_ram_mb}MB (~$(( total_ram_mb / 1024 ))GB)\n\n\
Rough estimate:\n\
  • You could run: ~$suggested_vms VMs comfortably\n\
    (assuming 2GB each)\n\n\
Factors that matter:\n\
  • VM workload (server vs desktop)\n\
  • Resource allocation per VM\n\
  • Host overhead (~2-4GB + 1-2 CPUs)\n\n\
Example scenarios:\n\
  • 16GB RAM: 3-4 desktop VMs or 6-8 server VMs\n\
  • 32GB RAM: 6-8 desktop VMs or 12-16 server VMs\n\n\
💡 Best practice:\n\
  • Start with fewer VMs\n\
  • Monitor resource usage\n\
  • Add more as needed" 28 70
        ;;
      4)
        $DIALOG --msgbox "NAT vs Bridge Networking?\n\n\
🏢 NAT (default) = Apartment Building:\n\
  • VMs share one internet connection\n\
  • Private IPs (192.168.122.X)\n\
  • Isolated from your network\n\
  • More secure\n\
  Best for: Testing, development, desktops\n\n\
🏠 Bridge (br0) = Houses on Street:\n\
  • Each VM has own address\n\
  • IPs from your router (192.168.1.X)\n\
  • Accessible from other computers\n\
  • More exposed\n\
  Best for: Servers, services, production\n\n\
💡 Recommendation:\n\
  • New users: Use NAT (simpler, more secure)\n\
  • Servers: Use Bridge (accessible)\n\
  • Can mix: Some VMs on NAT, some on Bridge" 26 70
        ;;
      5)
        $DIALOG --msgbox "Why verify ISOs?\n\n\
🔒 Security reasons:\n\n\
Without verification:\n\
  ✗ Could be corrupted download\n\
  ✗ Could be modified by attacker\n\
  ✗ Could contain malware\n\
  ✗ You wouldn't know!\n\n\
With verification:\n\
  ✓ Checksum proves file integrity\n\
  ✓ GPG signature proves authenticity\n\
  ✓ Matches official source exactly\n\
  ✓ Safe to use\n\n\
This hypervisor:\n\
  • Auto-downloads checksums\n\
  • Auto-verifies after download\n\
  • Marks verified ISOs\n\
  • Prevents using unverified ISOs\n\n\
💡 It's like checking ID:\n\
  You want to know the OS installer is really\n\
  from Ubuntu/Fedora/etc, not an imposter!" 28 70
        ;;
      6)
        $DIALOG --msgbox "Can I run Windows VMs?\n\n\
✓ Yes! Windows VMs work great.\n\n\
Requirements:\n\
  • Windows ISO (download from Microsoft)\n\
  • More resources: 8GB RAM, 4 CPUs, 60GB disk\n\
  • TPM emulation (for Windows 11)\n\n\
Setup:\n\
  1. Download Windows ISO from Microsoft\n\
  2. Create VM with higher resources\n\
  3. Enable TPM in profile: \"tpm\":{\"enable\":true}\n\
  4. Start VM and install Windows\n\n\
Performance tips:\n\
  • Install virtio drivers for best speed\n\
  • Enable CPU pinning for gaming\n\
  • Consider GPU passthrough for games\n\n\
See also:\n\
  • docs/advanced_features.md\n\
  • VM Profile examples" 24 70
        ;;
      15|*) break ;;
    esac
  done
}

# Specific topics
help_specific_topics() {
  local topic
  topic=$($DIALOG --title "Help Topics" --menu "Choose a topic:" 22 70 12 \
    "1" "VM Creation and Management" \
    "2" "Networking" \
    "3" "Storage and Disks" \
    "4" "Performance Tuning" \
    "5" "Security" \
    "6" "Monitoring" \
    "7" "Backup and Recovery" \
    "8" "Troubleshooting" \
    "9" "Advanced Features" \
    "10" "Automation" \
    "11" "Back" \
    3>&1 1>&2 2>&3) || return 0
  
  case "$topic" in
    1) less /etc/hypervisor/docs/TOOL_GUIDE.md ;;
    2) less /etc/hypervisor/docs/networking.txt ;;
    3) less /etc/hypervisor/docs/storage.txt ;;
    4) less /etc/hypervisor/docs/advanced_features.md ;;
    5) less /etc/hypervisor/docs/security_best_practices.md ;;
    6) less /etc/hypervisor/docs/MONITORING_SETUP.md ;;
    7) less /etc/hypervisor/docs/QUICKSTART_EXPANDED.md ;;
    8) less /etc/hypervisor/docs/TROUBLESHOOTING.md ;;
    9) less /etc/hypervisor/docs/advanced_features.md ;;
    10) less /etc/hypervisor/docs/workflows.txt ;;
  esac
}

# Show examples
help_examples() {
  $DIALOG --title "Practical Examples" --menu "Choose a scenario:" 22 78 10 \
    "1" "Example: Create Ubuntu Desktop VM" \
    "2" "Example: Create Windows 11 VM" \
    "3" "Example: Create Web Server" \
    "4" "Example: Set up Development Environment" \
    "5" "Example: Gaming VM with GPU" \
    "6" "Example: Isolated Test Environment" \
    "7" "Example: Daily Backup Routine" \
    "8" "Example: Multi-VM Project Setup" \
    "9" "Back" \
    3>&1 1>&2 2>&3 || return 0
  
  case "$1" in
    1)
      $DIALOG --msgbox "Example: Ubuntu Desktop VM\n\n\
📋 Scenario: Create a VM for daily use\n\n\
Steps:\n\
1. ISO Manager → Download Ubuntu 24.04 Desktop\n\
2. Create VM Wizard:\n\
   Name: ubuntu-desktop\n\
   CPUs: 2\n\
   RAM: 4096 MB\n\
   Disk: 30 GB\n\
   Network: default (NAT)\n\
3. VM Action Menu → Start VM\n\
4. VM Action Menu → Launch Console\n\
5. Install Ubuntu (follow installer)\n\
6. After install:\n\
   • Remove iso_path from profile\n\
   • Restart VM\n\
   • Enable autostart (optional)\n\n\
⏱️  Time: ~30 minutes\n\
💾 Space needed: ~35 GB" 28 70
      ;;
    2)
      $DIALOG --msgbox "Example: Windows 11 VM\n\n\
📋 Scenario: Windows for office apps/gaming\n\n\
Steps:\n\
1. Download Windows 11 ISO from Microsoft\n\
2. Create VM with:\n\
   Name: windows-11\n\
   CPUs: 4\n\
   RAM: 8192 MB (8 GB)\n\
   Disk: 60 GB\n\
3. Edit profile, add:\n\
   \"tpm\": {\"enable\": true}\n\
   (Required for Windows 11)\n\
4. Start VM and install Windows\n\
5. Install virtio drivers in Windows\n\n\
For gaming:\n\
  • Add GPU passthrough (VFIO)\n\
  • Enable CPU pinning\n\
  • Use hugepages\n\n\
See: docs/advanced_features.md" 26 70
      ;;
  esac
}

# Visual guides
help_visual_guides() {
  $DIALOG --msgbox "Visual Guides\n\n\
System Architecture:\n\
┌─────────────────────────────────────┐\n\
│  Host OS (NixOS + Hardened Kernel) │\n\
├─────────────────────────────────────┤\n\
│  Libvirt + QEMU                     │\n\
├─────────────────────────────────────┤\n\
│  ┌────────┐ ┌────────┐ ┌────────┐  │\n\
│  │  VM 1  │ │  VM 2  │ │  VM 3  │  │\n\
│  └────────┘ └────────┘ └────────┘  │\n\
└─────────────────────────────────────┘\n\n\
VM Creation Flow:\n\
ISO → Profile → Start → Console → Install\n\
 ↓      ↓         ↓        ↓         ↓\n\
.iso  .json     XML    SPICE/VNC   OS\n\n\
For more diagrams, see documentation." 24 70
}

# Learning paths
help_learning_paths() {
  $DIALOG --title "Learning Paths" --menu "Choose your level:" 18 70 4 \
    "1" "New User Path (Start here!)" \
    "2" "Intermediate User Path" \
    "3" "Advanced User Path" \
    "4" "Back" \
    3>&1 1>&2 2>&3 || return 0
  
  case "$1" in
    1)
      $DIALOG --msgbox "New User Learning Path\n\n\
Week 1: Basics\n\
  □ Run System Diagnostics\n\
  □ Complete Interactive Tutorial Lessons 1-5\n\
  □ Create and use first VM\n\
  □ Practice start/stop operations\n\n\
Week 2: Daily Operations\n\
  □ Learn VM Dashboard\n\
  □ Practice with different OSes\n\
  □ Create snapshots\n\
  □ Learn troubleshooting basics\n\n\
Week 3: Confidence Building\n\
  □ Create multiple VMs\n\
  □ Try bulk operations\n\
  □ Set up monitoring\n\
  □ Explore advanced features\n\n\
⏱️  3 weeks to proficiency!" 26 70
      ;;
    2)
      $DIALOG --msgbox "Intermediate User Path\n\n\
You know the basics, now optimize:\n\n\
□ Performance tuning (CPU pinning, hugepages)\n\
□ Advanced networking (bridges, zones)\n\
□ Automation (bulk ops, scripts)\n\
□ Monitoring setup (Prometheus, Grafana)\n\
□ Backup strategies\n\
□ Security hardening\n\n\
Skills to develop:\n\
  • Resource optimization\n\
  • Network design\n\
  • Automation scripting\n\
  • Monitoring and alerting\n\n\
⏱️  1-2 months to expert level" 26 70
      ;;
  esac
}

# Pro tips
help_pro_tips() {
  $DIALOG --msgbox "💡 Pro Tips and Tricks\n\n\
EFFICIENCY:\n\
  • Use Bulk Operations for multiple VMs\n\
  • Clone VMs instead of creating from scratch\n\
  • Keep templates for common setups\n\n\
PERFORMANCE:\n\
  • Remove ISO after install (faster boot)\n\
  • Enable hugepages for memory-heavy VMs\n\
  • Use CPU pinning for dedicated workloads\n\
  • Virtio drivers = best performance\n\n\
TROUBLESHOOTING:\n\
  • System Diagnostics = first step always\n\
  • Check logs: tail -f /var/log/libvirt/qemu/\n\
  • VM Dashboard shows issues quickly\n\n\
ORGANIZATION:\n\
  • Use descriptive VM names\n\
  • Tag VMs by project/purpose\n\
  • Keep ISO library organized\n\
  • Snapshot before major changes" 28 70
}

# Common mistakes
help_common_mistakes() {
  $DIALOG --msgbox "⚠️  Common Mistakes to Avoid\n\n\
VM CREATION:\n\
  ✗ Too little RAM (OS won't run well)\n\
  ✗ Forgetting to download ISO first\n\
  ✗ Using invalid VM name characters\n\
  ✓ Follow wizard recommendations\n\n\
OPERATIONS:\n\
  ✗ Force stop instead of graceful shutdown\n\
  ✗ Not waiting for shutdown to complete\n\
  ✗ Deleting VM without backup\n\
  ✓ Always try graceful operations first\n\n\
PERFORMANCE:\n\
  ✗ Allocating all RAM to VMs\n\
  ✗ Not installing guest tools/drivers\n\
  ✗ Keeping ISO mounted after install\n\
  ✓ Leave resources for host, optimize VMs\n\n\
TROUBLESHOOTING:\n\
  ✗ Asking for help before running diagnostics\n\
  ✗ Not checking documentation\n\
  ✓ Diagnostics → Docs → Ask for help" 28 70
}

# Emergency recovery
help_emergency() {
  $DIALOG --msgbox "🆘 Emergency Recovery Procedures\n\n\
VM Won't Start:\n\
  1. Run: System Diagnostics\n\
  2. Check: KVM, libvirtd, disk space\n\
  3. See: TROUBLESHOOTING.md\n\n\
VM Crashed:\n\
  1. Force stop: virsh destroy VM-NAME\n\
  2. Check logs: journalctl -u libvirtd -n 100\n\
  3. Try start again\n\
  4. If fails: Restore from snapshot\n\n\
System Won't Boot:\n\
  1. Boot from NixOS live USB\n\
  2. Rollback: nixos-rebuild --rollback boot\n\
  3. Reboot\n\n\
Lost Data:\n\
  1. Check snapshots: virsh snapshot-list VM\n\
  2. Restore: virsh snapshot-revert VM NAME\n\
  3. Check backups in /var/lib/hypervisor/backups/\n\n\
Complete Reset:\n\
  See: TROUBLESHOOTING.md → Reset to Clean State" 28 70
}

# Main
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Help Assistant - Context-aware help and guidance"
  echo ""
  echo "Usage: $0 [TOPIC]"
  echo ""
  echo "Interactive help system covering:"
  echo "  • Getting started guides"
  echo "  • Interactive tutorials"
  echo "  • Troubleshooting"
  echo "  • FAQs"
  echo "  • Examples"
  echo "  • Learning paths"
  echo ""
  echo "Access from menu:"
  echo "  More Options → Help & Learning Center"
  exit 0
fi

main_help_menu
