#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <vm_profile.json>" >&2
  exit 1
fi

PROFILE_JSON="$1"
if [[ ! -f "$PROFILE_JSON" ]]; then
  echo "Profile not found: $PROFILE_JSON" >&2
  exit 1
fi

name=$(jq -r '.name' "$PROFILE_JSON")
cpus=$(jq -r '.cpus' "$PROFILE_JSON")
memory_mb=$(jq -r '.memory_mb' "$PROFILE_JSON")
disk_gb=$(jq -r '.disk_gb' "$PROFILE_JSON")
iso_path=$(jq -r '.iso_path' "$PROFILE_JSON")

if [[ -z "$name" || -z "$cpus" || -z "$memory_mb" || -z "$disk_gb" || -z "$iso_path" ]]; then
  echo "Missing required fields in JSON" >&2
  exit 1
fi

cat <<XML
<domain type='kvm'>
  <name>$name</name>
  <memory unit='MiB'>$memory_mb</memory>
  <vcpu placement='static'>$cpus</vcpu>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <boot dev='cdrom'/>
  </os>
  <devices>
    <disk type='file' device='cdrom'>
      <source file='$iso_path'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <graphics type='vnc' port='-1'/>
  </devices>
</domain>
XML
