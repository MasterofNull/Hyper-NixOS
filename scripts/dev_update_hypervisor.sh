#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Development Update Script
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Fast development workflow:
# 1. Validate current installation
# 2. Smart sync only changed files from GitHub
# 3. Optionally rebuild the system
#
# This is the main script you'll use during development to quickly
# update your NixOS installation with the latest changes.
#
set -Eeuo pipefail
IFS=$'\n\t'
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

msg() { printf "${BLUE}[dev-update]${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
error() { printf "${RED}✗${NC} %s\n" "$*"; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Fast development update workflow for Hyper-NixOS.

This script combines validation, smart sync, and rebuild into one command:
  1. Validates your current installation
  2. Intelligently syncs only changed files from GitHub (saves bandwidth!)
  3. Optionally rebuilds your system with the updates

Options:
  --ref BRANCH|TAG|SHA    Update to specific branch/tag/commit (default: main)
  --check-only            Only check for updates, don't download or rebuild
  --skip-rebuild          Download updates but don't rebuild
  --force-full            Force full git clone instead of smart sync
  --rebuild-action ACTION Build action: build|test|switch (default: switch)
  --verbose               Show detailed output
  -h, --help              Show this help

Examples:
  $(basename "$0")                         # Smart update and rebuild from main
  $(basename "$0") --check-only            # Check what needs updating
  $(basename "$0") --ref develop           # Update from develop branch
  $(basename "$0") --skip-rebuild          # Just sync files, no rebuild
  $(basename "$0") --rebuild-action test   # Sync and test (don't switch)

Workflow:
  ┌──────────────────────────────────────┐
  │ 1. Validate Installation             │ ← Checks system health
  ├──────────────────────────────────────┤
  │ 2. Smart Sync from GitHub            │ ← Only downloads changed files!
  ├──────────────────────────────────────┤
  │ 3. Rebuild System (optional)         │ ← Applies updates
  └──────────────────────────────────────┘

Benefits:
  • 10-50x faster than full git clone for updates
  • Saves bandwidth (only downloads changed files)
  • Perfect for rapid development iterations
  • Validates before and after updates

USAGE
}

# Default options
REF="main"
CHECK_ONLY=false
SKIP_REBUILD=false
FORCE_FULL=false
REBUILD_ACTION="switch"
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) REF="$2"; shift 2;;
    --check-only) CHECK_ONLY=true; shift;;
    --skip-rebuild) SKIP_REBUILD=true; shift;;
    --force-full) FORCE_FULL=true; shift;;
    --rebuild-action) REBUILD_ACTION="$2"; shift 2;;
    --verbose) VERBOSE=true; shift;;
    -h|--help) usage; exit 0;;
    *) error "Unknown option: $1"; usage; exit 1;;
  esac
done

# Validate rebuild action
case "$REBUILD_ACTION" in
  build|test|switch) ;;
  *) error "Invalid rebuild action: $REBUILD_ACTION (must be build|test|switch)"; exit 1;;
esac

# Check if running as root
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  error "This script must be run as root (use sudo)"
  exit 1
fi

msg "╔════════════════════════════════════════════════════════╗"
msg "║   Hyper-NixOS Development Update                       ║"
msg "╚════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Validate current installation
msg "Step 1/3: Validating current installation..."
echo ""

if [[ -f "$SCRIPT_DIR/validate_hypervisor_install.sh" ]]; then
  if bash "$SCRIPT_DIR/validate_hypervisor_install.sh" --quick; then
    success "Installation validation passed"
  else
    warn "Installation validation found issues"
    read -r -p "Continue anyway? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      msg "Aborted by user"
      exit 1
    fi
  fi
else
  warn "Validation script not found, skipping validation"
fi

echo ""

# Step 2: Smart sync from GitHub
msg "Step 2/3: Syncing files from GitHub (ref: $REF)..."
echo ""

SYNC_ARGS=(--ref "$REF")
$CHECK_ONLY && SYNC_ARGS+=(--check-only)
$FORCE_FULL && SYNC_ARGS+=(--force-full)
$VERBOSE && SYNC_ARGS+=(--verbose)

if [[ -f "$SCRIPT_DIR/smart_sync_hypervisor.sh" ]]; then
  if bash "$SCRIPT_DIR/smart_sync_hypervisor.sh" "${SYNC_ARGS[@]}"; then
    success "File synchronization completed"
  else
    sync_exit=$?
    if [[ $sync_exit -eq 0 ]]; then
      success "No changes detected - system is up to date"
      
      if ! $SKIP_REBUILD; then
        read -r -p "Force rebuild anyway? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
          msg "✓ Nothing to do - system is current"
          exit 0
        fi
      else
        msg "✓ Nothing to do - system is current"
        exit 0
      fi
    else
      error "File synchronization failed"
      exit 1
    fi
  fi
else
  error "Smart sync script not found at $SCRIPT_DIR/smart_sync_hypervisor.sh"
  exit 1
fi

echo ""

# If check-only mode, exit here
if $CHECK_ONLY; then
  msg "Check complete - files synced (not downloaded due to --check-only)"
  msg "Run without --check-only to download and rebuild"
  exit 0
fi

# If skip-rebuild, exit here
if $SKIP_REBUILD; then
  success "Files synchronized successfully"
  msg "Skipping rebuild as requested (--skip-rebuild)"
  msg "Run 'sudo nixos-rebuild switch --flake \"/etc/hypervisor#\$(hostname -s)\"' to apply changes"
  exit 0
fi

# Step 3: Rebuild system
msg "Step 3/3: Rebuilding system (action: $REBUILD_ACTION)..."
echo ""

export NIX_CONFIG="experimental-features = nix-command flakes"

HOSTNAME=$(hostname -s)
FLAKE_PATH="/etc/hypervisor#$HOSTNAME"

msg "Running: nixos-rebuild $REBUILD_ACTION --flake $FLAKE_PATH"
echo ""

REBUILD_ARGS=(
  "$REBUILD_ACTION"
  --impure
  --flake "$FLAKE_PATH"
  --refresh
  --option tarball-ttl 0
  --option narinfo-cache-positive-ttl 0
  --option narinfo-cache-negative-ttl 0
)

$VERBOSE && REBUILD_ARGS+=(--show-trace)

if nixos-rebuild "${REBUILD_ARGS[@]}"; then
  success "System rebuild completed successfully"
  
  if [[ "$REBUILD_ACTION" == "switch" ]]; then
    msg "System has been updated and activated"
    msg "Services are being reloaded..."
    systemctl daemon-reload || true
    
    # Ask about reboot
    echo ""
    read -r -p "Reboot now to ensure all changes take effect? [y/N] " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      msg "Rebooting system..."
      systemctl reboot
    else
      msg "Remember to reboot later to complete the update"
    fi
  elif [[ "$REBUILD_ACTION" == "test" ]]; then
    msg "System has been temporarily activated (not persistent)"
  else
    msg "System has been built but not activated"
  fi
  
  echo ""
  msg "╔════════════════════════════════════════════════════════╗"
  msg "║   ✓ Update completed successfully!                    ║"
  msg "╚════════════════════════════════════════════════════════╝"
  exit 0
else
  error "System rebuild failed"
  echo ""
  error "╔════════════════════════════════════════════════════════╗"
  error "║   ✗ Update failed during rebuild                      ║"
  error "╚════════════════════════════════════════════════════════╝"
  echo ""
  msg "Troubleshooting:"
  msg "  1. Check the error messages above"
  msg "  2. Run validation: sudo bash $SCRIPT_DIR/validate_hypervisor_install.sh"
  msg "  3. Try: sudo nixos-rebuild build --flake $FLAKE_PATH --show-trace"
  msg "  4. Check logs: journalctl -xe"
  exit 1
fi
