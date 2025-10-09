#!/usr/bin/env bash
# Apply per-VM resource limits by creating a slice and moving QEMU PID into it.
set -euo pipefail

domain="$1"
cpulimit="${2:-200%}"
memmax="${3:-8G}"

# Find QEMU PID for domain
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

# Move PID into slice
echo "vm-${domain}.slice" > "/proc/${pid}/cgroup" || true
