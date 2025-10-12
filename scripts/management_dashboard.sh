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

get_gui_status() {
  # Detect GUI environment
  if command -v "$SCRIPTS/detect_gui_environment.sh" >/dev/null 2>&1; then
    gui_json=$("$SCRIPTS/detect_gui_environment.sh" 2>/dev/null || echo '{}')
    base_gui=$(echo "$gui_json" | jq -r '.base_system_gui // false' 2>/dev/null || echo "false")
    hypervisor_gui=$(echo "$gui_json" | jq -r '.hypervisor_gui_enabled // false' 2>/dev/null || echo "false")
    
    if [[ "$hypervisor_gui" == "true" ]]; then
      echo "GUI: Forced ON (override)"
    elif [[ "$hypervisor_gui" == "false" ]] && [[ -f /var/lib/hypervisor/configuration/gui-local.nix ]]; then
      echo "GUI: Forced OFF (override)"
    elif [[ "$base_gui" == "true" ]]; then
      echo "GUI: ON (base system)"
    else
      echo "GUI: OFF (no GUI installed)"
    fi
  else
    echo "GUI: Unknown"
  fi
}

show_menu() {
  gui_status=$(get_gui_status)
  
  zenity --list --title="Hypervisor Dashboard - $gui_status" \
    --column=Action --column=Description \
    "vm_menu" "Open VM selector (TUI)" \
    "wizard" "Run first-boot setup wizard" \
    "network_setup" "Network foundation setup" \
    "iso" "Open ISO manager" \
    "create" "Create VM wizard" \
    "update" "Update Hypervisor (pin latest)" \
    "gui_status" "Show GUI environment status" \
    "gui_auto" "GUI: Use base system default" \
    "gui_force_off" "GUI: Force console menu at boot" \
    "toggle_menu_on" "Enable console menu at boot" \
    "toggle_menu_off" "Disable console menu at boot" \
    "toggle_wizard_on" "Enable first-boot wizard at boot" \
    "toggle_wizard_off" "Disable first-boot wizard at boot" \
    "terminal" "Open terminal" \
    --height=550 --width=680
}

run_action() {
  case "$1" in
    vm_menu)        $TERMINAL -- bash -lc "$SCRIPTS/menu.sh" & ;;
    wizard)         $TERMINAL -- bash -lc "$SCRIPTS/setup_wizard.sh" & ;;
    network_setup)  $TERMINAL -- bash -lc "sudo $SCRIPTS/foundational_networking_setup.sh" & ;;
    iso)            $TERMINAL -- bash -lc "$SCRIPTS/iso_manager.sh" & ;;
    create)         $TERMINAL -- bash -lc "$SCRIPTS/create_vm_wizard.sh $STATE/vm_profiles $STATE/isos" & ;;
    update)         $TERMINAL -- bash -lc "$SCRIPTS/update_hypervisor.sh" & ;;
    gui_status)     $TERMINAL -- bash -lc "sudo $SCRIPTS/toggle_gui.sh status; read -p 'Press Enter to continue...'" & ;;
    gui_auto)       $TERMINAL -- bash -lc "sudo $SCRIPTS/toggle_gui.sh auto; read -p 'Press Enter to continue...'" & ;;
    gui_force_off)  $TERMINAL -- bash -lc "sudo $SCRIPTS/toggle_gui.sh off; read -p 'Press Enter to continue...'" & ;;
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
