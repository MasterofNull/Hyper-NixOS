#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export NIX_CONFIG="experimental-features = nix-command flakes"

cleanup() {
  local ec=$?
  [[ -n "${TMPDIR:-}" && -d "${TMPDIR:-}" ]] && rm -rf -- "$TMPDIR"
  exit "$ec"
}
trap cleanup EXIT HUP INT TERM
TMPDIR=$(mktemp -d -t hypervisor-bootstrap.XXXXXX)

HOSTNAME_OVERRIDE=""
ACTION=""   # build|test|switch
FORCE=true
SRC_OVERRIDE=""

usage() {
  cat <<USAGE
Usage: sudo $(basename "$0") [--hostname NAME] [--action build|test|switch] [--force] [--source PATH]

Install Hyper‑NixOS from the current folder (USB checkout) into /etc/hypervisor,
write /etc/nixos/flake.nix, and optionally perform a one-shot rebuild.

Options:
  --hostname NAME     Host attribute and system hostname (default: current hostname)
  --action MODE       One of: build, test, switch. If omitted, show TUI menu.
  --force             Overwrite existing /etc/hypervisor without prompting
  --source PATH       Use PATH as source folder instead of auto-detect
  -h, --help          Show this help
USAGE
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      echo "Elevating privileges with sudo..."
      exec sudo -E "$0" "$@"
    else
      echo "This script must be run as root (use sudo)." >&2
      exit 1
    fi
  fi
}

use_dialog() {
  if command -v dialog >/dev/null 2>&1; then
    echo dialog
  elif command -v whiptail >/dev/null 2>&1; then
    echo whiptail
  else
    echo "" # no TUI available
  fi
}

msg() { printf "[hypervisor-bootstrap] %s\n" "$*"; }

detect_system() {
  case "$(uname -m)" in
    x86_64) echo x86_64-linux ;;
    aarch64|arm64) echo aarch64-linux ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}

ensure_hardware_config() {
  if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    msg "Generating /etc/nixos/hardware-configuration.nix"
    nixos-generate-config --root /
  fi
}

copy_repo_to_etc() {
  local src_root="$1"
  local dst_root="/etc/hypervisor"
  if [[ -d "$dst_root" ]]; then
    if $FORCE; then
      :
    elif [[ -n "$DIALOG" ]]; then
      "$DIALOG" --yesno "/etc/hypervisor exists. Overwrite with current repo contents?" 10 70 || return 0
    else
      read -r -p "/etc/hypervisor exists. Overwrite? [y/N] " ans
      [[ "$ans" =~ ^[Yy]$ ]] || return 0
    fi
    rm -rf -- "$dst_root"
  fi
  mkdir -p "$dst_root"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude ".git/" --exclude "result" --exclude "target/" "$src_root/" "$dst_root/"
  else
    shopt -s dotglob
    cp -a "$src_root"/* "$dst_root"/
    shopt -u dotglob
  fi
  chmod -R go-rwx "$dst_root" || true
}

write_host_flake() {
  local system="$1"; shift
  local hostname="$1"; shift
  local flake_path="/etc/nixos/flake.nix"
  msg "Writing $flake_path for $hostname ($system)"
  install -m 0644 /dev/null "$flake_path"
  cat > "$flake_path" <<'FLAKE'
{
  description = "Hyper‑NixOS Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    hypervisor.url = "path:/etc/hypervisor";
  };

  outputs = { self, nixpkgs, hypervisor }:
    let
      system = "__SYSTEM__";
    in {
      nixosConfigurations.__HOST__ = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hardware-configuration.nix
          (hypervisor + "/configuration/configuration.nix")
        ];
      };
    };

  nixConfig = { experimental-features = [ "nix-command" "flakes" ]; };
}
FLAKE
  sed -i "s/__SYSTEM__/$system/" "$flake_path"
  sed -i "s/__HOST__/$hostname/" "$flake_path"
}

rebuild_menu() {
  local host="$1"
  local attr="/etc/nixos#$host"
  export NIX_CONFIG="experimental-features = nix-command flakes"
  if [[ -n "$DIALOG" ]]; then
    "$DIALOG" --menu "Choose next step" 14 70 5 \
      build "Build only (no activation)" \
      test "Test (temporary activation)" \
      switch "Switch (persist default)" \
      shell "Open root shell" \
      quit "Quit" 2>"$TMPDIR/choice" || return 0
    local choice; choice=$(cat "$TMPDIR/choice" 2>/dev/null || true)
  else
    printf "1) Build only\n2) Test activate\n3) Switch\n4) Shell\n5) Quit\n"
    read -r -p "Select [1-5]: " n
    case "$n" in 1) choice=build;; 2) choice=test;; 3) choice=switch;; 4) choice=shell;; *) choice=quit;; esac
  fi
  case "${choice:-quit}" in
    build) nixos-rebuild build --flake "$attr" ;;
    test) nixos-rebuild test --flake "$attr" ;;
    switch) nixos-rebuild switch --flake "$attr" ;;
    shell) ${SHELL:-/bin/bash} -l ;;
    *) : ;;
  esac
}

ask_yes_no() {
  local prompt="$1"; local default_answer="${2:-yes}"
  if [[ -n "$DIALOG" ]]; then
    if "$DIALOG" --yesno "$prompt" 10 70; then return 0; else return 1; fi
  fi
  if [[ -t 0 ]]; then
    local suffix="[Y/n]"; [[ "$default_answer" == "no" ]] && suffix="[y/N]"
    read -r -p "$prompt $suffix " ans || true
    if [[ -z "$ans" ]]; then [[ "$default_answer" == "yes" ]]; return $?; fi
    [[ "$ans" =~ ^[Yy]$ ]]
    return $?
  else
    [[ "$default_answer" == "yes" ]]
    return $?
  fi
}

main() {
  require_root "$@"
  DIALOG="$(use_dialog)"

  # Parse CLI flags early for non-interactive one-shot installs
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hostname) HOSTNAME_OVERRIDE="$2"; shift 2;;
      --action) ACTION="$2"; shift 2;;
      --force) FORCE=true; shift;;
      --source) SRC_OVERRIDE="$2"; shift 2;;
      -h|--help) usage; exit 0;;
      *) echo "Unknown option: $1" >&2; usage; exit 1;;
    esac
  done

  local system; system=$(detect_system)
  local default_hostname; default_hostname=$(hostname -s 2>/dev/null || echo hypervisor)

  # Determine source root when run via nix run (store) or from a checkout
  local src_root
  if [[ -n "$SRC_OVERRIDE" ]]; then
    src_root="$SRC_OVERRIDE"
  elif [[ "$0" == /nix/store/* ]]; then
    src_root="$(dirname "$(dirname "$0")")"
  else
    src_root="$(cd "$(dirname "$0")/.." && pwd)"
  fi

  local hostname
  if [[ -n "$HOSTNAME_OVERRIDE" ]]; then
    hostname="$HOSTNAME_OVERRIDE"
  elif [[ -n "$DIALOG" && -z "$ACTION" ]]; then
    hostname=$("$DIALOG" --inputbox "Hostname for this hypervisor" 10 60 "$default_hostname" 3>&1 1>&2 2>&3 || echo "$default_hostname")
    "$DIALOG" --msgbox "We will copy Hyper‑NixOS files to /etc/hypervisor and generate /etc/nixos/flake.nix for '$hostname' on $system." 12 70 || true
  else
    read -r -p "Hostname [$default_hostname]: " ans || true
    hostname=${ans:-$default_hostname}
  fi

  ensure_hardware_config
  copy_repo_to_etc "$src_root"
  write_host_flake "$system" "$hostname"

  if [[ -n "$ACTION" ]]; then
    export NIX_CONFIG="experimental-features = nix-command flakes"
    case "$ACTION" in
      build) nixos-rebuild build --flake "/etc/nixos#$hostname" ;;
      test) nixos-rebuild test --flake "/etc/nixos#$hostname" ;;
      switch) nixos-rebuild switch --flake "/etc/nixos#$hostname" ;;
      *) echo "Invalid --action: $ACTION" >&2; exit 1;;
    esac
  else
    # Automated flow with minimal prompts: offer test first, then optional switch
    if ask_yes_no "Run a test activation (nixos-rebuild test) before full switch?" yes; then
      if ! nixos-rebuild test --flake "/etc/nixos#$hostname"; then
        if [[ -n "$DIALOG" ]]; then "$DIALOG" --msgbox "Test activation failed. Review configuration and retry." 10 70 || true; fi
        echo "Test activation failed." >&2
        exit 1
      fi
      if ask_yes_no "Test succeeded. Proceed with full switch now?" yes; then
        nixos-rebuild switch --flake "/etc/nixos#$hostname"
      else
        msg "Switch skipped per user choice."
      fi
    else
      if ask_yes_no "Proceed directly to full switch now?" yes; then
        nixos-rebuild switch --flake "/etc/nixos#$hostname"
      else
        msg "No rebuild performed."
      fi
    fi
  fi
}

main "$@"
