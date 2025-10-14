#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"
CONFIG_JSON="/etc/hypervisor/config.json"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" jq ip iptables

list_zones() {
  jq -r '.network_zones | to_entries[] | [.key, (.value.bridge // ""), (.value.allow_hostdev // false)] | @tsv' "$CONFIG_JSON"
}

ensure_bridge() {
  local br="$1"
  ip link show "$br" >/dev/null 2>&1 && return 0
  sudo ip link add name "$br" type bridge
  sudo ip link set "$br" up
}

apply_zone_rules() {
  local zone="$1" br="$2"
  # Example minimal rules: default DROP, allow established/related, DNS/NTP egress
  # Customize with NixOS firewall ideally; shell fallback here is basic.
  sudo iptables -N "ZONE_${zone^^}" >/dev/null 2>&1 || true
  sudo iptables -F "ZONE_${zone^^}" || true
  sudo iptables -A "ZONE_${zone^^}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  sudo iptables -A "ZONE_${zone^^}" -p udp --dport 53 -j ACCEPT
  sudo iptables -A "ZONE_${zone^^}" -p udp --dport 123 -j ACCEPT
  # Hook chain into FORWARD for bridge
  sudo iptables -C FORWARD -i "$br" -j "ZONE_${zone^^}" 2>/dev/null || sudo iptables -A FORWARD -i "$br" -j "ZONE_${zone^^}"
}

menu() {
  while true; do
    choice=$($DIALOG --menu "Zone Manager" 20 70 10 \
      list "List zones" \
      apply "Ensure bridges and apply base rules" \
      exit "Exit" 3>&1 1>&2 2>&3 || true)
    case "$choice" in
      list)
        out=$(list_zones | awk 'BEGIN{printf("ZONE\tBRIDGE\tALLOW_HOSTDEV\n")} {print $1"\t"$2"\t"$3}')
        printf '%s\n' "$out" | ${PAGER:-less}
        ;;
      apply)
        while read -r line; do
          zone=$(printf '%s' "$line" | awk '{print $1}')
          br=$(printf '%s' "$line" | awk '{print $2}')
          [[ -z "$zone" || -z "$br" ]] && continue
          ensure_bridge "$br"
          apply_zone_rules "$zone" "$br"
        done < <(list_zones)
        $DIALOG --msgbox "Applied bridges and base rules for configured zones." 8 60
        ;;
      *) break ;;
    esac
  done
}

menu
