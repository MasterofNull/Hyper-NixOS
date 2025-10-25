#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() { printf "[FAIL] %s\n" "$1"; }

checks() {
  # Libvirt running
  systemctl is-active --quiet libvirtd && ok "libvirtd active" || fail "libvirtd not active"
  # Bridges exist
  for br in $(jq -r '.network_zones[]?.bridge' /etc/hypervisor/config.json 2>/dev/null || true); do
    ip link show "$br" >/dev/null 2>&1 && ok "bridge $br exists" || warn "bridge $br missing"
  done
  # Storage dirs
  for d in /var/lib/hypervisor/{disks,xml,vm-profiles,isos}; do
    [[ -d "$d" ]] && ok "$d present" || warn "$d missing"
  done
}

out=$(mktemp); checks > "$out"; ${PAGER:-less} "$out"; rm -f "$out"
