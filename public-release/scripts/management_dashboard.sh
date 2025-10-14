#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Simple dashboard to launch hypervisor tools from any desktop environment
# --autostart: if VMs exist, offer selection with timeout; if none, open dashboard

ROOT=/etc/hypervisor
SCRIPTS=$ROOT/scripts
STATE=/var/lib/hypervisor

# Pick a terminal emulator dynamically (DE-agnostic, Wayland-friendly)
TERM_CMD=""; TERM_MODE="plain"
detect_terminal() {
  if [[ -n "${TERMINAL:-}" ]] && command -v "$TERMINAL" >/dev/null 2>&1; then
    TERM_CMD="$TERMINAL"; TERM_MODE="plain"; return 0
  fi
  for t in footclient foot kitty wezterm alacritty xfce4-terminal konsole gnome-terminal xterm; do
    if command -v "$t" >/dev/null 2>&1; then
      TERM_CMD="$t"
      case "$t" in
        gnome-terminal) TERM_MODE="dashdash";;
        wezterm)        TERM_MODE="start";;
        *)              TERM_MODE="plain";;
      esac
      return 0
    fi
  done
  TERM_CMD="" # no GUI terminal available
}

run_in_terminal() {
  local cmd="$1"
  if [[ -n "$TERM_CMD" ]]; then
    case "$TERM_MODE" in
      dashdash) "$TERM_CMD" -- bash -lc "$cmd" & ;;
      start)    "$TERM_CMD" start -- bash -lc "$cmd" & ;;
      *)        "$TERM_CMD" -e bash -lc "$cmd" & ;;
    esac
  else
    # Fallback: run in background without opening a terminal
    bash -lc "$cmd" &
  fi
}

# Pick list dialog tool (zenity preferred, fallback to yad)
ZENITY="zenity"
detect_dialog() {
  if ! command -v zenity >/dev/null 2>&1 && command -v yad >/dev/null 2>&1; then
    ZENITY=yad
  else
    ZENITY=zenity
  fi
}

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
  
  "$ZENITY" --list --title="Hypervisor Dashboard - $gui_status" \
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
    vm_menu)        run_in_terminal "$SCRIPTS/menu.sh" ;;
    wizard)         run_in_terminal "$SCRIPTS/setup_wizard.sh" ;;
    network_setup)  run_in_terminal "sudo $SCRIPTS/foundational_networking_setup.sh" ;;
    iso)            run_in_terminal "$SCRIPTS/iso_manager.sh" ;;
    create)         run_in_terminal "$SCRIPTS/create_vm_wizard.sh $STATE/vm_profiles $STATE/isos" ;;
    update)         run_in_terminal "$SCRIPTS/update_hypervisor.sh" ;;
    gui_status)     run_in_terminal "sudo $SCRIPTS/toggle_gui.sh status; read -p 'Press Enter to continue...'" ;;
    gui_auto)       run_in_terminal "sudo $SCRIPTS/toggle_gui.sh auto; read -p 'Press Enter to continue...'" ;;
    gui_force_off)  run_in_terminal "sudo $SCRIPTS/toggle_gui.sh off; read -p 'Press Enter to continue...'" ;;
    toggle_menu_on) run_in_terminal "$SCRIPTS/toggle_boot_features.sh menu on" ;;
    toggle_menu_off)run_in_terminal "$SCRIPTS/toggle_boot_features.sh menu off" ;;
    toggle_wizard_on)run_in_terminal "$SCRIPTS/toggle_boot_features.sh wizard on" ;;
    toggle_wizard_off)run_in_terminal "$SCRIPTS/toggle_boot_features.sh wizard off" ;;
    terminal)       run_in_terminal "bash -l" ;;
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
    detect_dialog
    sel=$("$ZENITY" --list --title="Select VM (auto in 8s)" --timeout=8 \
      --column=Path --column=Name "${ZLIST[@]}" 2>/dev/null || true)
    if [[ -n "$sel" ]]; then
      detect_terminal
      run_in_terminal "$SCRIPTS/json_to_libvirt_xml_and_define.sh '$sel'"
      exit 0
    elif [[ -n "$default" && -f "$default" ]]; then
      detect_terminal
      run_in_terminal "$SCRIPTS/json_to_libvirt_xml_and_define.sh '$default'"
      exit 0
    fi
  fi
fi

detect_terminal
detect_dialog
sel=$(show_menu || true)
run_action "$sel"
