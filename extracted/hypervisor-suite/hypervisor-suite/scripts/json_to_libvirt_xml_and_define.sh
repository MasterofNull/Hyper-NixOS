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
hugepages=$(jq -r '.hugepages // false' "$PROFILE_JSON")
audio_model=$(jq -r '.audio.model // empty' "$PROFILE_JSON")
video_heads=$(jq -r '.video.heads // 1' "$PROFILE_JSON")
looking_glass_enabled=$(jq -r '.looking_glass.enable // false' "$PROFILE_JSON")
looking_glass_size=$(jq -r '.looking_glass.size_mb // 64' "$PROFILE_JSON")
# cpu_pinning: array of host cpu ids, sequentially mapped to vcpus
mapfile -t pin_array < <(jq -r '.cpu_pinning[]? // empty' "$PROFILE_JSON")

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
XML

# Optional hugepages backing
if [[ "$hugepages" == "true" || "$hugepages" == "True" ]]; then
  cat >> "$xml" <<XML
  <memoryBacking>
    <hugepages/>
  </memoryBacking>
XML
fi

# Optional CPU pinning
if (( ${#pin_array[@]} > 0 )); then
  {
    echo "  <cputune>"
    for ((i=0;i<cpus;i++)); do
      host_cpu=${pin_array[$(( i % ${#pin_array[@]} ))]}
      echo "    <vcpupin vcpu='${i}' cpuset='${host_cpu}'/>"
    done
    echo "  </cputune>"
  } >> "$xml"
fi

cat >> "$xml" <<XML
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
      <model type='virtio' heads='${video_heads}'/>
    </video>
    <input type='tablet' bus='usb'/>
XML

# Optional audio device
if [[ -n "$audio_model" && "$audio_model" != "null" ]]; then
  cat >> "$xml" <<XML
    <sound model='${audio_model}'/>
XML
fi

# Optional Looking Glass shared memory
if [[ "$looking_glass_enabled" == "true" || "$looking_glass_enabled" == "True" ]]; then
  cat >> "$xml" <<XML
    <shmem name='looking-glass'>
      <model type='ivshmem-plain'/>
      <size unit='M'>${looking_glass_size}</size>
    </shmem>
XML
fi

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
