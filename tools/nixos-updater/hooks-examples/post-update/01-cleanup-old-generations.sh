#!/usr/bin/env bash
#
# Example Hook: Cleanup old generations after update
#
# This hook runs after system updates to clean up old
# generations and optimize the Nix store.

set -euo pipefail

KEEP_GENERATIONS=5

echo "Cleaning up old generations (keeping $KEEP_GENERATIONS)..."

# Get current generation count
current_count=$(nixos-rebuild list-generations | wc -l)
echo "Current generation count: $current_count"

if [[ $current_count -gt $((KEEP_GENERATIONS + 2)) ]]; then
    echo "Removing old generations..."
    nix-env --delete-generations "+${KEEP_GENERATIONS}" 2>&1 || true
    
    echo "Running garbage collection..."
    nix-collect-garbage -d 2>&1 || true
    
    echo "Optimizing Nix store..."
    nix-store --optimise 2>&1 || true
    
    echo "✓ Cleanup complete"
else
    echo "✓ No cleanup needed (only $current_count generations)"
fi
