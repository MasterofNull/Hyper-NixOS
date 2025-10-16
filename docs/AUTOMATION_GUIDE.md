# Automation Guide - Streamline Your Workflow

**Learn how to automate common tasks and integrate the hypervisor into your workflows**

---

## 🎯 Purpose of This Guide

Help you:
- ⏰ **Save time** with automation
- 🔄 **Standardize** operations
- 🛡️ **Reduce errors** through consistency
- 📈 **Scale** operations efficiently
- 🎓 **Learn** scripting patterns

---

## Table of Contents

1. [Why Automate](#why-automate)
2. [Where to Automate](#where-to-automate)
3. [When to Automate](#when-to-automate)
4. [How to Automate](#how-to-automate)
5. [Automation Patterns](#automation-patterns)
6. [Common Scenarios](#common-scenarios)
7. [Best Practices](#best-practices)

---

## Why Automate

### Benefits

**For Daily Operations:**
- ✅ Consistency - Same result every time
- ✅ Speed - Run instantly vs manual steps
- ✅ Reliability - No forgotten steps
- ✅ Documentation - Scripts document process

**For Learning:**
- ✅ Understanding - See exactly what happens
- ✅ Repeatability - Practice safely
- ✅ Experimentation - Try variations easily
- ✅ Knowledge capture - Share with team

**For Production:**
- ✅ Scalability - Manage many VMs easily
- ✅ Audit trail - All actions logged
- ✅ Recovery - Recreate environments quickly
- ✅ Integration - Connect with other systems

---

## Where to Automate

### High-Value Automation Targets

**1. Daily Start/Stop Routines**
- ⏰ WHEN: You do this daily
- 💰 VALUE: Save 5-10 minutes/day
- 📊 ROI: High - automate first!

**2. Environment Setup**
- ⏰ WHEN: Creating dev/test environments
- 💰 VALUE: Standardize configurations
- 📊 ROI: Medium-High - avoid configuration drift

**3. Backup Operations**
- ⏰ WHEN: Regular backups needed
- 💰 VALUE: Never forget backups
- 📊 ROI: High - data protection

**4. Monitoring and Alerts**
- ⏰ WHEN: Production VMs
- 💰 VALUE: Catch issues early
- 📊 ROI: Very High - prevent downtime

**5. Resource Optimization**
- ⏰ WHEN: Resource constraints
- 💰 VALUE: Optimal allocation
- 📊 ROI: Medium - efficiency gains

---

## When to Automate

### Decision Framework

**DO automate when:**
- ✅ Task repeated regularly (daily/weekly)
- ✅ Task has multiple steps
- ✅ Task is error-prone if manual
- ✅ Consistency matters
- ✅ Documentation needed
- ✅ Integration with other systems

**DON'T automate when:**
- ❌ Task done once or rarely
- ❌ Task requires human judgment
- ❌ Automation more complex than task
- ❌ Still learning the process
- ❌ Requirements change frequently

### ROI Calculation

```
Time Saved = (Manual Time - Automated Time) × Frequency
ROI = Time Saved / Time to Automate

Example:
  Manual VM backup: 10 min
  Automated: 1 min (setup) + 0 min (runs automatically)
  Frequency: Daily (365 times/year)
  Time saved: 9 min × 365 = 54.75 hours/year!
  Time to automate: 30 minutes
  ROI: 54.75 hours saved / 0.5 hours investment = 109x return!
```

---

## How to Automate

### Method 1: Using Provided Scripts

**Easiest** - Use built-in automation tools

```bash
# Bulk operations (provided)
/etc/hypervisor/scripts/bulk_operations.sh

# Health monitoring (provided)
/etc/hypervisor/scripts/health_monitor.sh daemon &

# Scheduled metrics (provided)
PROM_DAEMON=true /etc/hypervisor/scripts/prom_exporter_enhanced.sh &
```

### Method 2: Command-Line Scripting

**Flexible** - Create custom scripts

```bash
#!/usr/bin/env bash
# Example: Start development environment

echo "Starting development environment..."

# Start all dev VMs
for vm in web-server db-server cache-server; do
  echo "Starting: $vm"
  virsh start "$vm" 2>/dev/null || echo "Already running: $vm"
done

echo "Waiting for VMs to boot..."
sleep 10

# Check all are running
virsh list | grep -E "(web-server|db-server|cache-server)"

echo "Development environment ready!"
```

### Method 3: Systemd Timers

**Scheduled** - Run tasks on schedule

```nix
# In configuration.nix

systemd.timers.vm-backup = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    OnBootSec = "10m";
    Unit = "vm-backup.service";
  };
};

systemd.services.vm-backup = {
  serviceConfig = {
    ExecStart = "/etc/hypervisor/scripts/backup-all-vms.sh";
    User = "hypervisor";
  };
};
```

### Method 4: JSON-Based Automation

**Declarative** - Define desired state

```json
{
  "environment": "development",
  "vms": [
    {
      "name": "web-server",
      "autostart": true,
      "priority": 10
    },
    {
      "name": "db-server", 
      "autostart": true,
      "priority": 5
    }
  ],
  "daily_tasks": {
    "backup": true,
    "snapshot": false,
    "health_check": true
  }
}
```

---

## Automation Patterns

### Pattern 1: Start Multiple Related VMs

**Scenario:** Development environment with multiple services

**Script:** `start-dev-env.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

VMS=("web-server" "db-server" "cache-server" "queue-server")

echo "Starting development environment..."
for vm in "${VMS[@]}"; do
  if virsh domstate "$vm" 2>/dev/null | grep -q "shut off"; then
    echo "  Starting: $vm"
    virsh start "$vm"
    sleep 5  # Stagger starts
  else
    echo "  Already running: $vm"
  fi
done

echo ""
echo "✓ Development environment started"
echo ""
echo "VM Status:"
virsh list | grep -E "($(IFS=\|; echo "${VMS[*]}"))"
```

**Usage:**
```bash
# Morning startup
./start-dev-env.sh

# Or add to cron/systemd timer
```

### Pattern 2: Automated Backups

**Scenario:** Nightly VM snapshots

**Script:** `nightly-snapshot.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT_NAME="nightly-$(date +%Y%m%d-%H%M)"
VMS=$(virsh list --all --name | grep -v '^$')

echo "Creating nightly snapshots: $SNAPSHOT_NAME"

for vm in $VMS; do
  echo "  Snapshotting: $vm"
  
  if virsh snapshot-create-as "$vm" \
      "$SNAPSHOT_NAME" \
      "Automated nightly snapshot" \
      --atomic 2>&1 | tee -a /var/lib/hypervisor/logs/snapshots.log; then
    echo "    ✓ Success"
  else
    echo "    ✗ Failed"
  fi
done

# Clean old snapshots (keep last 7 days)
echo ""
echo "Cleaning old snapshots..."
for vm in $VMS; do
  virsh snapshot-list "$vm" --name 2>/dev/null | \
    grep "^nightly-" | \
    sort -r | \
    tail -n +8 | \
    while read snapshot; do
      echo "  Deleting old: $vm -> $snapshot"
      virsh snapshot-delete "$vm" "$snapshot"
    done
done

echo ""
echo "✓ Nightly snapshot complete"
```

**Schedule with systemd:**
```nix
systemd.timers.nightly-snapshot = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    OnCalendar = "*-*-* 02:00:00";  # 2 AM daily
  };
};

systemd.services.nightly-snapshot = {
  serviceConfig = {
    ExecStart = "/etc/hypervisor/scripts/nightly-snapshot.sh";
  };
};
```

### Pattern 3: Resource Monitoring

**Scenario:** Alert when resources low

**Script:** `check-resources.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

# Check disk space
DISK_USED=$(df /var/lib/hypervisor | tail -1 | awk '{print $5}' | tr -d '%')
if [[ "$DISK_USED" -gt 85 ]]; then
  echo "⚠️  WARNING: Disk usage at ${DISK_USED}%"
  
  # Send alert (customize)
  logger -t hypervisor "Disk usage critical: ${DISK_USED}%"
  
  # Optional: Email alert
  # echo "Disk usage: ${DISK_USED}%" | mail -s "Hypervisor Alert" admin@example.com
fi

# Check memory
MEM_USED=$(free | awk '/^Mem:/{printf("%.0f", $3/$2*100)}')
if [[ "$MEM_USED" -gt 90 ]]; then
  echo "⚠️  WARNING: Memory usage at ${MEM_USED}%"
  logger -t hypervisor "Memory usage critical: ${MEM_USED}%"
fi

# Check VMs that should be running
while read -r vm; do
  [[ -z "$vm" ]] && continue
  
  # If autostart enabled but VM not running
  if virsh dominfo "$vm" | grep -q "Autostart:.*enable"; then
    if ! virsh domstate "$vm" | grep -q "running"; then
      echo "⚠️  WARNING: $vm should be running but isn't"
      logger -t hypervisor "VM $vm down (autostart enabled)"
      
      # Optional: Auto-restart
      # virsh start "$vm"
    fi
  fi
done < <(virsh list --all --name)
```

**Schedule:** Run every 15 minutes
```bash
# Add to crontab
*/15 * * * * /etc/hypervisor/scripts/check-resources.sh
```

### Pattern 4: Environment Provisioning

**Scenario:** Recreate test environment on demand

**Script:** `provision-test-env.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Provisioning test environment..."

# Define environment
declare -A VMS=(
  ["test-web"]="2:2048:20:ubuntu-server"
  ["test-db"]="2:4096:30:ubuntu-server"
  ["test-cache"]="1:1024:10:ubuntu-server"
)

# Create each VM
for vm_name in "${!VMS[@]}"; do
  IFS=':' read -r cpus memory disk iso <<< "${VMS[$vm_name]}"
  
  echo "Creating: $vm_name ($cpus CPU, ${memory}MB RAM, ${disk}GB disk)"
  
  # Create profile
  cat > "/var/lib/hypervisor/vm-profiles/${vm_name}.json" <<EOF
{
  "name": "$vm_name",
  "cpus": $cpus,
  "memory_mb": $memory,
  "disk_gb": $disk,
  "iso_path": "/var/lib/hypervisor/isos/${iso}.iso",
  "network": {"bridge": "default"},
  "autostart": false
}
EOF
  
  # Create and start
  /etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh \
    "/var/lib/hypervisor/vm-profiles/${vm_name}.json" || true
done

echo ""
echo "✓ Test environment provisioned"
echo ""
echo "VMs created:"
virsh list --all | grep test-
```

---

## Common Scenarios

### Scenario 1: Morning Startup Routine

**Goal:** Start work environment quickly

**Script:**
```bash
#!/usr/bin/env bash
# morning-startup.sh

echo "🌅 Good morning! Starting your work environment..."

# Start VMs in order
WORK_VMS=("ubuntu-desktop" "windows-dev" "test-server")

for vm in "${WORK_VMS[@]}"; do
  if virsh list --all | grep -q "$vm.*shut off"; then
    echo "  ▶ Starting: $vm"
    virsh start "$vm"
    sleep 5  # Stagger for resource management
  fi
done

# Wait for all to boot
echo "  ⏳ Waiting for VMs to boot (30s)..."
sleep 30

# Show dashboard
echo ""
echo "✓ Environment ready! Opening dashboard..."
/etc/hypervisor/scripts/vm_dashboard.sh --interval 10
```

**Add to shell profile:**
```bash
# In ~/.bashrc or ~/.bash_profile
alias morning='/etc/hypervisor/scripts/morning-startup.sh'

# Then just run:
morning
```

### Scenario 2: Pre-Update Safety

**Goal:** Snapshot all VMs before system update

**Script:**
```bash
#!/usr/bin/env bash
# pre-update-backup.sh

SNAPSHOT_NAME="pre-update-$(date +%Y%m%d)"

echo "📸 Creating pre-update snapshots: $SNAPSHOT_NAME"

virsh list --all --name | grep -v '^$' | while read vm; do
  echo "  Snapshotting: $vm"
  
  virsh snapshot-create-as "$vm" \
    "$SNAPSHOT_NAME" \
    "Before system update $(date)" \
    --disk-only --atomic || true
done

echo ""
echo "✓ All VMs snapshotted"
echo ""
echo "Safe to proceed with system update!"
echo ""
echo "To rollback later:"
echo "  virsh snapshot-revert VM-NAME $SNAPSHOT_NAME"
```

### Scenario 3: Weekly Maintenance

**Goal:** Clean up and optimize weekly

**Script:**
```bash
#!/usr/bin/env bash
# weekly-maintenance.sh

echo "🔧 Weekly hypervisor maintenance starting..."
echo ""

# 1. Clean old logs
echo "1. Cleaning old logs..."
find /var/lib/hypervisor/logs -name "*.log.*" -mtime +30 -delete
echo "  ✓ Logs cleaned"

# 2. Remove old snapshots
echo ""
echo "2. Removing old snapshots (>30 days)..."
virsh list --all --name | grep -v '^$' | while read vm; do
  virsh snapshot-list "$vm" --name 2>/dev/null | while read snapshot; do
    # Check snapshot age (implementation depends on naming)
    echo "  Checked: $vm -> $snapshot"
  done
done
echo "  ✓ Old snapshots removed"

# 3. Optimize disk images
echo ""
echo "3. Optimizing disk images..."
for disk in /var/lib/hypervisor/disks/*.qcow2; do
  [[ -f "$disk" ]] || continue
  echo "  Optimizing: $(basename "$disk")"
  # Only optimize stopped VMs
  qemu-img check "$disk" || true
done
echo "  ✓ Disks checked"

# 4. Generate report
echo ""
echo "4. Generating health report..."
/etc/hypervisor/scripts/diagnose.sh > "/var/lib/hypervisor/reports/weekly-$(date +%Y%m%d).txt"
echo "  ✓ Report saved"

echo ""
echo "✓ Weekly maintenance complete"
```

**Schedule:**
```bash
# Systemd timer for Sunday at 3 AM
systemd.timers.weekly-maintenance = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "Sun *-*-* 03:00:00";
  };
};
```

---

## Automation Patterns

### Pattern: Idempotent Operations

**Goal:** Safe to run multiple times

```bash
# Good - idempotent
start_vm_if_stopped() {
  local vm="$1"
  
  if virsh domstate "$vm" 2>/dev/null | grep -q "shut off"; then
    virsh start "$vm"
    echo "Started: $vm"
  else
    echo "Already running: $vm"
  fi
}

# Bad - not idempotent
start_vm() {
  virsh start "$vm"  # Fails if already running!
}
```

### Pattern: Error Handling

**Goal:** Graceful degradation

```bash
# Good - handles errors
backup_vm() {
  local vm="$1"
  local backup_dir="/var/lib/hypervisor/backups"
  
  if virsh snapshot-create-as "$vm" "backup-$(date +%Y%m%d)"; then
    echo "✓ Backup created: $vm"
    return 0
  else
    echo "✗ Backup failed: $vm" >&2
    logger -t hypervisor-backup "Failed to backup $vm"
    return 1
  fi
}

# Call with error handling
if backup_vm "important-vm"; then
  echo "Continue with next step..."
else
  echo "Backup failed, skipping risky operation"
  exit 1
fi
```

### Pattern: Dry Run Mode

**Goal:** Preview before executing

```bash
#!/usr/bin/env bash
DRY_RUN="${DRY_RUN:-false}"

execute() {
  local cmd="$*"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Would execute: $cmd"
  else
    echo "Executing: $cmd"
    eval "$cmd"
  fi
}

# Usage
execute virsh start my-vm

# Test first with:
DRY_RUN=true ./script.sh

# Then run for real:
./script.sh
```

### Pattern: Progress Reporting

**Goal:** User knows what's happening

```bash
with_progress() {
  local total=$1
  local current=0
  shift
  
  for item in "$@"; do
    ((current++))
    echo "[$current/$total] Processing: $item"
    
    # Do work
    process_item "$item"
    
    # Show progress bar
    local percent=$((current * 100 / total))
    printf "\rProgress: ["
    printf "%${percent}s" | tr ' ' '='
    printf "%$((100-percent))s" | tr ' ' ' '
    printf "] %d%%\n" "$percent"
  done
  
  echo "✓ Complete!"
}

# Usage
with_progress 3 vm1 vm2 vm3
```

---

## Best Practices

### 1. Make Scripts Educational

**Show what's happening:**
```bash
# Good - educational
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating VM Snapshot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What we're doing:"
echo "  • Creating point-in-time snapshot"
echo "  • Name: $SNAPSHOT_NAME"
echo "  • VM: $VM_NAME"
echo ""
echo "Why this matters:"
echo "  • Can restore to this exact state later"
echo "  • Useful before risky changes"
echo "  • Quick recovery if something breaks"
echo ""
echo "Working..."

# Bad - silent
virsh snapshot-create-as "$VM_NAME" "$SNAPSHOT_NAME"
```

### 2. Provide Dry Run

```bash
# Always allow testing
./script.sh --dry-run  # See what would happen
./script.sh            # Actually do it
```

### 3. Log Everything

```bash
LOG_FILE="/var/lib/hypervisor/logs/automation.log"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

log "Starting automated task"
log "Processing VM: $vm_name"
log "Task complete"
```

### 4. Handle Failures Gracefully

```bash
# Don't crash, report and continue
for vm in $VMS; do
  if ! start_vm "$vm"; then
    echo "⚠️  Failed to start $vm, continuing..." >&2
    FAILED_VMS+=("$vm")
  fi
done

# Report failures at end
if [[ ${#FAILED_VMS[@]} -gt 0 ]]; then
  echo ""
  echo "Failed VMs: ${FAILED_VMS[*]}"
  echo "Check logs for details"
fi
```

### 5. Make Scripts Discoverable

```bash
# Add --help to every script
if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
Script Name v1.0

Purpose: What this script does
Usage: $0 [OPTIONS]

Options:
  --dry-run   Preview actions
  --verbose   Show detailed output
  --help      This help message

Examples:
  $0                  # Normal run
  $0 --dry-run        # Test mode
  $0 --verbose        # Debug mode

Author: Your Name
See also: related-script.sh
EOF
  exit 0
fi
```

---

## Integration Examples

### With Monitoring

```bash
# Trigger actions based on metrics

# Check Prometheus for high load
LOAD=$(curl -s 'http://localhost:9090/api/v1/query?query=hypervisor_load_average{period="5m"}' | \
  jq -r '.data.result[0].value[1]')

if (( $(echo "$LOAD > 4" | bc -l) )); then
  echo "High load detected: $LOAD"
  # Stop non-essential VMs
  virsh shutdown test-vm
fi
```

### With Backup Systems

```bash
# Integration with Borg Backup

# After creating snapshot
virsh snapshot-create-as "$VM" "backup-$(date +%Y%m%d)"

# Export disk
qemu-img convert -O raw /var/lib/hypervisor/disks/$VM.qcow2 /tmp/$VM.raw

# Backup with Borg
borg create /mnt/backup::${VM}-$(date +%Y%m%d) /tmp/$VM.raw

# Cleanup
rm /tmp/$VM.raw
```

### With CI/CD

```bash
# Deploy new VM for testing in CI

# .github/workflows/integration-test.yml
- name: Create test VM
  run: |
    cat > test-vm.json <<EOF
    {"name": "ci-test-${{github.run_id}}", "cpus": 2, "memory_mb": 2048}
    EOF
    
    /etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh test-vm.json
    
    # Run tests
    pytest tests/
    
    # Cleanup
    virsh destroy ci-test-${{github.run_id}}
    virsh undefine ci-test-${{github.run_id}}
```

---

## Quick Reference

### Common Automation Tasks

```bash
# Start all VMs
virsh list --inactive --name | while read vm; do
  [[ -n "$vm" ]] && virsh start "$vm"
done

# Stop all VMs
virsh list --name | while read vm; do
  [[ -n "$vm" ]] && virsh shutdown "$vm"
done

# Snapshot all VMs
virsh list --all --name | while read vm; do
  [[ -n "$vm" ]] && virsh snapshot-create-as "$vm" "snapshot-$(date +%Y%m%d)"
done

# Get all VM IPs
virsh list --name | while read vm; do
  [[ -n "$vm" ]] && echo "$vm: $(virsh domifaddr "$vm" | awk 'NR==3{print $4}')"
done

# List VMs by state
virsh list --all | awk 'NR>2 && $3=="running" {print $2}'
```

---

## Learning Resources

- **Interactive Tutorial** - `/etc/hypervisor/scripts/interactive_tutorial.sh`
- **Tool Guide** - `/etc/hypervisor/docs/TOOL_GUIDE.md`
- **Examples** - Above patterns and scenarios
- **Workflows** - `/etc/hypervisor/docs/workflows.txt`

---

**Remember: Good automation teaches while it works. Add explanations, show progress, log actions, and handle errors gracefully.**
