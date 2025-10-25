#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
set -euo pipefail
: "${DIALOG:=whiptail}"
export DIALOG

require() { for b in $DIALOG ssh-keygen ssh-copy-id; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

keyfile="$HOME/.ssh/id_ed25519"
if [[ ! -f "$keyfile" ]]; then
  ssh-keygen -t ed25519 -f "$keyfile" -N ""
fi
host=$($DIALOG --inputbox "Target host (user@host)" 10 60 3>&1 1>&2 2>&3) || exit 0
ssh-copy-id -i "$keyfile.pub" "$host"
$DIALOG --msgbox "SSH key installed for $host" 8 40
