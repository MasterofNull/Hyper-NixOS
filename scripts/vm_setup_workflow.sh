#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

ROOT="/etc/hypervisor"
CONFIG_JSON="$ROOT/config.json"
STATE_DIR="/var/lib/hypervisor"
PROFILES_DIR="$STATE_DIR/vm-profiles"
ISOS_DIR="$STATE_DIR/isos"
SCRIPTS_DIR="$ROOT/scripts"
: "${DIALOG:=whiptail}"
export DIALOG

require() {
  for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done
}
require "$DIALOG" jq curl sha256sum virsh

mkdir -p "$PROFILES_DIR" "$ISOS_DIR" "$STATE_DIR/workflows"
STATE_FILE="$STATE_DIR/workflows/vm_setup_state.json"

ask() { $DIALOG --inputbox "$1" 10 70 "${2:-}" 3>&1 1>&2 2>&3; }

select_os_preset() {
  local items=()
  if [[ -f "$CONFIG_JSON" ]]; then
    mapfile -t names < <(jq -r '.iso_presets[]?.name' "$CONFIG_JSON")
    mapfile -t urls < <(jq -r '.iso_presets[]?.url' "$CONFIG_JSON")
    for i in "${!names[@]}"; do items+=("$i" "${names[$i]}"); done
  fi
  items+=("manual" "Manual URL")
  $DIALOG --menu "Select OS (preset or manual)" 22 80 12 "${items[@]}" 3>&1 1>&2 2>&3
}

ensure_iso_available() {
  local preset_or_manual="$1"; local iso_path_out
  if [[ "$preset_or_manual" == "manual" ]]; then
    local url; url=$($DIALOG --inputbox "ISO URL" 10 70 3>&1 1>&2 2>&3) || return 1
    iso_path_out=$("$SCRIPTS_DIR/iso_manager.sh" --cli download --url "$url")
  else
    iso_path_out=$("$SCRIPTS_DIR/iso_manager.sh" --cli download --preset "$preset_or_manual")
  fi
  printf '%s' "$iso_path_out"
}

save_state() {
  local stage="$1" preset_val="$2" iso_val="$3" profile_val="$4"
  cat > "$STATE_FILE" <<JSON
{
  "stage": "$stage",
  "preset": ${preset_val:+"$preset_val"},
  "iso": ${iso_val:+"$iso_val"},
  "profile": ${profile_val:+"$profile_val"}
}
JSON
}

load_state() {
  [[ -f "$STATE_FILE" ]] || return 1
  stage=$(jq -r '.stage // empty' "$STATE_FILE")
  preset=$(jq -r '.preset // empty' "$STATE_FILE")
  iso_file=$(jq -r '.iso // empty' "$STATE_FILE")
  profile=$(jq -r '.profile // empty' "$STATE_FILE")
}

create_profile() {
  local outfile; outfile=$(mktemp)
  PRESELECT_ISO="${iso_file:-}" WIZ_OUT_FILE="$outfile" "$SCRIPTS_DIR/create_vm_wizard.sh" "$PROFILES_DIR" "$ISOS_DIR" "${iso_file:-}"
  if [[ -s "$outfile" ]]; then
    local path; path=$(cat "$outfile")
    rm -f "$outfile"
    printf '%s' "$path"
  else
    rm -f "$outfile"
    return 1
  fi
}

choose_iso_from_dir() {
  local files=()
  shopt -s nullglob
  for f in "$ISOS_DIR"/*.iso; do files+=("$f" " "); done
  shopt -u nullglob
  if (( ${#files[@]} == 0 )); then
    $DIALOG --msgbox "No ISOs found. Download first." 8 40
    return 1
  fi
  $DIALOG --menu "Select ISO" 20 70 10 "${files[@]}" 3>&1 1>&2 2>&3
}

deploy_vm() {
  local profile_json="$1"
  "$SCRIPTS_DIR/json_to_libvirt_xml_and_define.sh" "$profile_json"
}

launch_vm() {
  local profile_json="$1" name
  name=$(jq -r '.name' "$profile_json")
  virsh start "$name" || true
}

# Workflow with resume support
if [[ -f "$STATE_FILE" ]]; then
  if $DIALOG --yesno "Resume previous VM setup workflow?" 8 60; then
    load_state || true
  else
    rm -f "$STATE_FILE"
  fi
fi

$DIALOG --msgbox "VM Setup Workflow\n\n1) Select OS\n2) Download ISO\n3) Create profile\n4) Deploy VM\n5) Launch VM" 14 70 || true

if [[ -z "${preset:-}" ]]; then
  preset=$(select_os_preset || true) || preset="manual"
  save_state "selected_os" "$preset" "" ""
fi

if [[ -z "${iso_file:-}" ]]; then
  iso_file=$(ensure_iso_available "$preset") || { $DIALOG --msgbox "Failed to obtain ISO" 8 40; exit 1; }
  save_state "downloaded_iso" "$preset" "$iso_file" ""
fi

if [[ -z "${profile:-}" ]]; then
  profile=$(create_profile) || { $DIALOG --msgbox "Failed to create profile" 8 40; exit 1; }
  save_state "created_profile" "$preset" "$iso_file" "$profile"
fi

if $DIALOG --yesno "Deploy VM now from profile?\n${profile}" 12 70; then
  deploy_vm "$profile" || { $DIALOG --msgbox "Deploy failed" 8 40; exit 1; }
  save_state "deployed" "$preset" "$iso_file" "$profile"
fi

if $DIALOG --yesno "Launch VM now?" 8 40; then
  launch_vm "$profile" || true
  save_state "launched" "$preset" "$iso_file" "$profile"
fi

rm -f "$STATE_FILE"
$DIALOG --msgbox "Workflow finished." 8 40
