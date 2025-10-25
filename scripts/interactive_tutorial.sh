#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Interactive Tutorial - Learn the hypervisor through guided exercises
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

: "${DIALOG:=whiptail}"

# Tutorial state tracking
TUTORIAL_STATE="/var/lib/hypervisor/.tutorial_progress"
mkdir -p "$(dirname "$TUTORIAL_STATE")"

# Colors for terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Track completed lessons
mark_complete() {
  local lesson="$1"
  echo "$lesson:$(date -Iseconds)" >> "$TUTORIAL_STATE"
}

is_complete() {
  local lesson="$1"
  grep -q "^$lesson:" "$TUTORIAL_STATE" 2>/dev/null
}

# Show progress
show_progress() {
  local total=10
  local completed=$(wc -l < "$TUTORIAL_STATE" 2>/dev/null || echo 0)
  local percent=$((completed * 100 / total))
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Tutorial Progress: $completed/$total lessons ($percent%)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main menu
tutorial_menu() {
  while true; do
    local choice
    choice=$($DIALOG --title "Interactive Tutorial" --menu \
"Learn the hypervisor hands-on through guided exercises.\n\n\
$(show_progress)" 24 78 12 \
      "1" "$(is_complete lesson1 && echo "✓" || echo " ") Lesson 1: Understanding Your System (10 min)" \
      "2" "$(is_complete lesson2 && echo "✓" || echo " ") Lesson 2: Downloading Your First ISO (15 min)" \
      "3" "$(is_complete lesson3 && echo "✓" || echo " ") Lesson 3: Creating Your First VM (15 min)" \
      "4" "$(is_complete lesson4 && echo "✓" || echo " ") Lesson 4: Starting and Connecting (10 min)" \
      "5" "$(is_complete lesson5 && echo "✓" || echo " ") Lesson 5: VM Lifecycle Management (15 min)" \
      "6" "$(is_complete lesson6 && echo "✓" || echo " ") Lesson 6: Network Configuration (20 min)" \
      "7" "$(is_complete lesson7 && echo "✓" || echo " ") Lesson 7: Snapshots and Backups (15 min)" \
      "8" "$(is_complete lesson8 && echo "✓" || echo " ") Lesson 8: Monitoring and Troubleshooting (20 min)" \
      "9" "$(is_complete lesson9 && echo "✓" || echo " ") Lesson 9: Bulk Operations (10 min)" \
      "10" "$(is_complete lesson10 && echo "✓" || echo " ") Lesson 10: Advanced Features (20 min)" \
      "R" "Reset progress" \
      "Q" "Quit" \
      3>&1 1>&2 2>&3) || break
    
    case "$choice" in
      1) lesson1_understand_system ;;
      2) lesson2_download_iso ;;
      3) lesson3_create_vm ;;
      4) lesson4_start_connect ;;
      5) lesson5_lifecycle ;;
      6) lesson6_networking ;;
      7) lesson7_snapshots ;;
      8) lesson8_monitoring ;;
      9) lesson9_bulk_ops ;;
      10) lesson10_advanced ;;
      R)
        if $DIALOG --yesno "Reset all tutorial progress?" 8 50; then
          rm -f "$TUTORIAL_STATE"
          $DIALOG --msgbox "Progress reset. Start fresh!" 8 40
        fi
        ;;
      Q|*) break ;;
    esac
  done
}

# Lesson 1: Understanding Your System
lesson1_understand_system() {
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Lesson 1: Understanding Your System${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}📚 What you'll learn:${NC}"
  echo "  • How to check your hardware capabilities"
  echo "  • What virtualization means for your system"
  echo "  • How to read system diagnostics"
  echo "  • Resource planning for VMs"
  echo ""
  read -p "Press Enter to begin..."
  
  clear
  echo -e "${BOLD}Step 1: Let's Check Your Hardware${NC}"
  echo ""
  echo "First, let's see what your system has available for virtualization."
  echo ""
  echo -e "${YELLOW}📝 Exercise: Run the diagnostic tool${NC}"
  echo ""
  echo "Command to run:"
  echo -e "  ${GREEN}/etc/hypervisor/scripts/diagnose.sh | less${NC}"
  echo ""
  read -p "Ready to run it? Press Enter..."
  
  /etc/hypervisor/scripts/diagnose.sh | less
  
  clear
  echo -e "${BOLD}Step 2: Understanding the Output${NC}"
  echo ""
  echo "You just saw a comprehensive health check. Let's decode what it means:"
  echo ""
  echo -e "${BOLD}Section 1: Virtualization Support${NC}"
  
  if [[ -c /dev/kvm ]]; then
    echo -e "  ${GREEN}✓${NC} You have KVM available"
    echo -e "  ${BLUE}→ This means:${NC} Your CPU supports hardware virtualization"
    echo -e "  ${BLUE}→ Benefit:${NC} VMs run at ~95% native speed (very fast!)"
  else
    echo -e "  ${YELLOW}⚠${NC} KVM not available"
    echo -e "  ${BLUE}→ This means:${NC} Virtualization disabled in BIOS or not supported"
    echo -e "  ${BLUE}→ Impact:${NC} VMs will be slow (software emulation)"
    echo -e "  ${BLUE}→ To fix:${NC} Enable VT-x or AMD-V in BIOS/UEFI"
  fi
  echo ""
  
  echo -e "${BOLD}Section 2: Resources Available${NC}"
  local total_cpus=$(nproc)
  local total_ram=$(free -h | awk '/^Mem:/{print $2}')
  echo "  CPUs: $total_cpus cores"
  echo -e "  ${BLUE}→ For VMs:${NC} Recommended to use $(( total_cpus - 2 )) or fewer"
  echo -e "  ${BLUE}→ Why:${NC} Leave some for host system"
  echo ""
  echo "  RAM: $total_ram total"
  echo -e "  ${BLUE}→ For VMs:${NC} Safe to allocate 50-70% to VMs"
  echo -e "  ${BLUE}→ Why:${NC} Host needs memory too"
  echo ""
  
  read -p "Press Enter to continue..."
  
  clear
  echo -e "${BOLD}Step 3: Quiz - Test Your Understanding${NC}"
  echo ""
  
  # Quiz questions
  echo -e "${YELLOW}Q1: What does KVM stand for?${NC}"
  echo "  a) Kernel Virtual Machine"
  echo "  b) KDE Virtual Manager"
  echo "  c) Key Virtual Memory"
  read -p "Your answer (a/b/c): " q1
  if [[ "$q1" == "a" || "$q1" == "A" ]]; then
    echo -e "  ${GREEN}✓ Correct!${NC} KVM is the Linux kernel module for virtualization."
  else
    echo -e "  ${YELLOW}✗ Not quite.${NC} It's Kernel-based Virtual Machine (a)."
  fi
  echo ""
  
  echo -e "${YELLOW}Q2: If your system has 8 GB RAM, how much should you allocate to VMs?${NC}"
  echo "  a) 8 GB (all of it)"
  echo "  b) 4-6 GB (50-75%)"
  echo "  c) 1 GB (be conservative)"
  read -p "Your answer (a/b/c): " q2
  if [[ "$q2" == "b" || "$q2" == "B" ]]; then
    echo -e "  ${GREEN}✓ Correct!${NC} Leave some for the host system."
  else
    echo -e "  ${YELLOW}✗ Not quite.${NC} Allocate 50-75% (b), leaving room for host."
  fi
  echo ""
  
  echo -e "${YELLOW}Q3: Why run diagnostics regularly?${NC}"
  echo "  a) To find issues before they cause problems"
  echo "  b) Because it's fun"
  echo "  c) It's required"
  read -p "Your answer (a/b/c): " q3
  if [[ "$q3" == "a" || "$q3" == "A" ]]; then
    echo -e "  ${GREEN}✓ Correct!${NC} Proactive monitoring prevents surprises."
  else
    echo -e "  ${YELLOW}✗ Not quite.${NC} The answer is (a) - early detection is key!"
  fi
  echo ""
  
  read -p "Press Enter to finish lesson..."
  
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Lesson 1 Complete!${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "🎓 What you learned:"
  echo "  ✓ How to run system diagnostics"
  echo "  ✓ What the output means"
  echo "  ✓ How to read system capabilities"
  echo "  ✓ Resource planning basics"
  echo ""
  echo "💡 Key takeaways:"
  echo "  • Diagnostics are your first troubleshooting step"
  echo "  • Understanding hardware helps plan VMs"
  echo "  • Regular checks prevent problems"
  echo ""
  echo "📚 Next lesson: Downloading Your First ISO"
  echo ""
  read -p "Press Enter to return to menu..."
  
  mark_complete "lesson1"
}

# Lesson 2: Download ISO
lesson2_download_iso() {
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Lesson 2: Downloading Your First ISO${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}📚 What you'll learn:${NC}"
  echo "  • What an ISO is and why you need it"
  echo "  • How to use the ISO Manager"
  echo "  • Why verification matters"
  echo "  • Where ISOs are stored"
  echo ""
  
  echo -e "${BOLD}Background: What is an ISO?${NC}"
  echo ""
  echo "An ISO is a disk image file - think of it as a virtual CD/DVD."
  echo ""
  echo "🎓 The concept:"
  echo "  • Old computers used CD-ROMs to install operating systems"
  echo "  • ISOs are digital copies of those CDs"
  echo "  • VMs can 'mount' ISOs like inserting a CD"
  echo "  • After OS is installed, you don't need the ISO anymore"
  echo ""
  echo "💡 Real-world analogy:"
  echo "  • ISO = Installation USB drive"
  echo "  • VM mounting ISO = Plugging in USB to install"
  echo "  • After install = Remove USB (remove ISO from profile)"
  echo ""
  read -p "Press Enter to continue..."
  
  clear
  echo -e "${BOLD}Why Verification Matters${NC}"
  echo ""
  echo "When you download an ISO from the internet, how do you know it's safe?"
  echo ""
  echo "🔒 Security checks:"
  echo "  1. Checksum (SHA256) - Ensures file isn't corrupted"
  echo "  2. GPG signature - Proves file is authentic (not tampered)"
  echo ""
  echo "🎓 How it works:"
  echo "  • Ubuntu publishes official checksum: abc123..."
  echo "  • You download ISO"
  echo "  • ISO Manager calculates checksum of your download"
  echo "  • If matches: ✓ File is correct and untampered"
  echo "  • If different: ✗ File corrupted or malicious"
  echo ""
  echo "💡 This hypervisor:"
  echo "  • Auto-downloads checksums from official sources"
  echo "  • Auto-verifies after download"
  echo "  • Marks ISOs as verified (.sha256.verified file)"
  echo "  • Prevents using unverified ISOs (security!)"
  echo ""
  read -p "Press Enter for hands-on exercise..."
  
  clear
  echo -e "${YELLOW}📝 Hands-On Exercise${NC}"
  echo ""
  echo "Now you'll download a real ISO using ISO Manager."
  echo ""
  echo "We'll walk through:"
  echo "  1. Launching ISO Manager"
  echo "  2. Selecting an ISO from presets"
  echo "  3. Watching the download and verification"
  echo "  4. Verifying the ISO is ready to use"
  echo ""
  echo -e "${BOLD}Your task:${NC}"
  echo "  Download: Ubuntu 24.04 LTS Server (or any preset you prefer)"
  echo ""
  echo "Command to run:"
  echo -e "  ${GREEN}/etc/hypervisor/scripts/iso_manager.sh${NC}"
  echo ""
  echo "Steps in ISO Manager:"
  echo "  1. Choose: '1 - Download from preset list'"
  echo "  2. Select: Ubuntu 24.04 (or your choice)"
  echo "  3. Wait for download (may take 3-10 minutes)"
  echo "  4. See 'Downloaded and verified' message"
  echo "  5. Exit ISO Manager"
  echo ""
  
  read -p "Ready? Press Enter to launch ISO Manager..."
  
  # Launch ISO Manager
  /etc/hypervisor/scripts/iso_manager.sh || true
  
  clear
  echo -e "${BOLD}Verification Check${NC}"
  echo ""
  echo "Let's verify your ISO was downloaded correctly."
  echo ""
  
  echo -e "${YELLOW}📝 Check 1: ISO exists${NC}"
  echo "Running: ls -lh /var/lib/hypervisor/isos/*.iso"
  echo ""
  ls -lh /var/lib/hypervisor/isos/*.iso 2>/dev/null || echo "No ISOs found"
  echo ""
  read -p "Do you see your ISO? (y/n): " saw_iso
  
  if [[ "$saw_iso" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ Great! Your ISO is downloaded.${NC}"
  else
    echo -e "${YELLOW}⚠ No ISO found. That's okay - you can try again.${NC}"
  fi
  echo ""
  
  echo -e "${YELLOW}📝 Check 2: Verification marker${NC}"
  echo "Running: ls /var/lib/hypervisor/isos/*.verified"
  echo ""
  ls /var/lib/hypervisor/isos/*.verified 2>/dev/null || echo "No verification markers"
  echo ""
  read -p "Do you see a .verified file? (y/n): " saw_verified
  
  if [[ "$saw_verified" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ Excellent! Your ISO was verified.${NC}"
    echo "  This means it's safe to use."
  else
    echo -e "${YELLOW}⚠ No verification marker. The ISO may not be verified.${NC}"
    echo "  Run ISO Manager → Validate ISO checksum to verify."
  fi
  echo ""
  
  read -p "Press Enter to continue..."
  
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Lesson 2 Complete!${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "🎓 What you learned:"
  echo "  ✓ What ISOs are and why you need them"
  echo "  ✓ How to use ISO Manager"
  echo "  ✓ Why verification is important"
  echo "  ✓ Where ISOs are stored"
  echo "  ✓ How to check if download was successful"
  echo ""
  echo "💡 Key takeaways:"
  echo "  • ISOs are temporary - only needed for installation"
  echo "  • Always verify ISOs for security"
  echo "  • Download once, use for multiple VMs"
  echo "  • ISOs live in: /var/lib/hypervisor/isos/"
  echo ""
  echo "📚 Next lesson: Creating Your First VM"
  echo ""
  read -p "Press Enter to return to menu..."
  
  mark_complete "lesson2"
}

# Lesson 3: Create VM
lesson3_create_vm() {
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Lesson 3: Creating Your First VM${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}📚 What you'll learn:${NC}"
  echo "  • What a VM profile is"
  echo "  • How to use the Create VM Wizard"
  echo "  • How to choose appropriate resources"
  echo "  • What happens when a VM is created"
  echo ""
  
  echo -e "${BOLD}Background: What is a VM Profile?${NC}"
  echo ""
  echo "A VM profile is a JSON file that describes your VM's 'hardware'."
  echo ""
  echo "🎓 Think of it as a blueprint:"
  echo "  • How many CPUs? (like choosing a processor)"
  echo "  • How much RAM? (like choosing memory modules)"
  echo "  • How much disk? (like choosing hard drive size)"
  echo "  • What network? (like plugging in ethernet cable)"
  echo ""
  echo "💡 The file is just text - you can edit it anytime!"
  echo ""
  echo "📍 Location: /var/lib/hypervisor/vm-profiles/"
  echo ""
  read -p "Press Enter to see an example profile..."
  
  clear
  echo -e "${BOLD}Example VM Profile (JSON):${NC}"
  echo ""
  cat << 'EOF'
{
  "name": "my-first-vm",
  "cpus": 2,
  "memory_mb": 4096,
  "disk_gb": 20,
  "iso_path": "/var/lib/hypervisor/isos/ubuntu-24.04.iso",
  "network": {
    "bridge": "default"
  }
}
EOF
  echo ""
  echo -e "${BLUE}Breaking it down:${NC}"
  echo "  • name: What you call this VM"
  echo "  • cpus: Number of virtual CPUs (vCPUs)"
  echo "  • memory_mb: RAM in megabytes (4096 = 4 GB)"
  echo "  • disk_gb: Virtual disk size in gigabytes"
  echo "  • iso_path: Which ISO to boot from"
  echo "  • network.bridge: Which network to use"
  echo ""
  read -p "Makes sense? Press Enter..."
  
  clear
  echo -e "${BOLD}Choosing Resources - Guidelines${NC}"
  echo ""
  echo "Your system:"
  echo "  • CPUs: $(nproc) cores"
  echo "  • RAM: $(free -h | awk '/^Mem:/{print $2}')"
  echo "  • Disk: $(df -h /var/lib/hypervisor 2>/dev/null | tail -1 | awk '{print $4}' || echo 'N/A') available"
  echo ""
  echo -e "${BOLD}For Ubuntu Desktop VM, recommend:${NC}"
  echo "  • CPUs: 2 (minimum), 4 (comfortable)"
  echo "  • RAM: 4096 MB (4 GB minimum)"
  echo "  • Disk: 30 GB (20 GB minimum)"
  echo ""
  echo -e "${BOLD}For Ubuntu Server VM, recommend:${NC}"
  echo "  • CPUs: 1-2 (servers don't need many)"
  echo "  • RAM: 2048 MB (2 GB sufficient)"
  echo "  • Disk: 20 GB (10 GB minimum)"
  echo ""
  echo "💡 Rule of thumb:"
  echo "  • Give VM what it needs, not all you have"
  echo "  • Can always increase later if needed"
  echo "  • Better to start conservative"
  echo ""
  read -p "Press Enter for hands-on exercise..."
  
  clear
  echo -e "${YELLOW}📝 Hands-On Exercise${NC}"
  echo ""
  echo "Now create your first VM using the wizard!"
  echo ""
  echo "Suggested name: tutorial-vm"
  echo "Suggested settings: 2 CPUs, 4096 MB RAM, 20 GB disk"
  echo ""
  echo "Command to run:"
  echo -e "  ${GREEN}/etc/hypervisor/scripts/create_vm_wizard.sh \\${NC}"
  echo -e "  ${GREEN}  /var/lib/hypervisor/vm-profiles \\${NC}"
  echo -e "  ${GREEN}  /var/lib/hypervisor/isos${NC}"
  echo ""
  read -p "Ready? Press Enter to launch wizard..."
  
  /etc/hypervisor/scripts/create_vm_wizard.sh /var/lib/hypervisor/vm-profiles /var/lib/hypervisor/isos || true
  
  clear
  echo -e "${BOLD}Verification${NC}"
  echo ""
  echo "Let's check that your VM profile was created."
  echo ""
  echo "Your VM profiles:"
  ls -1 /var/lib/hypervisor/vm-profiles/*.json 2>/dev/null | while read -r profile; do
    local name=$(jq -r '.name // empty' "$profile" 2>/dev/null || basename "$profile" .json)
    echo "  • $name"
  done
  echo ""
  read -p "See your new VM? Press Enter..."
  
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Lesson 3 Complete!${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "🎓 What you learned:"
  echo "  ✓ What VM profiles are (JSON configuration files)"
  echo "  ✓ How to use Create VM Wizard"
  echo "  ✓ How to choose appropriate resources"
  echo "  ✓ Where profiles are stored"
  echo ""
  echo "💡 Key takeaways:"
  echo "  • Profiles are just text files - easy to edit"
  echo "  • Start conservative with resources"
  echo "  • Can copy profiles to create similar VMs"
  echo "  • Location: /var/lib/hypervisor/vm-profiles/"
  echo ""
  echo "📚 Next lesson: Starting and Connecting to VMs"
  echo ""
  read -p "Press Enter to return to menu..."
  
  mark_complete "lesson3"
}

# Placeholder lessons (implement similar structure)
lesson4_start_connect() {
  $DIALOG --msgbox "Lesson 4: Starting and Connecting to VMs\n\n(Tutorial content coming soon)\n\nFor now, see:\ndocs/QUICKSTART_EXPANDED.md" 12 60
  mark_complete "lesson4"
}

lesson5_lifecycle() {
  $DIALOG --msgbox "Lesson 5: VM Lifecycle Management\n\n(Tutorial content coming soon)\n\nTopics: Start, stop, pause, reset, delete" 12 60
  mark_complete "lesson5"
}

lesson6_networking() {
  $DIALOG --msgbox "Lesson 6: Network Configuration\n\n(Tutorial content coming soon)\n\nTopics: NAT vs Bridge, network zones, firewall" 12 60
  mark_complete "lesson6"
}

lesson7_snapshots() {
  $DIALOG --msgbox "Lesson 7: Snapshots and Backups\n\n(Tutorial content coming soon)\n\nTopics: Creating snapshots, restoring, backups" 12 60
  mark_complete "lesson7"
}

lesson8_monitoring() {
  $DIALOG --msgbox "Lesson 8: Monitoring and Troubleshooting\n\n(Tutorial content coming soon)\n\nTopics: Dashboard, diagnostics, health monitor, logs" 12 60
  mark_complete "lesson8"
}

lesson9_bulk_ops() {
  $DIALOG --msgbox "Lesson 9: Bulk Operations\n\n(Tutorial content coming soon)\n\nTopics: Multi-VM management, automation" 12 60
  mark_complete "lesson9"
}

lesson10_advanced() {
  $DIALOG --msgbox "Lesson 10: Advanced Features\n\n(Tutorial content coming soon)\n\nTopics: VFIO, SEV, CPU pinning, optimization" 12 60
  mark_complete "lesson10"
}

# Main entry point
main() {
  clear
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Welcome to the Interactive Hypervisor Tutorial!${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "🎓 Learn by doing with hands-on guided exercises."
  echo ""
  echo "What this tutorial covers:"
  echo "  • System diagnostics and health checks"
  echo "  • Downloading and verifying ISOs"
  echo "  • Creating and managing VMs"
  echo "  • Networking and storage"
  echo "  • Monitoring and troubleshooting"
  echo "  • Advanced features and optimization"
  echo ""
  echo "💡 Each lesson includes:"
  echo "  • Explanation of concepts"
  echo "  • Hands-on exercises"
  echo "  • Real commands to run"
  echo "  • Knowledge checks"
  echo "  • Key takeaways"
  echo ""
  echo "⏱️  Time: 10-20 minutes per lesson"
  echo "📊 Progress: Tracked automatically"
  echo ""
  read -p "Ready to start learning? Press Enter..."
  
  tutorial_menu
}

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Interactive Hypervisor Tutorial"
  echo ""
  echo "Learn the hypervisor through hands-on guided exercises."
  echo ""
  echo "Usage: $0"
  echo ""
  echo "Features:"
  echo "  • 10 progressive lessons"
  echo "  • Hands-on exercises"
  echo "  • Automatic progress tracking"
  echo "  • Quizzes to test understanding"
  echo "  • Can complete in any order"
  echo ""
  echo "Time: 2-3 hours total (can be done in segments)"
  echo ""
  echo "Access from menu:"
  echo "  More Options → Interactive Tutorial (Learning Mode)"
  exit 0
fi

# Run
main
