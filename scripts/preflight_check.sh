#!/usr/bin/env bash
# Pre-flight checks before critical operations
# Validates system is ready for VM operations, ISO downloads, etc.

set -Eeuo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

OPERATION="${1:-general}"
REQUIRED_SPACE_GB="${2:-10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() {
  echo -e "${RED}✗${NC} $*" >&2
}

warn() {
  echo -e "${YELLOW}⚠${NC} $*" >&2
}

ok() {
  echo -e "${GREEN}✓${NC} $*"
}

# Check if we can proceed
CAN_PROCEED=true

check_disk_space() {
  local required_gb="$1"
  local path="${2:-/var/lib/hypervisor}"
  
  local avail_gb=$(df -BG "$path" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
  
  if [[ -z "$avail_gb" ]]; then
    error "Cannot determine disk space for $path"
    CAN_PROCEED=false
    return 1
  fi
  
  if [[ $avail_gb -lt $required_gb ]]; then
    error "Insufficient disk space: ${avail_gb}GB available, ${required_gb}GB required"
    warn "Free up space with: sudo virsh snapshot-delete <vm> <snapshot>"
    warn "Or clean old VMs: sudo virsh undefine <vm>"
    CAN_PROCEED=false
    return 1
  fi
  
  ok "Disk space: ${avail_gb}GB available"
  return 0
}

check_memory() {
  local required_mb="$1"
  
  local avail_mb=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
  
  if [[ $avail_mb -lt $required_mb ]]; then
    error "Insufficient memory: ${avail_mb}MB available, ${required_mb}MB required"
    warn "Close some applications or reduce VM memory allocation"
    CAN_PROCEED=false
    return 1
  fi
  
  ok "Memory: ${avail_mb}MB available"
  return 0
}

check_cpu() {
  local required_cpus="$1"
  
  local total_cpus=$(nproc)
  local used_cpus=$(virsh list --name 2>/dev/null | while read vm; do
    [[ -z "$vm" ]] && continue
    virsh vcpucount "$vm" --current 2>/dev/null || echo 0
  done | awk '{sum+=$1} END {print sum+0}')
  
  local avail_cpus=$((total_cpus - used_cpus))
  
  if [[ $avail_cpus -lt $required_cpus ]]; then
    warn "Limited CPU resources: ${avail_cpus} available, ${required_cpus} requested"
    warn "Total: $total_cpus CPUs, In use: $used_cpus CPUs"
    # Don't fail, just warn
  else
    ok "CPU: ${avail_cpus}/${total_cpus} CPUs available"
  fi
  
  return 0
}

check_kvm() {
  if [[ ! -e /dev/kvm ]]; then
    error "/dev/kvm not found - KVM not available"
    warn "Load KVM module: sudo modprobe kvm kvm_intel (or kvm_amd)"
    CAN_PROCEED=false
    return 1
  fi
  
  if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    error "/dev/kvm not accessible"
    warn "Check permissions: sudo chmod 666 /dev/kvm"
    CAN_PROCEED=false
    return 1
  fi
  
  ok "/dev/kvm: accessible"
  return 0
}

check_libvirt() {
  if ! systemctl is-active --quiet libvirtd; then
    error "libvirtd is not running"
    warn "Start libvirtd: sudo systemctl start libvirtd"
    CAN_PROCEED=false
    return 1
  fi
  
  if ! virsh list >/dev/null 2>&1; then
    error "Cannot connect to libvirt"
    CAN_PROCEED=false
    return 1
  fi
  
  ok "libvirtd: running and accessible"
  return 0
}

check_network() {
  # Check basic connectivity
  if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    warn "No internet connectivity (ISO downloads will fail)"
    # Don't fail on network issues for local operations
    return 1
  fi
  
  ok "Network: internet accessible"
  return 0
}

check_storage_pool() {
  if ! virsh pool-info default >/dev/null 2>&1; then
    warn "Storage pool 'default' not found"
    warn "VMs will use /var/lib/hypervisor/disks directly"
    return 1
  fi
  
  local pool_state=$(virsh pool-info default 2>/dev/null | awk '/State:/ {print $2}')
  if [[ "$pool_state" != "running" ]]; then
    warn "Storage pool 'default' is not active"
    warn "Start it with: virsh pool-start default"
    return 1
  fi
  
  ok "Storage pool: active"
  return 0
}

check_vm_name_unique() {
  local vm_name="$1"
  
  if virsh dominfo "$vm_name" >/dev/null 2>&1; then
    error "VM '$vm_name' already exists"
    warn "Choose a different name or delete the existing VM"
    CAN_PROCEED=false
    return 1
  fi
  
  ok "VM name '$vm_name': available"
  return 0
}

check_iso_exists() {
  local iso_path="$1"
  
  if [[ ! -f "$iso_path" ]]; then
    error "ISO file not found: $iso_path"
    warn "Download an ISO first using the ISO manager"
    CAN_PROCEED=false
    return 1
  fi
  
  ok "ISO file: found"
  return 0
}

check_iso_verified() {
  local iso_path="$1"
  
  if [[ -f "${iso_path}.sha256.verified" ]]; then
    ok "ISO: verified"
    return 0
  else
    warn "ISO not verified - checksum not validated"
    warn "Use ISO manager to verify: virsh iso-manager verify"
    return 1
  fi
}

# Operation-specific checks
case "$OPERATION" in
  vm-create)
    echo "Pre-flight checks for VM creation..."
    check_kvm
    check_libvirt
    check_disk_space "${REQUIRED_SPACE_GB:-20}"
    
    # These will be passed as additional args
    VM_NAME="${3:-}"
    VM_MEMORY="${4:-4096}"
    VM_CPUS="${5:-2}"
    ISO_PATH="${6:-}"
    
    if [[ -n "$VM_NAME" ]]; then
      check_vm_name_unique "$VM_NAME"
    fi
    
    check_memory "$VM_MEMORY"
    check_cpu "$VM_CPUS"
    
    if [[ -n "$ISO_PATH" && "$ISO_PATH" != "null" ]]; then
      check_iso_exists "$ISO_PATH"
      check_iso_verified "$ISO_PATH" || true  # Don't fail on unverified
    fi
    
    check_storage_pool || true  # Don't fail if pool doesn't exist
    ;;
    
  vm-start)
    echo "Pre-flight checks for VM start..."
    check_kvm
    check_libvirt
    
    VM_NAME="${3:-}"
    if [[ -n "$VM_NAME" ]]; then
      if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
        error "VM '$VM_NAME' does not exist"
        CAN_PROCEED=false
      else
        ok "VM '$VM_NAME': exists"
        
        # Check if already running
        local state=$(virsh domstate "$VM_NAME" 2>/dev/null)
        if [[ "$state" == "running" ]]; then
          warn "VM '$VM_NAME' is already running"
          CAN_PROCEED=false
        fi
      fi
    fi
    ;;
    
  iso-download)
    echo "Pre-flight checks for ISO download..."
    check_disk_space "${REQUIRED_SPACE_GB:-5}" "/var/lib/hypervisor/isos"
    check_network || {
      error "Internet connection required for ISO download"
      CAN_PROCEED=false
    }
    ;;
    
  backup)
    echo "Pre-flight checks for backup..."
    check_libvirt
    
    VM_NAME="${3:-}"
    BACKUP_DIR="${4:-/var/lib/hypervisor/backups}"
    
    if [[ -n "$VM_NAME" ]]; then
      if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
        error "VM '$VM_NAME' does not exist"
        CAN_PROCEED=false
      else
        # Estimate backup size (VM memory + disk)
        local vm_mem_kb=$(virsh dominfo "$VM_NAME" | awk '/Max memory:/ {print $3}')
        local vm_mem_gb=$((vm_mem_kb / 1024 / 1024 + 1))
        
        # Get disk sizes
        local disk_total_gb=0
        while read disk_path; do
          [[ -z "$disk_path" ]] && continue
          local disk_size=$(qemu-img info "$disk_path" 2>/dev/null | awk '/virtual size:/ {print $3}' | tr -d 'G')
          disk_total_gb=$((disk_total_gb + ${disk_size%%.*}))
        done < <(virsh domblklist "$VM_NAME" --details 2>/dev/null | awk '/file/ {print $4}')
        
        local required_gb=$((vm_mem_gb + disk_total_gb + 1))
        check_disk_space "$required_gb" "$BACKUP_DIR"
      fi
    fi
    ;;
    
  snapshot)
    echo "Pre-flight checks for snapshot..."
    check_libvirt
    
    VM_NAME="${3:-}"
    if [[ -n "$VM_NAME" ]]; then
      if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
        error "VM '$VM_NAME' does not exist"
        CAN_PROCEED=false
      else
        # Check snapshot count
        local snap_count=$(virsh snapshot-list "$VM_NAME" --name 2>/dev/null | wc -l)
        if [[ $snap_count -ge 10 ]]; then
          warn "VM has $snap_count snapshots (consider cleanup)"
          warn "Delete old snapshots with: virsh snapshot-delete $VM_NAME <snapshot>"
        fi
        
        # Estimate snapshot size
        local disk_gb=0
        while read disk_path; do
          [[ -z "$disk_path" ]] && continue
          local size=$(qemu-img info "$disk_path" 2>/dev/null | awk '/virtual size:/ {print $3}' | tr -d 'G')
          disk_gb=$((disk_gb + ${size%%.*}))
        done < <(virsh domblklist "$VM_NAME" --details 2>/dev/null | awk '/file/ {print $4}')
        
        check_disk_space "$disk_gb" "/var/lib/hypervisor/disks"
      fi
    fi
    ;;
    
  general|*)
    echo "General pre-flight checks..."
    check_kvm || true
    check_libvirt || true
    check_disk_space 10 || true
    check_network || true
    ;;
esac

echo ""
if $CAN_PROCEED; then
  ok "All critical checks passed - ready to proceed"
  exit 0
else
  error "Pre-flight checks failed - cannot proceed safely"
  echo ""
  echo "Fix the issues above and try again"
  echo "For help, run: /etc/hypervisor/scripts/diagnose.sh"
  exit 1
fi
