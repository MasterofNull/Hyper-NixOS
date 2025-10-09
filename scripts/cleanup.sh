#!/usr/bin/env bash
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
