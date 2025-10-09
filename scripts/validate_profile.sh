#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077
schema="/etc/hypervisor/vm_profile.schema.json"
profile="$1"
: "${DIALOG:=whiptail}"
export DIALOG

require() { for b in jq; do command -v "$b" >/dev/null 2>&1 || { echo "Missing $b" >&2; exit 1; }; done; }
require

if ! jq -e . "$profile" >/dev/null 2>&1; then
  $DIALOG --msgbox "Invalid JSON: $profile" 8 50
  exit 1
fi

# Minimal validation (presence and types). Full JSON Schema validation would need 'ajv' or python jsonschema.
missing=$(jq -r '[(.name? // empty), (.cpus? // empty), (.memory_mb? // empty)] | map(select(.=="")) | length' "$profile")
if [[ "$missing" != "0" ]]; then
  $DIALOG --msgbox "Profile missing required fields" 8 40
  exit 1
fi

$DIALOG --msgbox "Profile looks valid" 8 30
