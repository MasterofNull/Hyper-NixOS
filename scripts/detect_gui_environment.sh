#!/usr/bin/env bash
#
# Detect GUI Environment Information
# Returns JSON with GUI availability and configuration
#
set -euo pipefail

# Output JSON format
output_json() {
  cat <<EOF
{
  "gui_available": $1,
  "display_server": "$2",
  "desktop_environment": "$3",
  "display_manager": "$4",
  "session_type": "$5",
  "hypervisor_gui_enabled": $6,
  "base_system_gui": $7,
  "can_launch_gui": $8,
  "current_target": "$9"
}
EOF
}

# Check if X server or Wayland is available
gui_available=false
display_server="none"
desktop_environment="none"
display_manager="none"
session_type="none"

# Check for running display server
if systemctl is-active --quiet display-manager.service 2>/dev/null; then
  gui_available=true
fi

# Check for X server
if command -v xset >/dev/null 2>&1 && xset q &>/dev/null; then
  display_server="X11"
  session_type="${XDG_SESSION_TYPE:-x11}"
fi

# Check for Wayland
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  display_server="wayland"
  session_type="wayland"
  gui_available=true
fi

# Detect desktop environment
if [[ -n "${GNOME_DESKTOP_SESSION_ID:-}" ]] || [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
  desktop_environment="GNOME"
elif [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]]; then
  desktop_environment="KDE"
elif [[ "${XDG_CURRENT_DESKTOP:-}" == *"XFCE"* ]]; then
  desktop_environment="XFCE"
elif systemctl is-active --quiet gdm.service 2>/dev/null; then
  desktop_environment="GNOME"
  gui_available=true
fi

# Detect display manager
if systemctl is-active --quiet gdm.service 2>/dev/null; then
  display_manager="GDM"
elif systemctl is-active --quiet sddm.service 2>/dev/null; then
  display_manager="SDDM"
elif systemctl is-active --quiet lightdm.service 2>/dev/null; then
  display_manager="LightDM"
fi

# Check if hypervisor GUI is explicitly enabled
hypervisor_gui_enabled=false
if [[ -f /var/lib/hypervisor/configuration/gui-local.nix ]]; then
  if grep -q "hypervisor.gui.enableAtBoot.*=.*true" /var/lib/hypervisor/configuration/gui-local.nix 2>/dev/null; then
    hypervisor_gui_enabled=true
  fi
fi

# Check if base system has GUI (before hypervisor config)
base_system_gui=false
if systemctl list-unit-files | grep -q "gdm.service\|sddm.service\|lightdm.service"; then
  base_system_gui=true
fi

# Check if we can launch GUI
can_launch_gui=false
if systemctl list-units --type target | grep -q "graphical.target"; then
  can_launch_gui=true
fi

# Get current systemd target
current_target=$(systemctl get-default 2>/dev/null || echo "unknown")

# Output JSON
output_json \
  "$gui_available" \
  "$display_server" \
  "$desktop_environment" \
  "$display_manager" \
  "$session_type" \
  "$hypervisor_gui_enabled" \
  "$base_system_gui" \
  "$can_launch_gui" \
  "$current_target"
