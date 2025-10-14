#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" jq virsh awk free df

host_metrics() {
  echo "Host Metrics"; echo
  echo "CPU:"; awk -v FS=' ': '/^cpu /{printf("user=%s nice=%s system=%s idle=%s iowait=%s\n",$2,$3,$4,$5,$6)}' /proc/stat
  echo
  echo "Memory:"; free -h
  echo
  echo "Disks:"; df -h /var/lib/hypervisor
}

vm_metrics() {
  echo; echo "VM Metrics"; echo
  while IFS= read -r dom; do
    [[ -z "$dom" ]] && continue
    echo "- $dom"
    virsh dominfo "$dom" | sed 's/^/  /'
  done < <(virsh list --name)
}

out=$(mktemp)
{ host_metrics; vm_metrics; } > "$out"
${PAGER:-less} "$out"
rm -f "$out"
