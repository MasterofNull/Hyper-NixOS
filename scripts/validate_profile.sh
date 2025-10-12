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

# Prefer strict JSON Schema validation when available
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$schema" "$profile" <<'PY'
import json, sys
try:
    from jsonschema import validate
    from jsonschema.exceptions import ValidationError
except Exception as e:
    sys.exit(0)

schema_path, profile_path = sys.argv[1], sys.argv[2]
with open(schema_path, 'r', encoding='utf-8') as f:
    schema = json.load(f)
with open(profile_path, 'r', encoding='utf-8') as f:
    data = json.load(f)
try:
    validate(instance=data, schema=schema)
except ValidationError as e:
    print(f"Schema validation failed: {e.message}")
    sys.exit(1)
PY
  then
    : # Validation passed
  else
    $DIALOG --msgbox "Profile failed schema validation" 8 50
    exit 1
  fi
else
  # Minimal validation fallback
  missing=$(jq -r '[(.name? // empty), (.cpus? // empty), (.memory_mb? // empty)] | map(select(.=="")) | length' "$profile")
  if [[ "$missing" != "0" ]]; then
    $DIALOG --msgbox "Profile missing required fields" 8 40
    exit 1
  fi
fi

$DIALOG --msgbox "Profile passed validation" 8 40
