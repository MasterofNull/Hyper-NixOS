#!/usr/bin/env bash
set -euo pipefail

PROFILE_JSON="$1"
STATE_DIR="/var/lib/hypervisor"
XML_DIR="$STATE_DIR/xml"
DISKS_DIR="$STATE_DIR/disks"
ISOS_DIR="/etc/hypervisor/isos"

mkdir -p "$XML_DIR" "$DISKS_DIR"

require() {
  for b in jq virsh; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done
}
require

name=$(jq -r '.name' "$PROFILE_JSON")
cpus=$(jq -r '.cpus' "$PROFILE_JSON")
memory_mb=$(jq -r '.memory_mb' "$PROFILE_JSON")
disk_gb=$(jq -r '.disk_gb // 20' "$PROFILE_JSON")
iso_path=$(jq -r '.iso_path // empty' "$PROFILE_JSON")
bridge=$(jq -r '.network.bridge // empty' "$PROFILE_JSON")

# Prepare disk if not present
qcow="$DISKS_DIR/${name}.qcow2"
if [[ ! -f "$qcow" ]]; then
  qemu-img create -f qcow2 "$qcow" "${disk_gb}G" >/dev/null
fi

# Resolve ISO
if [[ -n "$iso_path" && ! -f "$iso_path" ]]; then
  # if relative, resolve from ISOS_DIR
  if [[ "$iso_path" != /* ]]; then
    iso_path="$ISOS_DIR/$iso_path"
  fi
fi

# Build XML
xml="$XML_DIR/${name}.xml"
cat > "$xml" <<XML
<domain type='kvm'>
  <name>${name}</name>
  <memory unit='MiB'>${memory_mb}</memory>
  <vcpu placement='static'>${cpus}</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <loader readonly='yes' type='pflash'>/run/current-system/sw/share/OVMF/OVMF_CODE.fd</loader>
    <nvram>/var/lib/hypervisor/${name}.OVMF_VARS.fd</nvram>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough'/>
  <devices>
    <emulator>/run/current-system/sw/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='${qcow}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
XML

if [[ -n "${iso_path:-}" ]]; then
  cat >> "$xml" <<XML
    <disk type='file' device='cdrom'>
      <source file='${iso_path}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
XML
fi

cat >> "$xml" <<XML
    <graphics type='spice' autoport='yes' listen='127.0.0.1'/>
    <video>
      <model type='virtio'/>
    </video>
    <input type='tablet' bus='usb'/>
XML

if [[ -n "${bridge:-}" ]]; then
  cat >> "$xml" <<XML
    <interface type='bridge'>
      <source bridge='${bridge}'/>
      <model type='virtio'/>
    </interface>
XML
else
  cat >> "$xml" <<XML
    <interface type='user'>
      <model type='virtio'/>
    </interface>
XML
fi

cat >> "$xml" <<XML
  </devices>
</domain>
XML

# Ensure OVMF VARS exists per-VM
if [[ ! -f "$STATE_DIR/${name}.OVMF_VARS.fd" ]]; then
  cp /run/current-system/sw/share/OVMF/OVMF_VARS.fd "$STATE_DIR/${name}.OVMF_VARS.fd" || true
fi

# Define and start
virsh destroy "$name" >/dev/null 2>&1 || true
virsh undefine "$name" --remove-all-storage >/dev/null 2>&1 || true
virsh define "$xml"
virsh start "$name"
