#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Harden /etc/hypervisor permissions after configuration is stable.
# Usage: sudo /etc/hypervisor/scripts/harden_permissions.sh

TARGET=${1:-/etc/hypervisor}

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Missing target: $TARGET" >&2
  exit 1
fi

# Restrictive perms: root:wheel readable dirs, scripts executable
chown -R root:wheel "$TARGET"
find "$TARGET" -type d -exec chmod 0750 {} +
find "$TARGET" -type f -exec chmod 0640 {} +
if [[ -d "$TARGET/scripts" ]]; then
  find "$TARGET/scripts" -type f -exec chmod 0750 {} +
fi

# Ensure NixOS flake remains readable
chmod 0644 "$TARGET/flake.nix" 2>/dev/null || true

echo "Permissions hardened under $TARGET."
