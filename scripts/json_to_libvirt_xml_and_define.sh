#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

PROFILE_JSON="$1"
STATE_DIR="/var/lib/hypervisor"
XML_DIR="$STATE_DIR/xml"
DISKS_DIR="$STATE_DIR/disks"
ISOS_DIR="/etc/hypervisor/isos"

mkdir -p "$XML_DIR" "$DISKS_DIR"

require() {
  for b in jq virsh; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done
}

xml_escape() {
  # Escapes &, <, >, ' and " for XML text nodes/attributes
  sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' \
      -e "s/'/\&apos;/g"
}
require

raw_name=$(jq -r '.name' "$PROFILE_JSON")
# Constrain name to safe subset for domain names (defense-in-depth)
if [[ ! "$raw_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  name=$(echo "$raw_name" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
else
  name="$raw_name"
fi
cpus=$(jq -r '.cpus' "$PROFILE_JSON")
memory_mb=$(jq -r '.memory_mb' "$PROFILE_JSON")
disk_gb=$(jq -r '.disk_gb // 20' "$PROFILE_JSON")
iso_path=$(jq -r '.iso_path // empty' "$PROFILE_JSON")
bridge=$(jq -r '.network.bridge // empty' "$PROFILE_JSON")
# hostdev passthrough list e.g. ["0000:01:00.0","0000:01:00.1"]
mapfile -t hostdevs < <(jq -r '.hostdevs[]? // empty' "$PROFILE_JSON")
hugepages=$(jq -r '.hugepages // false' "$PROFILE_JSON")
audio_model=$(jq -r '.audio.model // empty' "$PROFILE_JSON")
video_heads=$(jq -r '.video.heads // 1' "$PROFILE_JSON")
looking_glass_enabled=$(jq -r '.looking_glass.enable // false' "$PROFILE_JSON")
looking_glass_size=$(jq -r '.looking_glass.size_mb // 64' "$PROFILE_JSON")
# cpu_pinning: array of host cpu ids, sequentially mapped to vcpus
mapfile -t pin_array < <(jq -r '.cpu_pinning[]? // empty' "$PROFILE_JSON")
# numatune
numa_nodeset=$(jq -r '.numa.nodeset // empty' "$PROFILE_JSON")
# memballoon
memballoon_disable=$(jq -r '.memballoon.disable // false' "$PROFILE_JSON")
# tpm
tpm_enable=$(jq -r '.tpm.enable // false' "$PROFILE_JSON")
# vhost-net
vhost_net=$(jq -r '.network.vhost // false' "$PROFILE_JSON")
# autostart
autostart=$(jq -r '.autostart // false' "$PROFILE_JSON")

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
v_name=$(printf '%s' "$name" | xml_escape)
xml="$XML_DIR/${name}.xml"
cat > "$xml" <<XML
<domain type='kvm'>
  <name>${v_name}</name>
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

if [[ -n "$numa_nodeset" && "$numa_nodeset" != "null" ]]; then
  cat >> "$xml" <<XML
  <numatune>
    <memory mode='strict' nodeset='$(printf '%s' "$numa_nodeset" | xml_escape)'/>
  </numatune>
XML
fi

cat >> "$xml" <<XML
  <devices>
    <emulator>/run/current-system/sw/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$(printf '%s' "$qcow" | xml_escape)'/>
      <target dev='vda' bus='virtio'/>
    </disk>
XML

if [[ -n "${iso_path:-}" ]]; then
  v_iso=$(printf '%s' "$iso_path" | xml_escape)
  cat >> "$xml" <<XML
    <disk type='file' device='cdrom'>
      <source file='${v_iso}'/>
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
      <source bridge='$(printf '%s' "$bridge" | xml_escape)'/>
      <model type='virtio'/>
      $( [[ "$vhost_net" == "true" || "$vhost_net" == "True" ]] && echo "<driver name='vhost'/>" )
    </interface>
XML
else
  cat >> "$xml" <<XML
    <interface type='user'>
      <model type='virtio'/>
    </interface>
XML
fi

# Optional PCI passthrough devices
for bdf in "${hostdevs[@]:-}"; do
  [[ -z "$bdf" ]] && continue
  if [[ ! "$bdf" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
    echo "Skipping invalid PCI BDF: $bdf" >&2
    continue
  fi
  cat >> "$xml" <<XML
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x${bdf:0:4}' bus='0x${bdf:5:2}' slot='0x${bdf:8:2}' function='0x${bdf:11:1}'/>
      </source>
    </hostdev>
XML
done

# Optional memballoon (enabled by default unless disabled)
if [[ "$memballoon_disable" != "true" && "$memballoon_disable" != "True" ]]; then
  cat >> "$xml" <<XML
    <memballoon model='virtio'/>
XML
fi

# Optional TPM 2.0 emulator
if [[ "$tpm_enable" == "true" || "$tpm_enable" == "True" ]]; then
  cat >> "$xml" <<XML
    <tpm model='tpm-tis'>
      <backend type='emulator' version='2.0'/>
    </tpm>
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
if [[ "$autostart" == "true" || "$autostart" == "True" ]]; then
  virsh autostart "$name" || true
fi
