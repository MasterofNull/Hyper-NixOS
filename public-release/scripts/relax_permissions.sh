#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Relax /etc/hypervisor permissions to facilitate updates and GC operations.
# Usage: sudo /etc/hypervisor/scripts/relax_permissions.sh

TARGET=${1:-/etc/hypervisor}

if [[ $EUID -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Missing target: $TARGET" >&2
  exit 1
fi

# Permissive defaults: owner root:root, dirs 0755, files 0644, scripts 0755
chown -R root:root "$TARGET"
find "$TARGET" -type d -exec chmod 0755 {} +
find "$TARGET" -type f -exec chmod 0644 {} +
if [[ -d "$TARGET/scripts" ]]; then
  find "$TARGET/scripts" -type f -exec chmod 0755 {} +
fi

# Ensure flake remains readable
chmod 0644 "$TARGET/flake.nix" 2>/dev/null || true

echo "Permissions relaxed under $TARGET. You can now update or prune generations safely."
