#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run]

Install host dependencies required for Hypervisor Suite.

Options:
  --dry-run   Print actions without executing system changes.
USAGE
}

is_dry_run=false
if [[ "${1-}" == "--dry-run" ]]; then
  is_dry_run=true
fi

run() {
  if $is_dry_run; then
    echo "+ $*"
  else
    eval "$@"
  fi
}

if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt-get"
  UPDATE_CMD="apt-get update"
  INSTALL_CMD="apt-get install -y"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
  UPDATE_CMD="dnf makecache -y"
  INSTALL_CMD="dnf install -y"
elif command -v pacman >/dev/null 2>&1; then
  PKG_MGR="pacman"
  UPDATE_CMD="pacman -Sy --noconfirm"
  INSTALL_CMD="pacman -S --noconfirm"
else
  echo "Unsupported package manager. Please install dependencies manually." >&2
  exit 1
fi

COMMON_PACKAGES=(
  qemu-kvm libvirt virt-install virt-manager
  bridge-utils dnsmasq
  python3 python3-venv
)

echo "Using package manager: $PKG_MGR"
run sudo $UPDATE_CMD
run sudo $INSTALL_CMD "${COMMON_PACKAGES[@]}"

echo "Installation complete."
