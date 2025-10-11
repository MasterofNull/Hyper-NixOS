#!/usr/bin/env bash
# Purpose: Convert a VM JSON profile into libvirt XML and define/start it
# Inputs: PROFILE_JSON (path)
# Outputs: domain XML at /var/lib/hypervisor/xml/<name>.xml; domain started via virsh
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
IFS=$'\n\t'
umask 077

PROFILE_JSON="$1"
STATE_DIR="/var/lib/hypervisor"
XML_DIR="$STATE_DIR/xml"
DISKS_DIR="$STATE_DIR/disks"
# Use the stateful ISO library to match menu/ISO manager conventions
ISOS_DIR="/var/lib/hypervisor/isos"
CONFIG_JSON="/etc/hypervisor/config.json"

mkdir -p "$XML_DIR" "$DISKS_DIR"

require() {
  local missing=()
  for b in "$@"; do
    if ! command -v "$b" >/dev/null 2>&1; then
      missing+=("$b")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies: ${missing[*]}" >&2
    echo "" >&2
    echo "To install on NixOS:" >&2
    for dep in "${missing[@]}"; do
      case "$dep" in
        jq) echo "  nix-env -iA nixpkgs.jq" >&2 ;;
        virsh) echo "  Enable virtualisation.libvirtd in configuration.nix" >&2 ;;
        qemu-img) echo "  nix-env -iA nixpkgs.qemu" >&2 ;;
        *) echo "  nix-env -iA nixpkgs.$dep" >&2 ;;
      esac
    done
    exit 1
  fi
}

xml_escape() {
  # Escapes &, <, >, ' and " for XML text nodes/attributes
  sed -e 's/&/\&amp;/g' \
      -e 's/</\&lt;/g' \
      -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' \
      -e "s/'/\&apos;/g"
}
require jq virsh qemu-img

raw_name=$(jq -r '.name' "$PROFILE_JSON")

# Validate VM name: 1-64 chars, alphanumeric + . _ -
# Must not start with . or -
if [[ -z "$raw_name" ]]; then
  echo "Error: VM name cannot be empty" >&2
  exit 1
fi

if [[ ${#raw_name} -gt 64 ]]; then
  echo "Error: VM name too long (max 64 characters): $raw_name" >&2
  exit 1
fi

if [[ ! "$raw_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Error: Invalid VM name: $raw_name" >&2
  echo "Name must start with alphanumeric and contain only: A-Z, a-z, 0-9, ., _, -" >&2
  echo "" >&2
  echo "Examples of valid names:" >&2
  echo "  ubuntu-server" >&2
  echo "  windows11_gaming" >&2
  echo "  test-vm.dev" >&2
  exit 1
fi

name="$raw_name"
cpus=$(jq -r '.cpus' "$PROFILE_JSON")
memory_mb=$(jq -r '.memory_mb' "$PROFILE_JSON")
disk_gb=$(jq -r '.disk_gb // 20' "$PROFILE_JSON")
iso_path=$(jq -r '.iso_path // empty' "$PROFILE_JSON")
disk_image_path=$(jq -r '.disk_image_path // empty' "$PROFILE_JSON")
ci_seed=$(jq -r '.cloud_init.seed_iso_path // empty' "$PROFILE_JSON")
ci_user=$(jq -r '.cloud_init.user_data_path // empty' "$PROFILE_JSON")
ci_meta=$(jq -r '.cloud_init.meta_data_path // empty' "$PROFILE_JSON")
ci_net=$(jq -r '.cloud_init.network_config_path // empty' "$PROFILE_JSON")
bridge=$(jq -r '.network.bridge // empty' "$PROFILE_JSON")
# Optional logical zone name
zone=$(jq -r '.network.zone // empty' "$PROFILE_JSON")
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

# Architecture and advanced CPU/memory options
arch=$(jq -r '.arch // "x86_64"' "$PROFILE_JSON")
# CPU features (x86-centric where applicable)
cf_shstk=$(jq -r '.cpu_features.shstk // false' "$PROFILE_JSON")
cf_ibt=$(jq -r '.cpu_features.ibt // false' "$PROFILE_JSON")
cf_avic=$(jq -r '.cpu_features.avic // false' "$PROFILE_JSON")
cf_secure_avic=$(jq -r '.cpu_features.secure_avic // false' "$PROFILE_JSON")
cf_sev=$(jq -r '.cpu_features.sev // false' "$PROFILE_JSON")
cf_sev_es=$(jq -r '.cpu_features.sev_es // false' "$PROFILE_JSON")
cf_sev_snp=$(jq -r '.cpu_features.sev_snp // false' "$PROFILE_JSON")
cf_ciphertext_hiding=$(jq -r '.cpu_features.ciphertext_hiding // false' "$PROFILE_JSON")
cf_secure_tsc=$(jq -r '.cpu_features.secure_tsc // false' "$PROFILE_JSON")
cf_fred=$(jq -r '.cpu_features.fred // false' "$PROFILE_JSON")
cf_zx_leaves=$(jq -r '.cpu_features.zhaoxin_centaur_leaves // false' "$PROFILE_JSON")
# memory options
mem_guest_memfd=$(jq -r '.memory_options.guest_memfd // false' "$PROFILE_JSON")
mem_private=$(jq -r '.memory_options.private // false' "$PROFILE_JSON")

# Prepare disk if not present; allow base image clone when disk_image_path provided
qcow="$DISKS_DIR/${name}.qcow2"
if [[ ! -f "$qcow" ]]; then
  if [[ -n "$disk_image_path" && -f "$disk_image_path" ]]; then
    # Create a COW overlay referencing the base image
    if ! qemu-img create -f qcow2 -b "$disk_image_path" -F $(qemu-img info -f raw -U "$disk_image_path" >/dev/null 2>&1 && echo raw || echo qcow2) "$qcow" >/dev/null 2>&1; then
      if ! qemu-img create -f qcow2 "$qcow" "${disk_gb}G" >/dev/null 2>&1; then
        echo "Error: Failed to create disk image with backing file" >&2
        echo "  Path: $qcow" >&2
        echo "  Base: $disk_image_path" >&2
        exit 1
      fi
    fi
  else
    if ! qemu-img create -f qcow2 "$qcow" "${disk_gb}G" >/dev/null 2>&1; then
      echo "Error: Failed to create disk image" >&2
      echo "  Path: $qcow" >&2
      echo "  Size: ${disk_gb}G" >&2
      echo "" >&2
      echo "Possible causes:" >&2
      echo "  - Insufficient disk space (check: df -h /var/lib/hypervisor)" >&2
      echo "  - Permission denied (check: ls -ld /var/lib/hypervisor/disks)" >&2
      echo "  - Invalid size (must be > 0)" >&2
      exit 1
    fi
  fi
fi

# Resolve ISO
if [[ -n "$iso_path" && ! -f "$iso_path" ]]; then
  # if relative, resolve from ISOS_DIR
  if [[ "$iso_path" != /* ]]; then
    iso_path="$ISOS_DIR/$iso_path"
  fi
fi

# Verify ISO has been checksummed (security enhancement)
if [[ -n "$iso_path" && -f "$iso_path" ]]; then
  checksum_file="${iso_path}.sha256.verified"
  if [[ ! -f "$checksum_file" ]]; then
    echo "Warning: ISO has not been verified with checksums: $iso_path" >&2
    echo "" >&2
    echo "For security, verify the ISO using the ISO Manager before use." >&2
    echo "Or manually mark as verified (only if you trust the source):" >&2
    echo "  touch '${checksum_file}'" >&2
    echo "" >&2
    if [[ "${HYPERVISOR_REQUIRE_ISO_VERIFICATION:-1}" == "1" ]]; then
      echo "Error: ISO verification is required by security policy." >&2
      echo "To bypass (not recommended), set:" >&2
      echo "  export HYPERVISOR_REQUIRE_ISO_VERIFICATION=0" >&2
      exit 1
    fi
  fi
fi

# Determine emulator/machine/firmware based on arch
emulator="/run/current-system/sw/bin/qemu-system-x86_64"
machine="q35"
os_type_arch="x86_64"
loader_line="<loader readonly='yes' type='pflash'>/run/current-system/sw/share/OVMF/OVMF_CODE.fd</loader>"
nvram_line="<nvram>/var/lib/hypervisor/${name}.OVMF_VARS.fd</nvram>"
vars_src="/run/current-system/sw/share/OVMF/OVMF_VARS.fd"
case "$arch" in
  x86_64)
    emulator="/run/current-system/sw/bin/qemu-system-x86_64" ; machine="q35" ; os_type_arch="x86_64" ;;
  aarch64)
    emulator="/run/current-system/sw/bin/qemu-system-aarch64" ; machine="virt" ; os_type_arch="aarch64"
    if [[ -f /run/current-system/sw/share/AAVMF/AAVMF_CODE.fd ]]; then
      loader_line="<loader readonly='yes' type='pflash'>/run/current-system/sw/share/AAVMF/AAVMF_CODE.fd</loader>"
      nvram_line="<nvram>/var/lib/hypervisor/${name}.AAVMF_VARS.fd</nvram>"
      vars_src="/run/current-system/sw/share/AAVMF/AAVMF_VARS.fd"
    elif [[ -f /run/current-system/sw/share/edk2-armvirt/AAVMF_CODE.fd ]]; then
      loader_line="<loader readonly='yes' type='pflash'>/run/current-system/sw/share/edk2-armvirt/AAVMF_CODE.fd</loader>"
      nvram_line="<nvram>/var/lib/hypervisor/${name}.AAVMF_VARS.fd</nvram>"
      vars_src="/run/current-system/sw/share/edk2-armvirt/AAVMF_VARS.fd"
    else
      loader_line="" ; nvram_line="" ; vars_src=""
    fi
    ;;
  riscv64)
    emulator="/run/current-system/sw/bin/qemu-system-riscv64" ; machine="virt" ; os_type_arch="riscv64" ; loader_line="" ; nvram_line="" ; vars_src="" ;;
  loongarch64)
    emulator="/run/current-system/sw/bin/qemu-system-loongarch64" ; machine="virt" ; os_type_arch="loongarch64" ; loader_line="" ; nvram_line="" ; vars_src="" ;;
esac

# Build XML (prefer vmctl when available)
v_name=$(printf '%s' "$name" | xml_escape)
xml="$XML_DIR/${name}.xml"
if command -v vmctl >/dev/null 2>&1; then
  tmp_xml="$XML_DIR/.tmp-${name}.xml"
  vmctl gen-xml --profile "$PROFILE_JSON" --out "$tmp_xml" || { echo "vmctl failed" >&2; exit 1; }
  mv "$tmp_xml" "$xml"
else
  cat > "$xml" <<XML
<domain type='kvm'>
  <name>${v_name}</name>
  <memory unit='MiB'>${memory_mb}</memory>
  <vcpu placement='static'>${cpus}</vcpu>
  <os>
    <type arch='${os_type_arch}' machine='${machine}'>hvm</type>
    ${loader_line}
    ${nvram_line}
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='partial'>
$( if [[ "$arch" == "x86_64" ]]; then
     [[ "$cf_shstk" == "true" || "$cf_shstk" == "True" ]] && echo "    <feature policy='require' name='shstk'/>"
     [[ "$cf_ibt" == "true" || "$cf_ibt" == "True" ]] && echo "    <feature policy='require' name='ibt'/>"
     [[ "$cf_avic" == "true" || "$cf_avic" == "True" ]] && echo "    <feature policy='require' name='avic'/>"
   fi )
  </cpu>
XML
fi

# Optional memory backing (hugepages, memfd, private)
if [[ "$hugepages" == "true" || "$hugepages" == "True" || "$mem_guest_memfd" == "true" || "$mem_guest_memfd" == "True" || "$mem_private" == "true" || "$mem_private" == "True" ]]; then
  {
    echo "  <memoryBacking>"
    if [[ "$hugepages" == "true" || "$hugepages" == "True" ]]; then
      echo "    <hugepages/>"
    fi
    if [[ "$mem_guest_memfd" == "true" || "$mem_guest_memfd" == "True" ]]; then
      echo "    <source type='memfd'/>"
    fi
    if [[ "$mem_private" == "true" || "$mem_private" == "True" ]]; then
      echo "    <access mode='private'/>"
    fi
    echo "  </memoryBacking>"
  } >> "$xml"
fi

# Optional AMD SEV/SEV-ES/SEV-SNP (basic enable)
if [[ "$arch" == "x86_64" && ( "$cf_sev" == "true" || "$cf_sev" == "True" || "$cf_sev_es" == "true" || "$cf_sev_es" == "True" || "$cf_sev_snp" == "true" || "$cf_sev_snp" == "True" ) ]]; then
  cat >> "$xml" <<XML
  <launchSecurity type='sev'/>
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
    <emulator>${emulator}</emulator>
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

# Optional cloud-init seed ISO
if [[ -z "${ci_seed:-}" && ( -n "${ci_user:-}" || -n "${ci_meta:-}" ) ]]; then
  # Generate seed into state dir
  ci_seed="$DISKS_DIR/${name}-cidata.iso"
  /etc/hypervisor/scripts/cloud_init_seed.sh "$ci_seed" "${ci_user:-}" "${ci_meta:-}" "${ci_net:-}" || true
fi
if [[ -n "${ci_seed:-}" && -f "$ci_seed" ]]; then
  v_seed=$(printf '%s' "$ci_seed" | xml_escape)
  cat >> "$xml" <<XML
    <disk type='file' device='cdrom'>
      <source file='${v_seed}'/>
      <target dev='sdb' bus='sata'/>
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

if [[ -z "${bridge:-}" && -n "${zone:-}" && -f "$CONFIG_JSON" ]]; then
  # Map zone to bridge name via config file: .network_zones.{zone}.bridge
  bridge=$(jq -r --arg z "$zone" '.network_zones?[$z]?.bridge // empty' "$CONFIG_JSON" 2>/dev/null || echo "")
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
  # Guard: if zone is 'untrusted' and not explicitly allowed, skip passthrough
  if [[ -n "${zone:-}" && -f "$CONFIG_JSON" ]]; then
    allow=$(jq -r --arg z "$zone" '.network_zones?[$z]?.allow_hostdev // false' "$CONFIG_JSON" 2>/dev/null || echo false)
    if [[ "$allow" != true && "$allow" != True ]]; then
      echo "Skipping hostdev passthrough in zone '$zone' (not allowed)" >&2
      continue
    fi
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
if [[ -n "$vars_src" && -n "$nvram_line" ]]; then
  # Ensure per-VM firmware VARS exists for architectures that use it
  vm_vars_path=$(sed -n "s#.*<nvram>\(.*\)</nvram>.*#\1#p" "$xml" | head -n1 || true)
  if [[ -n "$vm_vars_path" && ! -f "$vm_vars_path" && -f "$vars_src" ]]; then
    cp "$vars_src" "$vm_vars_path" || true
  fi
fi

# Define and start
# Do not remove storage on re-define; preserve installed disks between edits
virsh destroy "$name" >/dev/null 2>&1 || true
virsh undefine "$name" --nvram >/dev/null 2>&1 || true
if ! virsh define "$xml"; then
  echo "Error: Failed to define VM '$name'" >&2
  echo "  XML file: $xml" >&2
  echo "" >&2
  echo "Possible causes:" >&2
  echo "  - Invalid XML configuration" >&2
  echo "  - Conflicting VM name already exists" >&2
  echo "  - Libvirtd not running (check: systemctl status libvirtd)" >&2
  echo "" >&2
  echo "To debug, check the XML file: cat $xml" >&2
  exit 1
fi

if ! virsh start "$name"; then
  echo "Error: Failed to start VM '$name'" >&2
  echo "" >&2
  echo "Possible causes:" >&2
  echo "  - Insufficient memory available" >&2
  echo "  - KVM not available (check: ls /dev/kvm)" >&2
  echo "  - ISO or disk image not found" >&2
  echo "  - Network bridge not available" >&2
  echo "" >&2
  echo "To debug:" >&2
  echo "  - Check VM definition: virsh dumpxml $name" >&2
  echo "  - Check libvirt logs: journalctl -u libvirtd -n 50" >&2
  exit 1
fi
if [[ "$autostart" == "true" || "$autostart" == "True" ]]; then
  virsh autostart "$name" || true
fi
