#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

trap 'exit $?' EXIT HUP INT TERM

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--flake FLAKE] [--host HOST] {build|test|switch|check}

Safely build/test/switch a NixOS configuration with flakes enabled.

Options:
  --flake FLAKE   Flake path or URL (default: /etc/nixos)
  --host HOST     Host attribute name (default: "+ detect from hostname")
  --help          Show this help

Commands:
  build           Build only (no activation)
  test            Temporary activation (does not make default)
  switch          Activate and make default
  check           Run flake checks if defined
USAGE
}

export NIX_CONFIG="experimental-features = nix-command flakes"

flake="/etc/nixos"
host=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flake) flake="$2"; shift 2;;
    --host) host="$2"; shift 2;;
    --help|-h) usage; exit 0;;
    build|test|switch|check) cmd="$1"; shift;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

cmd=${cmd:-}
if [[ -z "$cmd" ]]; then usage; exit 1; fi

# Detect host if not provided
if [[ -z "$host" ]]; then
  host=$(hostname -s 2>/dev/null || echo hypervisor)
fi

attr="${flake}#${host}"

case "$cmd" in
  check)
    nix flake check "$flake" ;;
  build)
    nixos-rebuild build --flake "$attr" ;;
  test)
    nixos-rebuild test --flake "$attr" ;;
  switch)
    nixos-rebuild switch --flake "$attr" ;;
  *)
    usage; exit 1;;
esac
