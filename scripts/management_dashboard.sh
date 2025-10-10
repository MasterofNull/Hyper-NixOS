#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Simple dashboard to launch hypervisor tools from GNOME
# --autostart will open a basic chooser if no VMs configured

ROOT=/etc/hypervisor
SCRIPTS=$ROOT/scripts
STATE=/var/lib/hypervisor
: "${TERMINAL:=gnome-terminal}"

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

sel=$(show_menu || true)
run_action "$sel"
