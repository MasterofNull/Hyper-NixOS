#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"
CONFIG_JSON="/etc/hypervisor/config.json"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" jq ip iptables dnsmasq

ensure_bridge() { local br="$1"; ip link show "$br" >/dev/null 2>&1 || { sudo ip link add name "$br" type bridge; sudo ip link set "$br" up; }; }

setup_dnsmasq() {
  local br="$1" cidr="$2"; local conf="/etc/dnsmasq.d/hypervisor-${br}.conf"
  sudo bash -c "cat > '$conf' <<CONF
# Auto-generated for $br
interface=$br
bind-interfaces
except-interface=lo
# DHCP range
$(awk -v cidr="$cidr" 'BEGIN{split(cidr,a,"/"); print "dhcp-range="a[1]",static"}')
CONF"
  sudo systemctl restart dnsmasq || true
}

apply_reservations() {
  local zone="$1" br="$2"; local conf="/etc/dnsmasq.d/hypervisor-${br}.conf"
  # Append dhcp-host entries from config.json dhcp_reservations
  tmp=$(mktemp)
  cp "$conf" "$tmp" || true
  while IFS= read -r kv; do
    mac="${kv%%|*}"; ip="${kv##*|}"
    echo "dhcp-host=$mac,$ip" >> "$tmp"
  done < <(jq -r --arg z "$zone" '.network_zones[$z].dhcp_reservations | to_entries[] | (.key+"|"+.value)' "$CONFIG_JSON" 2>/dev/null || true)
  sudo mv "$tmp" "$conf" && sudo systemctl restart dnsmasq || true
}

apply_fw_rules() {
  local br="$1" zone="$2"
  sudo iptables -N "VMZ_${zone^^}" >/dev/null 2>&1 || true
  sudo iptables -F "VMZ_${zone^^}" || true
  sudo iptables -A "VMZ_${zone^^}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  sudo iptables -A "VMZ_${zone^^}" -p udp --dport 53 -j ACCEPT
  sudo iptables -A "VMZ_${zone^^}" -p udp --dport 123 -j ACCEPT
  sudo iptables -C FORWARD -i "$br" -j "VMZ_${zone^^}" 2>/dev/null || sudo iptables -A FORWARD -i "$br" -j "VMZ_${zone^^}"
}

menu() {
  while true; do
    choice=$($DIALOG --menu "Network Helper" 22 80 14 \
      setup "Create bridge and apply base firewall" \
      dhcp "Configure dnsmasq for a bridge" \
      exit "Exit" 3>&1 1>&2 2>&3 || true)
    case "$choice" in
      setup)
        zone=$($DIALOG --inputbox "Zone name (must exist in config.json)" 10 60 3>&1 1>&2 2>&3) || continue
        br=$(jq -r --arg z "$zone" '.network_zones?[$z]?.bridge // empty' "$CONFIG_JSON")
        cidr=$(jq -r --arg z "$zone" '.network_zones?[$z]?.dhcp_cidr // empty' "$CONFIG_JSON")
        [[ -z "$br" || "$br" == "null" ]] && { $DIALOG --msgbox "Unknown zone or bridge" 8 40; continue; }
        ensure_bridge "$br"; apply_fw_rules "$br" "$zone"; [[ -n "$cidr" && "$cidr" != "null" ]] && setup_dnsmasq "$br" "$cidr" && apply_reservations "$zone" "$br"; $DIALOG --msgbox "Applied for $zone ($br)" 8 50 ;;
      dhcp)
        br=$($DIALOG --inputbox "Bridge name" 10 60 3>&1 1>&2 2>&3) || continue
        cidr=$($DIALOG --inputbox "CIDR (e.g., 192.168.100.1/24)" 10 60 3>&1 1>&2 2>&3) || continue
        setup_dnsmasq "$br" "$cidr" ;;
      *) exit 0 ;;
    esac
  done
}

menu
