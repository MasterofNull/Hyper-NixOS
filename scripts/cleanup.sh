#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Purpose: Housekeeping helper to remove repo-local tmp folder (dev only)
# Note: Not used in production NixOS flow.
set -euo pipefail

echo "Cleaning up temporary artifacts..."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TMP_DIR="$ROOT_DIR/tmp"

if [[ -d "$TMP_DIR" ]]; then
  rm -rf "$TMP_DIR"
  echo "Removed $TMP_DIR"
else
  echo "No tmp directory present."
fi

echo "Cleanup complete."
