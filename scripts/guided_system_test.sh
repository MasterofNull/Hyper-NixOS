#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Guided System Testing Wizard
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Interactive wizard that guides users through system testing
# while teaching them what's being tested and why
#

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

DIALOG="${DIALOG:-whiptail}"
LOG_FILE="/var/lib/hypervisor/logs/guided-test-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

log() {
  echo "[$(date -Iseconds)] $*" >> "$LOG_FILE"
}

show_intro() {
  $DIALOG --title "System Testing Wizard" --msgbox "\
╔════════════════════════════════════════════════════════════════╗
║          Welcome to System Testing Wizard                      ║
╚════════════════════════════════════════════════════════════════╝

This wizard will guide you through testing your Hyper-NixOS system.

WHAT YOU'LL LEARN:
• How to validate your hypervisor is working correctly
• What each component does and why it's important
• How to diagnose problems if tests fail
• Professional testing practices you can use anywhere

WHAT WE'LL TEST:
• System Configuration (NixOS, files, permissions)
• Security Model (users, groups, polkit rules)
• Virtualization (KVM, libvirt, QEMU)
• Networking (bridges, firewall, DNS)
• Services (health checks, backups, monitoring)
• VM Lifecycle (create, start, stop, delete)

TIME: ~10 minutes

Press OK to begin your learning journey!" 24 78
}

explain_and_test() {
  local test_name="$1"
  local description="$2"
  local why_it_matters="$3"
  local what_were_checking="$4"
  local test_command="$5"
  local success_means="$6"
  local failure_help="$7"
  
  # Explain what we're about to test
  $DIALOG --title "Test: $test_name" --msgbox "\
═══════════════════════════════════════════════════════════════

WHAT: $description

WHY IT MATTERS:
$why_it_matters

WHAT WE'RE CHECKING:
$what_were_checking

Press OK to run this test..." 20 78
  
  # Show progress
  echo ""
  echo -e "${BOLD}${CYAN}Testing: $test_name${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  
  ((TESTS_RUN++))
  log "Running test: $test_name"
  
  # Run the test with visual feedback
  echo -n "Running test... "
  
  local result=0
  if eval "$test_command" >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
    log "PASS: $test_name"
    
    # Explain what success means
    $DIALOG --title "✓ Test Passed" --msgbox "\
SUCCESS! ✓

$success_means

KEY TAKEAWAY:
This means your system is correctly configured for this component.
You can confidently rely on this functionality.

SKILLS LEARNED:
• How to test: $what_were_checking
• Commands used: $(echo "$test_command" | head -c 100)...
• Expected result: Success indicates proper configuration

Press OK to continue..." 20 78
  else
    echo -e "${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$test_name")
    log "FAIL: $test_name"
    
    # Explain failure and how to fix
    $DIALOG --title "✗ Test Failed" --yesno "\
TEST FAILED ✗

This test didn't pass, but that's okay! This is a learning opportunity.

WHAT THIS MEANS:
$failure_help

HOW TO FIX:
1. Read the detailed error in the log: $LOG_FILE
2. Follow the recommendations above
3. Re-run this wizard after making changes

WANT TO SEE THE DETAILED ERROR NOW?
(It will be displayed in your terminal)

Yes = Show error details
No = Continue to next test" 22 78
    
    if [[ $? -eq 0 ]]; then
      # Show error details
      echo ""
      echo -e "${RED}═══ ERROR DETAILS ═══${NC}"
      tail -20 "$LOG_FILE"
      echo -e "${RED}═════════════════════${NC}"
      echo ""
      read -p "Press Enter to continue..."
    fi
  fi
  
  echo ""
}

test_nixos_configuration() {
  explain_and_test \
    "NixOS Configuration" \
    "Verify that the NixOS configuration files exist and are valid" \
    "NixOS uses declarative configuration. These files define your entire system.
Without them, you can't manage or update your hypervisor." \
    "• Flake file exists at /etc/hypervisor/flake.nix
• Main config exists at /etc/hypervisor/src/configuration.nix
• Configuration is valid Nix syntax" \
    "test -f /etc/hypervisor/flake.nix && test -f /etc/hypervisor/src/configuration.nix" \
    "Your NixOS configuration is properly installed.

This means:
• You can rebuild your system with: nixos-rebuild switch
• Your configuration is version-controlled
• You can roll back to previous versions if needed

This is the foundation of NixOS's reliability!" \
    "Your configuration files are missing or in the wrong location.

To fix:
1. Re-run the system installer: sudo bash /etc/hypervisor/scripts/system_installer.sh
2. Or check that /etc/hypervisor/ directory exists
3. Verify you completed the initial installation

TRANSFERABLE SKILL:
On any NixOS system, configuration lives in /etc/nixos/ or a custom location.
Always verify your configuration files exist before making changes!"
}

test_security_model() {
  explain_and_test \
    "Zero-Trust Security Model" \
    "Verify the production security model is active" \
    "Security is the foundation of a reliable hypervisor.
The zero-trust model ensures operators can manage VMs but can't compromise the system." \
    "• Operator user 'hypervisor-operator' exists
• Operator is NOT in wheel group (no sudo access)
• Operator IS in kvm and libvirtd groups (VM access)
• Polkit rules allow specific VM operations only" \
    "id hypervisor-operator >/dev/null 2>&1 && \
     ! id -nG hypervisor-operator | grep -qw wheel && \
     id -nG hypervisor-operator | grep -qw kvm && \
     id -nG hypervisor-operator | grep -qw libvirtd" \
    "Your security model is correctly configured!

What this means:
• The operator can create and manage VMs
• The operator CANNOT modify the system or install packages
• Even if the operator account is compromised, the host is protected
• This is called 'least privilege' - a fundamental security principle

REAL-WORLD APPLICATION:
This same pattern (dedicated service accounts with minimal permissions)
is used in production environments everywhere. You're learning industry
best practices!" \
    "The security model is not properly configured.

This could mean:
• The system installer wasn't run completely
• Security settings were manually changed
• The security-production.nix module isn't loaded

To fix:
1. Check: cat /etc/hypervisor/src/configuration.nix
2. Verify 'security-production.nix' is in the imports
3. Rebuild: sudo nixos-rebuild switch --flake /etc/hypervisor

LEARNING MOMENT:
Security requires careful configuration. One missing import can create a vulnerability.
Always verify security settings after any system change!"
}

test_virtualization_support() {
  explain_and_test \
    "Virtualization Hardware" \
    "Check that CPU virtualization extensions are available" \
    "Modern VMs need hardware virtualization (VT-x or AMD-V).
Without it, VMs run very slowly or not at all." \
    "• CPU supports virtualization extensions
• KVM kernel module is loaded
• /dev/kvm device exists with correct permissions" \
    "test -c /dev/kvm && lsmod | grep -q kvm" \
    "Your CPU supports hardware virtualization and it's enabled!

What this means:
• VMs will run at near-native speed
• You can run multiple VMs without slowdown
• You have the same setup as enterprise data centers

TECHNICAL DETAIL:
• /dev/kvm is the interface to the KVM hypervisor
• KVM = Kernel-based Virtual Machine
• This is the same tech used by AWS, Google Cloud, and Azure

You have enterprise-grade virtualization!" \
    "Hardware virtualization is not available or not enabled.

Common causes:
1. CPU doesn't support VT-x/AMD-V (check: lscpu | grep -i virtual)
2. Virtualization is disabled in BIOS/UEFI settings
3. Running inside a VM that doesn't expose virtualization

To fix:
1. Reboot and enter BIOS/UEFI (usually Del, F2, or F12)
2. Find 'Virtualization Technology' or 'VT-x' or 'AMD-V'
3. Enable it and save

LEARNING: Most modern CPUs support virtualization, but it's often
disabled by default. This is one of the first things system administrators
check when setting up hypervisors!"
}

test_libvirt_daemon() {
  explain_and_test \
    "Libvirt Daemon" \
    "Verify the libvirt virtualization management service is running" \
    "Libvirt is the management layer for VMs. It handles VM creation,
networking, storage, and lifecycle. Without it, you can't manage VMs." \
    "• libvirtd service is running
• libvirt socket is accessible
• You can connect to qemu:///system" \
    "systemctl is-active libvirtd && virsh -c qemu:///system list --all >/dev/null 2>&1" \
    "Libvirt is running and accessible!

What this means:
• You can create and manage VMs
• Networking and storage pools work
• The virsh command will function

PROFESSIONAL TIP:
'virsh' is your command-line interface to libvirt.
Key commands you'll use:
  virsh list --all       # List all VMs
  virsh start <vm>       # Start a VM
  virsh shutdown <vm>    # Gracefully stop a VM
  virsh console <vm>     # Connect to VM console

These skills work on any Linux hypervisor!" \
    "Libvirt is not running properly.

To diagnose:
1. Check status: systemctl status libvirtd
2. View logs: journalctl -xeu libvirtd
3. Try starting: sudo systemctl start libvirtd

Common issues:
• Service wasn't started after installation
• Permission problems with /var/lib/libvirt
• Conflicts with other virtualization software

TROUBLESHOOTING SKILL:
When a service fails, always check:
1. systemctl status <service> - is it running?
2. journalctl -xeu <service> - what errors occurred?
3. Is the user in the right groups? (Check with: groups)

These debugging steps work for ANY systemd service!"
}

test_network_bridge() {
  explain_and_test \
    "Network Bridge" \
    "Check if a network bridge is configured for VM networking" \
    "Bridges allow VMs to connect to your network as if they were physical machines.
Without a bridge, VMs can only talk to the host." \
    "• At least one bridge interface exists (br0, virbr0, etc.)
• Bridge is in UP state
• Bridge has IP configuration" \
    "ip link show type bridge | grep -q 'state UP'" \
    "A network bridge is configured and active!

What this means:
• Your VMs can get network connectivity
• VMs can communicate with each other
• VMs can access your LAN (if bridge is connected to physical interface)

NETWORKING CONCEPT:
A bridge is like a virtual network switch:
• Physical interface (eth0) → Bridge (br0) → VMs (vnet0, vnet1...)
• All devices on the bridge can see each other
• This is the standard way to network VMs

View your bridges: ip link show type bridge
View bridge details: bridge link

This knowledge applies to Docker, Kubernetes, and all virtualization!" \
    "No active network bridge found.

This is okay if:
• You just installed and haven't run the network setup wizard yet
• You're planning to use NAT networking only

To create a bridge:
1. Run: sudo /etc/hypervisor/scripts/bridge_helper.sh
2. Follow the wizard to configure networking
3. Choose your network mode (bridge or NAT)

LEARNING POINT:
Linux bridges are fundamental to container and VM networking.
Docker creates 'docker0' bridge, Kubernetes uses CNI bridges, 
hypervisors use custom bridges like 'br0'.

Once you understand Linux bridges, you understand 90% of Linux networking!"
}

test_health_check_system() {
  explain_and_test \
    "Health Check System" \
    "Verify the automated health monitoring is configured" \
    "Automated health checks catch problems before they cause downtime.
This is proactive operations - preventing issues instead of reacting to them." \
    "• Health check script exists and is executable
• Systemd timer is configured to run checks daily
• Health check can be run manually" \
    "test -x /etc/hypervisor/scripts/system_health_check.sh && \
     systemctl list-timers hypervisor-health-check.timer >/dev/null 2>&1" \
    "Automated health monitoring is active!

What this means:
• Your system checks itself daily
• You'll be alerted to problems early
• Issues are caught before users notice

PROACTIVE OPERATIONS:
Instead of waiting for something to break, you're monitoring:
• Disk space (before it fills up)
• Service status (before it causes errors)
• VM health (before performance degrades)

Run it manually: sudo /etc/hypervisor/scripts/system_health_check.sh

CAREER SKILL:
Proactive monitoring is the difference between junior and senior operators.
Learning to set up automated health checks is a valuable skill in any tech role!" \
    "Health check system is not fully configured.

To set up:
1. Verify script: ls -l /etc/hypervisor/scripts/system_health_check.sh
2. Check timer: systemctl status hypervisor-health-check.timer
3. Enable timer: sudo systemctl enable --now hypervisor-health-check.timer

MONITORING PHILOSOPHY:
Good operators don't wait for things to break. They:
1. Set up automated checks
2. Get alerted to problems early
3. Fix issues during maintenance windows

This approach minimizes downtime and stress!"
}

test_backup_system() {
  explain_and_test \
    "Backup System" \
    "Verify automated backup system is configured" \
    "Backups are your insurance policy. When (not if) something goes wrong,
backups let you recover. Automated backups ensure you're always protected." \
    "• Backup script exists and is executable
• Backup directory exists
• Systemd timer is configured for nightly backups" \
    "test -x /etc/hypervisor/scripts/automated_backup.sh && \
     test -d /var/lib/hypervisor/backups" \
    "Automated backup system is configured!

What this means:
• Your VMs are backed up automatically every night
• Old backups are rotated to save space
• You can restore from backups if needed

BACKUP BEST PRACTICES:
• 3-2-1 Rule: 3 copies, 2 different media, 1 offsite
• Automated: Manual backups get forgotten
• Tested: Untested backups are useless

Test your backup: sudo /etc/hypervisor/scripts/automated_backup.sh list

PROFESSIONAL INSIGHT:
Every production system needs automated backups.
The skills you're learning here (scripting backups, setting up timers,
testing restores) are fundamental to system administration.

Many outages could have been prevented with good backups!" \
    "Backup system is not fully set up.

To configure:
1. Verify script: ls -l /etc/hypervisor/scripts/automated_backup.sh
2. Create backup dir: sudo mkdir -p /var/lib/hypervisor/backups
3. Enable timer: sudo systemctl enable --now hypervisor-backup.timer

DISASTER RECOVERY:
Ask yourself:
• If my disk died right now, could I recover?
• When was my last backup?
• Have I ever tested restoring from backup?

If any answer is uncertain, set up backups now!"
}

run_vm_lifecycle_test() {
  local test_vm="test-wizard-$$"
  
  $DIALOG --title "VM Lifecycle Test" --yesno "\
═══════════════════════════════════════════════════════════════

COMPREHENSIVE VM TEST

This test will create a real VM, start it, stop it, and delete it.

WHAT YOU'LL LEARN:
• How VM creation works end-to-end
• How to start and stop VMs
• How to properly clean up VMs
• Common issues and how to fix them

WHAT WE'LL DO:
1. Create a test VM profile
2. Convert it to libvirt XML
3. Define the VM in libvirt
4. Start the VM
5. Verify it's running
6. Stop the VM
7. Clean up

This test will take ~2 minutes.

IMPORTANT: We'll create a real (but minimal) VM. It won't use much disk space.

Ready to test the full VM lifecycle?

Yes = Run the test
No = Skip this test" 28 78
  
  if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}Skipped VM lifecycle test${NC}"
    return 0
  fi
  
  echo ""
  echo -e "${BOLD}${CYAN}VM Lifecycle Test${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  
  # Step 1: Create profile
  echo -e "${CYAN}Step 1/7:${NC} Creating test VM profile..."
  cat > "/tmp/$test_vm.json" << EOF
{
  "name": "$test_vm",
  "memory_mb": 512,
  "cpus": 1,
  "disk_gb": 1,
  "network": "default"
}
EOF
  echo -e "${GREEN}✓${NC} Profile created"
  
  # Step 2: Define VM
  echo -e "${CYAN}Step 2/7:${NC} Defining VM in libvirt..."
  if /etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh "/tmp/$test_vm.json" >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}✓${NC} VM defined"
  else
    echo -e "${RED}✗${NC} Failed to define VM"
    return 1
  fi
  
  # Step 3: Verify definition
  echo -e "${CYAN}Step 3/7:${NC} Verifying VM appears in list..."
  if virsh list --all | grep -q "$test_vm"; then
    echo -e "${GREEN}✓${NC} VM found in list"
  else
    echo -e "${RED}✗${NC} VM not found"
    return 1
  fi
  
  # Step 4: Start VM
  echo -e "${CYAN}Step 4/7:${NC} Starting VM..."
  if virsh start "$test_vm" >> "$LOG_FILE" 2>&1; then
    echo -e "${GREEN}✓${NC} VM started"
  else
    echo -e "${RED}✗${NC} Failed to start"
    virsh undefine "$test_vm" 2>/dev/null
    return 1
  fi
  
  # Step 5: Verify running
  echo -e "${CYAN}Step 5/7:${NC} Verifying VM is running..."
  sleep 2
  if virsh list --state-running | grep -q "$test_vm"; then
    echo -e "${GREEN}✓${NC} VM is running!"
  else
    echo -e "${RED}✗${NC} VM not running"
  fi
  
  # Step 6: Stop VM
  echo -e "${CYAN}Step 6/7:${NC} Stopping VM..."
  virsh destroy "$test_vm" >> "$LOG_FILE" 2>&1
  echo -e "${GREEN}✓${NC} VM stopped"
  
  # Step 7: Cleanup
  echo -e "${CYAN}Step 7/7:${NC} Cleaning up..."
  virsh undefine "$test_vm" >> "$LOG_FILE" 2>&1
  rm -f "/tmp/$test_vm.json"
  echo -e "${GREEN}✓${NC} Cleanup complete"
  
  echo ""
  ((TESTS_RUN++))
  ((TESTS_PASSED++))
  
  $DIALOG --title "✓ VM Lifecycle Test Passed" --msgbox "\
SUCCESS! You just completed a full VM lifecycle! ✓

WHAT YOU ACCOMPLISHED:
• Created a VM from a JSON profile
• Defined it in libvirt (registered it)
• Started the VM
• Verified it was running
• Stopped it gracefully
• Cleaned up all resources

COMMANDS YOU LEARNED:
• virsh list --all          # List all VMs
• virsh start <vm>          # Start a VM
• virsh destroy <vm>        # Force stop
• virsh undefine <vm>       # Remove VM

REAL-WORLD APPLICATION:
This is the exact process you'll use for production VMs:
1. Create → 2. Start → 3. Use → 4. Stop → 5. Backup → 6. Delete

You now understand VM management at a deep level.
These skills work with KVM, QEMU, oVirt, Proxmox, and more!

Press OK to see the final results..." 28 78
}

show_final_results() {
  local status="SUCCESS"
  local message="All tests passed! Your system is properly configured."
  local recommendations=""
  
  if [[ $TESTS_FAILED -gt 0 ]]; then
    status="NEEDS ATTENTION"
    message="Some tests failed, but that's okay! Let's fix them."
    recommendations="\n\nFAILED TESTS:\n"
    for test in "${FAILED_TESTS[@]}"; do
      recommendations+="• $test\n"
    done
    recommendations+="\nNext steps:\n"
    recommendations+="1. Review the detailed log: $LOG_FILE\n"
    recommendations+="2. Follow the fix recommendations from each test\n"
    recommendations+="3. Re-run this wizard to verify fixes\n"
  fi
  
  $DIALOG --title "Testing Complete - $status" --msgbox "\
═══════════════════════════════════════════════════════════════
                     TESTING COMPLETE
═══════════════════════════════════════════════════════════════

RESULTS:
• Tests run: $TESTS_RUN
• Tests passed: $TESTS_PASSED ✓
• Tests failed: $TESTS_FAILED

$message$recommendations

═══════════════════════════════════════════════════════════════
                   WHAT YOU LEARNED
═══════════════════════════════════════════════════════════════

TECHNICAL SKILLS:
• How to test system configuration
• How to diagnose problems
• How to use virsh, systemctl, and other tools
• Professional testing methodology

CONCEPTUAL UNDERSTANDING:
• Why each component matters
• How pieces fit together
• Industry best practices
• Security principles

CAREER SKILLS:
• Proactive monitoring
• Automated testing
• Problem diagnosis
• Documentation reading

═══════════════════════════════════════════════════════════════
                    NEXT STEPS
═══════════════════════════════════════════════════════════════

1. Run this wizard regularly to verify your system
2. When adding new VMs, run specific tests
3. Before major changes, run tests to catch issues early
4. Share what you learned with others!

AVAILABLE COMMANDS:
• Run wizard: sudo /etc/hypervisor/scripts/guided_system_test.sh
• Quick test: sudo /etc/hypervisor/scripts/system_health_check.sh
• Run CI tests: cd /etc/hypervisor/tests && ./run_all_tests.sh

Detailed log saved to: $LOG_FILE

═══════════════════════════════════════════════════════════════

You're now equipped with professional-grade testing knowledge!

Press OK to finish." 45 78
}

main_menu() {
  while true; do
    local choice
    choice=$($DIALOG --title "Guided Testing Wizard - Main Menu" --menu "\
Choose what you'd like to test and learn about:

Each test includes:
• Explanation of what's being tested
• Why it matters
• Step-by-step execution
• Success/failure interpretation
• How to fix problems
• Skills you can use elsewhere

Your progress: $TESTS_RUN tests run, $TESTS_PASSED passed, $TESTS_FAILED failed" 26 78 12 \
      "1" "Full Guided Test (All tests with explanations)" \
      "2" "System Configuration (NixOS, files)" \
      "3" "Security Model (Zero-trust, permissions)" \
      "4" "Virtualization (KVM, hardware)" \
      "5" "Libvirt Service (VM management)" \
      "6" "Network Bridge (VM networking)" \
      "7" "Health Checks (Automated monitoring)" \
      "8" "Backup System (Data protection)" \
      "9" "VM Lifecycle (Create, start, stop, delete)" \
      "10" "View Results Summary" \
      "11" "Exit" \
      3>&1 1>&2 2>&3)
    
    case "$choice" in
      1)
        test_nixos_configuration
        test_security_model
        test_virtualization_support
        test_libvirt_daemon
        test_network_bridge
        test_health_check_system
        test_backup_system
        run_vm_lifecycle_test
        show_final_results
        ;;
      2) test_nixos_configuration ;;
      3) test_security_model ;;
      4) test_virtualization_support ;;
      5) test_libvirt_daemon ;;
      6) test_network_bridge ;;
      7) test_health_check_system ;;
      8) test_backup_system ;;
      9) run_vm_lifecycle_test ;;
      10) show_final_results ;;
      11|"") break ;;
    esac
  done
}

# Main execution
main() {
  log "Guided System Test started"
  
  show_intro
  main_menu
  
  log "Guided System Test completed: $TESTS_RUN run, $TESTS_PASSED passed, $TESTS_FAILED failed"
  
  echo ""
  echo -e "${GREEN}Thank you for using the Guided Testing Wizard!${NC}"
  echo -e "Log saved to: $LOG_FILE"
  echo ""
}

main "$@"
