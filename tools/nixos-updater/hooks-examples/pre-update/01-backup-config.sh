#!/usr/bin/env bash
#
# Example Hook: Backup configuration before update
#
# This hook runs before system updates to create a backup
# of critical configuration files.

set -euo pipefail

BACKUP_DIR="/var/backups/nixos-updater"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/config-backup-$TIMESTAMP"

echo "Creating configuration backup..."
mkdir -p "$BACKUP_PATH"

# Backup NixOS configuration
if [[ -d /etc/nixos ]]; then
    cp -r /etc/nixos "$BACKUP_PATH/"
    echo "✓ Backed up /etc/nixos"
fi

# Backup important system files
for file in /etc/fstab /etc/hosts /etc/resolv.conf; do
    if [[ -f "$file" ]]; then
        cp "$file" "$BACKUP_PATH/"
        echo "✓ Backed up $file"
    fi
done

# Create manifest
cat > "$BACKUP_PATH/manifest.txt" << EOF
Backup created: $(date)
System: $(nixos-version)
Hostname: $(hostname)
Generation: $(nixos-rebuild list-generations | tail -1)
EOF

echo "✓ Configuration backup created: $BACKUP_PATH"
