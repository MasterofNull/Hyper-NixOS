#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Usage:
#   sudo /etc/hypervisor/scripts/update_hypervisor.sh [--ref <commit|branch|tag>] [--force]
# - Updates /etc/nixos/flake.nix to point hypervisor input at latest or the provided ref
# - Refreshes flake.lock and rebuilds with safe options

: "${REF:=}"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) REF="$2"; shift 2;;
    --force) FORCE=true; shift;;
    -h|--help)
      cat <<USAGE
Usage: $(basename "$0") [--ref <commit|branch|tag>] [--force]

Examples:
  $(basename "$0")                 # update to latest on default branch
  $(basename "$0") --ref main       # pin to branch 'main'
  $(basename "$0") --ref v1.2.3     # pin to tag 'v1.2.3'
  $(basename "$0") --ref <sha>      # pin to a specific commit
USAGE
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

FLAKE_NIX=/etc/nixos/flake.nix
REPO_BASE="github:MasterofNull/Hyper-NixOS"

[[ -f "$FLAKE_NIX" ]] || { echo "Missing $FLAKE_NIX" >&2; exit 1; }

# Build the new URL
if [[ -n "$REF" ]]; then
  NEW_URL="$REPO_BASE/$REF"
else
  NEW_URL="$REPO_BASE"
fi

tmp=$(mktemp)
cp "$FLAKE_NIX" "$tmp"
# Replace hypervisor.url conservatively
if rg -q "^\s*hypervisor\.url\s*=\s*\".*\";" "$tmp" 2>/dev/null; then
  sed -i "s#^\s*hypervisor\.url\s*=\s*\".*\";#    hypervisor.url = \"$NEW_URL\";#" "$tmp"
else
  echo "Could not find hypervisor.url in $FLAKE_NIX" >&2
  exit 1
fi

install -m 0644 "$tmp" "$FLAKE_NIX"
rm -f "$tmp"

export NIX_CONFIG="experimental-features = nix-command flakes"
# Refresh lock and rebuild with safe cache options
nix flake lock --update-input hypervisor --flake /etc/nixos
nixos-rebuild switch --flake "/etc/nixos#$(hostname -s)" \
  --refresh --option tarball-ttl 0 \
  --option narinfo-cache-positive-ttl 0 \
  --option narinfo-cache-negative-ttl 0
