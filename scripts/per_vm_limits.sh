#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Purpose: Legacy manual per-VM limit applier (deprecated)
# Note: Libvirt hook now applies limits automatically from JSON profiles.
# Usage: per_vm_limits.sh <domain> [cpu_quota] [mem_max]
set -euo pipefail

domain="${1:-}"
cpulimit="${2:-200%}"
memmax="${3:-8G}"

if [[ -z "$domain" ]]; then
  echo "Usage: $(basename "$0") <domain> [cpu_quota] [mem_max]" >&2
  exit 2
fi

# Find QEMU PID for domain (best-effort)
pid=$(pgrep -f "qemu-system-.*-name $domain" | head -n1 || true)
if [[ -z "${pid:-}" ]]; then
  echo "Cannot find QEMU PID for $domain" >&2
  exit 1
fi

# Create a transient slice
systemd-run --unit="vm-${domain}.slice" \
  --slice=machine.slice \
  -p CPUAccounting=yes -p MemoryAccounting=yes -p IOAccounting=yes \
  -p CPUQuota=${cpulimit} -p MemoryMax=${memmax} \
  /bin/true

# Move PID into slice (Note: moving PIDs directly is fragile; hook approach is preferred)
echo "vm-${domain}.slice" > "/proc/${pid}/cgroup" || true
