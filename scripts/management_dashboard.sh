#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Simple dashboard to launch hypervisor tools from GNOME
# --autostart: if VMs exist, offer selection with timeout; if none, open dashboard

ROOT=/etc/hypervisor
SCRIPTS=$ROOT/scripts
STATE=/var/lib/hypervisor
: "${TERMINAL:=gnome-terminal}"

list_vms() {
  shopt -s nullglob
  for f in "$STATE/vm_profiles"/*.json; do
    name=$(jq -r '.name // empty' "$f" 2>/dev/null || basename "$f")
    [[ -z "$name" ]] && name=$(basename "$f")
    echo "$f|$name"
  done
  shopt -u nullglob
}

show_menu() {
  zenity --list --title="Hypervisor Dashboard" \
    --column=Action --column=Description \
    "vm_menu" "Open VM selector (TUI)" \
    "wizard" "Run first-boot setup wizard" \
    "iso" "Open ISO manager" \
    "create" "Create VM wizard" \
    "update" "Update Hypervisor (pin latest)" \
    "toggle_menu_on" "Enable menu at boot" \
    "toggle_menu_off" "Disable menu at boot" \
    "toggle_wizard_on" "Enable first-boot wizard at boot" \
    "toggle_wizard_off" "Disable first-boot wizard at boot" \
    "terminal" "Open terminal" \
    --height=420 --width=640
}

run_action() {
  case "$1" in
    vm_menu)        $TERMINAL -- bash -lc "$SCRIPTS/menu.sh" & ;;
    wizard)         $TERMINAL -- bash -lc "$SCRIPTS/setup_wizard.sh" & ;;
    iso)            $TERMINAL -- bash -lc "$SCRIPTS/iso_manager.sh" & ;;
    create)         $TERMINAL -- bash -lc "$SCRIPTS/create_vm_wizard.sh $STATE/vm_profiles $STATE/isos" & ;;
    update)         $TERMINAL -- bash -lc "$SCRIPTS/update_hypervisor.sh" & ;;
    toggle_menu_on) $TERMINAL -- bash -lc "$SCRIPTS/toggle_boot_features.sh menu on" & ;;
    toggle_menu_off)$TERMINAL -- bash -lc "$SCRIPTS/toggle_boot_features.sh menu off" & ;;
    toggle_wizard_on)$TERMINAL -- bash -lc "$SCRIPTS/toggle_boot_features.sh wizard on" & ;;
    toggle_wizard_off)$TERMINAL -- bash -lc "$SCRIPTS/toggle_boot_features.sh wizard off" & ;;
    terminal)       $TERMINAL & ;;
    *) : ;;
  esac
}

if [[ "${1:-}" == "--autostart" ]]; then
  # Optionally auto-open dashboard; can be enhanced to show last VMs
  :
fi

# Autostart behavior: if VMs exist, offer selection with timeout; else show dashboard
if [[ "${1:-}" == "--autostart" ]]; then
  mapfile -t items < <(list_vms)
  if (( ${#items[@]} > 0 )); then
    ZLIST=( )
    for line in "${items[@]}"; do
      vm_path="${line%%|*}"; vm_name="${line##*|}"
      ZLIST+=("$vm_path" "$vm_name")
    done
    last_vm="$STATE/last_vm"
    default=""
    [[ -f "$last_vm" ]] && default=$(cat "$last_vm" 2>/dev/null || true)
    sel=$(zenity --list --title="Select VM (auto in 8s)" --timeout=8 \
      --column=Path --column=Name "${ZLIST[@]}" 2>/dev/null || true)
    if [[ -n "$sel" ]]; then
      gnome-terminal -- bash -lc "$SCRIPTS/json_to_libvirt_xml_and_define.sh '$sel'"
      exit 0
    elif [[ -n "$default" && -f "$default" ]]; then
      gnome-terminal -- bash -lc "$SCRIPTS/json_to_libvirt_xml_and_define.sh '$default'"
      exit 0
    fi
  fi
fi

sel=$(show_menu || true)
run_action "$sel"
