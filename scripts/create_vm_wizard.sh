#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM
IFS=$'\n\t'
umask 077

PROFILES_DIR="${1:-/var/lib/hypervisor/vm_profiles}"
ISOS_DIR="${2:-/var/lib/hypervisor/isos}"
# Optional: preselect ISO path and output file for created profile path
PRESELECT_ISO="${PRESELECT_ISO:-${3:-}}"
WIZ_OUT_FILE="${WIZ_OUT_FILE:-}"
: "${DIALOG:=whiptail}"
export DIALOG

require() { for b in jq $DIALOG; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

ask() { $DIALOG --inputbox "$1" 10 60 "$2" 3>&1 1>&2 2>&3; }

WF_DIR="/var/lib/hypervisor/workflows"
mkdir -p "$WF_DIR"
STATE_FILE="$WF_DIR/create_vm_state.json"

# Load defaults
total_mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
avail_mem_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
total_mem_mb=$(( total_mem_kb / 1024 ))
avail_mem_mb=$(( avail_mem_kb / 1024 ))
total_cpus=$(nproc 2>/dev/null || echo 1)

name="my-vm"
cpus="2"
mem="4096"
disk="20"
mem_max="4096"
arch="x86_64"
owner=""
zone=""
audio_model=""
video_heads="1"
hugepages="false"
mem_guest_memfd="false"
mem_private="false"
vhost_net="false"
memballoon_disable="false"
autostart="false"

# Pull defaults from config.json when available
if [[ -f /etc/hypervisor/config.json ]]; then
  huge_default=$(jq -r '.features.hugepages_default // false' /etc/hypervisor/config.json 2>/dev/null || echo false)
  [[ "$huge_default" == "true" || "$huge_default" == "True" ]] && hugepages="true"
fi

save_state() {
  cat > "$STATE_FILE" <<JSON
{
  "name": "$name",
  "owner": "$owner",
  "cpus": $cpus,
  "memory_mb": $mem,
  "disk_gb": $disk,
  "memory_max_mb": $mem_max,
  "iso_path": "${iso_path:-}",
  "arch": "$arch",
  "audio_model": "${audio_model}",
  "video_heads": $video_heads,
  "hugepages": $hugepages,
  "mem_guest_memfd": $mem_guest_memfd,
  "mem_private": $mem_private,
  "vhost_net": $vhost_net,
  "memballoon_disable": $memballoon_disable,
  "autostart": $autostart
}
JSON
}

load_state() {
  [[ -f "$STATE_FILE" ]] || return 1
  name=$(jq -r .name "$STATE_FILE")
  owner=$(jq -r .owner "$STATE_FILE")
  cpus=$(jq -r .cpus "$STATE_FILE")
  mem=$(jq -r .memory_mb "$STATE_FILE")
  disk=$(jq -r .disk_gb "$STATE_FILE")
  mem_max=$(jq -r .memory_max_mb "$STATE_FILE")
  iso_path=$(jq -r .iso_path "$STATE_FILE")
  arch=$(jq -r .arch "$STATE_FILE")
  audio_model=$(jq -r .audio_model "$STATE_FILE")
  video_heads=$(jq -r .video_heads "$STATE_FILE")
  hugepages=$(jq -r .hugepages "$STATE_FILE")
  mem_guest_memfd=$(jq -r .mem_guest_memfd "$STATE_FILE")
  mem_private=$(jq -r .mem_private "$STATE_FILE")
  vhost_net=$(jq -r .vhost_net "$STATE_FILE")
  memballoon_disable=$(jq -r .memballoon_disable "$STATE_FILE")
  autostart=$(jq -r .autostart "$STATE_FILE")
}

# Offer resume if state exists
if [[ -f "$STATE_FILE" ]]; then
  if $DIALOG --yesno "Resume previous Create VM wizard session?" 8 60; then
    load_state || true
  else
    rm -f "$STATE_FILE"
  fi
fi

$DIALOG --msgbox "Host resources detected:\n\nCPUs: ${total_cpus}\nTotal RAM: ${total_mem_mb} MiB\nAvailable RAM: ${avail_mem_mb} MiB" 12 60

# Step inputs
name=$(ask "VM name" "$name") || exit 0; save_state
owner=$(ask "Owner (optional)" "$owner") || exit 0; save_state
cpus=$(ask "vCPUs (host: ${total_cpus})" "$cpus") || exit 0; save_state
mem=$(ask "Memory (MiB) (avail: ${avail_mem_mb}, total: ${total_mem_mb})" "$mem") || exit 0; save_state
disk=$(ask "Disk size (GiB)" "$disk") || exit 0; save_state

# Optional variable memory (soft cap)
if $DIALOG --yesno "Enable variable memory limit (soft cap)?\n\nThis sets a memory_max_mb higher than the initial memory, allowing flexibility." 12 70 ; then
  mem_max=$(ask "Max memory (MiB) (>= ${mem})" "$(( mem + 1024 ))") || exit 0
else
  mem_max=${mem}
fi
save_state

# Architecture
arch=$($DIALOG --menu "Architecture" 12 60 4 x86_64 "x86_64" aarch64 "aarch64" riscv64 "riscv64" loongarch64 "loongarch64" 3>&1 1>&2 2>&3) || arch="x86_64"; save_state

# Optional zone selection (logical security/network domain)
if [[ -f /etc/hypervisor/config.json ]]; then
  mapfile -t zones < <(jq -r '.network_zones? | keys[]?' /etc/hypervisor/config.json 2>/dev/null || true)
  if (( ${#zones[@]} > 0 )); then
    zitems=()
    for z in "${zones[@]}"; do zitems+=("$z" " "); done
    zone=$($DIALOG --menu "Network zone (optional)" 20 60 10 "${zitems[@]}" 3>&1 1>&2 2>&3 || echo "")
    save_state
  fi
fi

# ISO selection with preselect support
shopt -s nullglob
isos=( "$ISOS_DIR"/*.iso )
shopt -u nullglob
if (( ${#isos[@]} == 0 )); then
  $DIALOG --msgbox "No ISOs found in $ISOS_DIR. Use ISO manager first." 10 70
  exit 0
fi
if [[ -n "$PRESELECT_ISO" && -f "$PRESELECT_ISO" ]]; then
  if $DIALOG --yesno "Use preselected ISO?\n$PRESELECT_ISO" 10 70; then
    iso_path="$PRESELECT_ISO"
  fi
fi
if [[ -z "${iso_path:-}" ]]; then
  iso_choices=()
  for f in "${isos[@]}"; do iso_choices+=("$f" " "); done
  iso_path=$($DIALOG --menu "Select ISO" 20 70 10 "${iso_choices[@]}" 3>&1 1>&2 2>&3) || exit 0
fi
save_state

# Advanced options
if $DIALOG --yesno "Configure advanced options (audio, video heads, hugepages, memfd/private, vhost-net, ballooning, autostart)?" 14 78; then
  # Audio
  audio_model=$($DIALOG --menu "Audio device model" 14 60 6 none "None" ich9 "ICH9" ac97 "AC97" es1370 "ES1370" ich6 "ICH6" 3>&1 1>&2 2>&3 || true)
  [[ "$audio_model" == "none" ]] && audio_model=""
  save_state
  # Video heads
  video_heads=$($DIALOG --menu "Video heads" 12 50 4 1 "Single" 2 "Dual" 3 "Triple" 4 "Quad" 3>&1 1>&2 2>&3 || echo 1)
  save_state
  # Hugepages
  if $DIALOG --yesno "Enable Hugepages?" 8 40; then hugepages=true; else hugepages=false; fi
  save_state
  # memfd/private
  if $DIALOG --yesno "Back memory by guest_memfd?" 8 50; then mem_guest_memfd=true; else mem_guest_memfd=false; fi
  save_state
  if $DIALOG --yesno "Request private memory (confidential)?" 8 60; then mem_private=true; else mem_private=false; fi
  save_state
  # network vhost-net
  if $DIALOG --yesno "Enable vhost-net acceleration for virtio-net?" 8 60; then vhost_net=true; else vhost_net=false; fi
  save_state
  # memballoon
  if $DIALOG --yesno "Disable virtio memballoon?" 8 50; then memballoon_disable=true; else memballoon_disable=false; fi
  save_state
  # Autostart
  if $DIALOG --yesno "Autostart this VM on boot?" 8 50; then autostart=true; else autostart=false; fi
  save_state
fi

# Review loop
while true; do
  summary=$(cat <<EOT
Name: $name
Owner: ${owner:-}
Arch: $arch
vCPU: $cpus
RAM: $mem MiB (max $mem_max)
Disk: $disk GiB
ISO: $iso_path
Audio: ${audio_model:-none}
Video heads: $video_heads
Hugepages: $hugepages, memfd: $mem_guest_memfd, private: $mem_private
vhost-net: $vhost_net, memballoon disabled: $memballoon_disable
Autostart: $autostart
EOT
)
  if $DIALOG --yesno "Review configuration:\n\n$summary\n\nProceed to write profile?" 22 78; then
    break
  fi
  # Allow editing fields
  choice=$($DIALOG --menu "Edit which field?" 24 70 14 \
    name "VM name ($name)" \
    owner "Owner (${owner:-})" \
    arch "Architecture ($arch)" \
    cpus "vCPUs ($cpus)" \
    mem "Memory MiB ($mem)" \
    memmax "Memory max MiB ($mem_max)" \
    disk "Disk GiB ($disk)" \
    iso "ISO path" \
    zone "Network zone (${zone:-})" \
    audio "Audio model (${audio_model:-none})" \
    video "Video heads ($video_heads)" \
    huge "Hugepages ($hugepages)" \
    memfd "guest_memfd ($mem_guest_memfd)" \
    private "private mem ($mem_private)" \
    vhost "vhost-net ($vhost_net)" \
    balloon "disable balloon ($memballoon_disable)" \
    autostart "autostart ($autostart)" \
    done "Done" 3>&1 1>&2 2>&3 || echo done)
  case "$choice" in
    name) name=$(ask "VM name" "$name") || true ;;
    arch) arch=$($DIALOG --menu "Architecture" 12 60 4 x86_64 "x86_64" aarch64 "aarch64" riscv64 "riscv64" loongarch64 "loongarch64" 3>&1 1>&2 2>&3) || true ;;
    owner) owner=$(ask "Owner" "$owner") || true ;;
    cpus) cpus=$(ask "vCPUs" "$cpus") || true ;;
    mem) mem=$(ask "Memory (MiB)" "$mem") || true ;;
    memmax) mem_max=$(ask "Max memory (MiB)" "$mem_max") || true ;;
    disk) disk=$(ask "Disk GiB" "$disk") || true ;;
    iso) iso_path=$($DIALOG --inputbox "ISO path" 10 70 "$iso_path" 3>&1 1>&2 2>&3) || true ;;
    zone)
      if [[ -f /etc/hypervisor/config.json ]]; then
        mapfile -t zones < <(jq -r '.network_zones? | keys[]?' /etc/hypervisor/config.json 2>/dev/null || true)
      else
        zones=()
      fi
      if (( ${#zones[@]} > 0 )); then
        zitems=(); for z in "${zones[@]}"; do zitems+=("$z" " "); done
        zone=$($DIALOG --menu "Network zone" 20 60 10 "${zitems[@]}" 3>&1 1>&2 2>&3 || echo "")
      else
        zone=$(ask "Network zone (free-form)" "$zone") || true
      fi
      ;;
    audio) audio_model=$($DIALOG --menu "Audio" 14 60 6 none "None" ich9 "ICH9" ac97 "AC97" es1370 "ES1370" ich6 "ICH6" 3>&1 1>&2 2>&3 || true); [[ "$audio_model" == "none" ]] && audio_model="" ;;
    video) video_heads=$($DIALOG --menu "Video heads" 12 50 4 1 "Single" 2 "Dual" 3 "Triple" 4 "Quad" 3>&1 1>&2 2>&3 || echo 1) ;;
    huge) if $DIALOG --yesno "Enable Hugepages?" 8 40; then hugepages=true; else hugepages=false; fi ;;
    memfd) if $DIALOG --yesno "Enable guest_memfd?" 8 40; then mem_guest_memfd=true; else mem_guest_memfd=false; fi ;;
    private) if $DIALOG --yesno "Enable private memory?" 8 40; then mem_private=true; else mem_private=false; fi ;;
    vhost) if $DIALOG --yesno "Enable vhost-net?" 8 40; then vhost_net=true; else vhost_net=false; fi ;;
    balloon) if $DIALOG --yesno "Disable memballoon?" 8 40; then memballoon_disable=true; else memballoon_disable=false; fi ;;
    autostart) if $DIALOG --yesno "Autostart VM?" 8 40; then autostart=true; else autostart=false; fi ;;
    *) : ;;
  esac
  save_state
done

profile_json="$PROFILES_DIR/${name}.json"
mkdir -p "$PROFILES_DIR"
tmp=$(mktemp)
cat > "$tmp" <<JSON
{
  "name": "${name}",
  "owner": ${owner:+"$owner"}${owner:=""},
  "arch": "${arch}",
  "cpus": ${cpus},
  "memory_mb": ${mem},
  "disk_gb": ${disk},
  "iso_path": "${iso_path}",
  "network": { "bridge": "", "vhost": ${vhost_net}, "zone": ${zone:+"$zone"}${zone:=""} },
  "limits": { "cpu_quota_percent": 200, "memory_max_mb": ${mem_max} },
  "audio": { "model": ${audio_model:+"$audio_model"}${audio_model:=""} },
  "video": { "heads": ${video_heads} },
  "hugepages": ${hugepages},
  "memory_options": { "guest_memfd": ${mem_guest_memfd}, "private": ${mem_private} },
  "memballoon": { "disable": ${memballoon_disable} },
  "autostart": ${autostart}
}
JSON
# Clean up audio object if empty model
jq 'if .audio.model == null or .audio.model == "" then del(.audio) else . end | if .owner == null or .owner == "" then del(.owner) else . end | if .network.zone == null or .network.zone == "" then (.network |= del(.zone)) else . end' "$tmp" > "$profile_json"
rm -f "$tmp"

$DIALOG --msgbox "Created profile: $profile_json" 8 60
[[ -n "$WIZ_OUT_FILE" ]] && printf '%s' "$profile_json" > "$WIZ_OUT_FILE"

rm -f "$STATE_FILE"
