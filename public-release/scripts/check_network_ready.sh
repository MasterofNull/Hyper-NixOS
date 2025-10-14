#!/usr/bin/env bash
#
# Hyper-NixOS Network Readiness Checker
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Checks if foundational networking has been completed
# Used by scripts that require network access
#
set -euo pipefail

READINESS_MARKER="/var/lib/hypervisor/.network_ready"

# Check if marker exists
if [[ ! -f "$READINESS_MARKER" ]]; then
  echo "ERROR: Network foundation has not been set up"
  echo ""
  echo "Please run foundational networking setup first:"
  echo "  sudo /etc/hypervisor/scripts/foundational_networking_setup.sh"
  echo ""
  exit 1
fi

# Parse marker file
if command -v jq >/dev/null 2>&1; then
  status=$(jq -r '.status // "unknown"' "$READINESS_MARKER" 2>/dev/null || echo "unknown")
  bridge=$(jq -r '.bridge // "unknown"' "$READINESS_MARKER" 2>/dev/null || echo "unknown")
  ip=$(jq -r '.ip // "none"' "$READINESS_MARKER" 2>/dev/null || echo "none")
  
  if [[ "$status" == "ready" ]]; then
    # Verify bridge still exists
    if ip link show "$bridge" &>/dev/null; then
      # Optional: verbose mode
      if [[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]]; then
        echo "✓ Network foundation is ready"
        echo "  Bridge: $bridge"
        echo "  IP: $ip"
      fi
      exit 0
    else
      echo "WARNING: Network foundation marker exists but bridge '$bridge' not found"
      echo "Run setup again to reconfigure:"
      echo "  sudo /etc/hypervisor/scripts/foundational_networking_setup.sh"
      exit 1
    fi
  else
    echo "ERROR: Network foundation status: $status"
    exit 1
  fi
else
  # jq not available, just check marker exists
  exit 0
fi
