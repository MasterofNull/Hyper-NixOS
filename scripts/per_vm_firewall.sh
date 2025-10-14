#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

: "${DIALOG:=whiptail}"

require() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require "$DIALOG" jq iptables virsh awk

select_profile() {
  local dir="/var/lib/hypervisor/vm_profiles" entries=()
  shopt -s nullglob
  for f in "$dir"/*.json; do name=$(jq -r '.name' "$f" 2>/dev/null || basename "$f"); entries+=("$f" "$name"); done
  shopt -u nullglob
  (( ${#entries[@]} == 0 )) && { $DIALOG --msgbox "No VM profiles found" 8 40; return 1; }
  $DIALOG --menu "Select VM" 22 80 14 "${entries[@]}" 3>&1 1>&2 2>&3
}

get_vm_ip() {
  local name="$1"
  # Try virsh domifaddr; return first IPv4
  virsh domifaddr "$name" 2>/dev/null | awk '/ipv4/ {print $4}' | sed 's#/.*##' | head -n1
}

get_vm_bridge() {
  local name="$1"
  # Find the bridge from domain XML network source
  virsh dumpxml "$name" 2>/dev/null | awk -F"'" '/<source bridge=/{print $2; exit}'
}

apply_rules() {
  local name="$1" port proto ip br
  ip=$(get_vm_ip "$name" || true)
  br=$(get_vm_bridge "$name" || true)
  while true; do
    choice=$($DIALOG --menu "Inbound rule for $name" 18 72 8 \
      add "Add TCP/UDP port" \
      list "List FORWARD rules (filtered)" \
      del "Delete rule by number" \
      done "Done" 3>&1 1>&2 2>&3 || true)
    case "$choice" in
      add)
        proto=$($DIALOG --menu "Protocol" 12 50 2 tcp "TCP" udp "UDP" 3>&1 1>&2 2>&3 || echo "tcp")
        port=$($DIALOG --inputbox "Port number" 10 50 3>&1 1>&2 2>&3) || continue
        if [[ -n "$ip" ]]; then
          sudo iptables -I FORWARD -p "$proto" -d "$ip" --dport "$port" -j ACCEPT
          $DIALOG --msgbox "Opened $proto/$port to $ip" 8 50
        elif [[ -n "$br" ]]; then
          sudo iptables -I FORWARD -o "$br" -p "$proto" --dport "$port" -j ACCEPT
          $DIALOG --msgbox "Opened $proto/$port on bridge $br (all VMs on bridge)." 10 60
        else
          sudo iptables -I FORWARD -p "$proto" --dport "$port" -j ACCEPT
          $DIALOG --msgbox "Opened $proto/$port (broad rule)." 8 50
        fi ;;
      list)
        # Show only rules that match VM IP or bridge, else all FORWARD
        if [[ -n "$ip" ]]; then sudo iptables -S FORWARD | grep -E "-d $ip|--dport" | nl -ba | ${PAGER:-less}; else sudo iptables -S FORWARD | nl -ba | ${PAGER:-less}; fi ;;
      del)
        num=$($DIALOG --inputbox "Rule number to delete (per 'iptables -S FORWARD' listing)" 10 70 3>&1 1>&2 2>&3) || true
        [[ -n "$num" ]] && sudo iptables -D FORWARD "$num" || true ;;
      *) break ;;
    esac
  done
}

p=$(select_profile || true) || exit 0
name=$(jq -r '.name' "$p")
apply_rules "$name"
