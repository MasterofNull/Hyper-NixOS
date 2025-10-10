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
RB_OPTS=(--refresh --option tarball-ttl 0 --option narinfo-cache-positive-ttl 0 --option narinfo-cache-negative-ttl 0)
REBOOT=false

# Wrapper: use a flake-capable nixos-rebuild even on older hosts
supports_flakes_flag() {
  nixos-rebuild --help 2>&1 | grep -q -- '--flake'
}

nr() {
  if supports_flakes_flag; then
    nixos-rebuild "$@"
  else
    nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nixos-rebuild -c nixos-rebuild "$@"
  fi
}

usage() {
  cat <<USAGE
Usage: sudo $(basename "$0") [--hostname NAME] [--action build|test|switch] [--force] [--source PATH] [--reboot]

Install Hyper‑NixOS from the current folder (USB checkout) into /etc/hypervisor,
write /etc/hypervisor/flake.nix (and symlink /etc/nixos/flake.nix), and optionally perform a one-shot rebuild.

Options:
  --hostname NAME     Host attribute and system hostname (default: current hostname)
  --action MODE       One of: build, test, switch. If omitted, show TUI menu.
  --force             Overwrite existing /etc/hypervisor without prompting
  --source PATH       Use PATH as source folder instead of auto-detect
  --reboot            Reboot after successful switch (recommended on fresh installs)
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
  local src_real dst_real
  src_real=$(readlink -f "$src_root" 2>/dev/null || echo "$src_root")
  dst_real=$(readlink -f "$dst_root" 2>/dev/null || echo "$dst_root")
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
    # If source resides under destination, stage a temporary copy to avoid
    # deleting our own source when we recreate the destination.
    if [[ "$src_real" == "$dst_real"* ]]; then
      local stage
      stage=$(mktemp -d -t hypervisor-stage.XXXXXX)
      rsync -a --exclude ".git/" --exclude "result" --exclude "target/" "$src_root/" "$stage/"
      # Now populate destination from the staged snapshot
      rsync -a --delete "$stage/" "$dst_root/"
      rm -rf -- "$stage"
    else
      rsync -a --delete --exclude ".git/" --exclude "result" --exclude "target/" "$src_root/" "$dst_root/"
    fi
  else
    # Fallback: copy via a temporary stage if needed
    if [[ "$src_real" == "$dst_real"* ]]; then
      local stage
      stage=$(mktemp -d -t hypervisor-stage.XXXXXX)
      shopt -s dotglob
      cp -a "$src_root"/* "$stage"/
      shopt -u dotglob
      shopt -s dotglob
      cp -a "$stage"/* "$dst_root"/
      shopt -u dotglob
      rm -rf -- "$stage"
    else
      shopt -s dotglob
      cp -a "$src_root"/* "$dst_root"/
      shopt -u dotglob
    fi
  fi
  # Permissive defaults for build/rebuild usability; optional hardening provided separately
  chown -R root:root "$dst_root" || true
  find "$dst_root" -type d -exec chmod 0755 {} + 2>/dev/null || true
  find "$dst_root" -type f -exec chmod 0644 {} + 2>/dev/null || true
  # Ensure scripts remain executable
  if [[ -d "$dst_root/scripts" ]]; then
    find "$dst_root/scripts" -type f -exec chmod 0755 {} + 2>/dev/null || true
  fi

  # Sanitize shebang typos that may exist in contributed scripts
  # Fix '/use/bin/env' -> '/usr/bin/env' on first line only
  find "$dst_root" -type f \
    -exec sed -i '1s|^#!/use/bin/env |#!/usr/bin/env |' {} + 2>/dev/null || true
  }

write_host_flake() {
  local system="$1"; shift
  local hostname="$1"; shift
  local flake_path="/etc/hypervisor/flake.nix"
  install -m 0644 /dev/null "$flake_path"
  # Determine hypervisor input: prefer pinned Git commit from source if available; fall back to repo head
  local repo_url="github:MasterofNull/Hyper-NixOS"
  local pinned_url="$repo_url"
  if command -v git >/dev/null 2>&1 && [[ -n "${SRC_OVERRIDE:-}" ]] && git -C "$SRC_OVERRIDE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local rev
    rev=$(git -C "$SRC_OVERRIDE" rev-parse HEAD 2>/dev/null || true)
    if [[ -n "$rev" ]]; then pinned_url="$repo_url/$rev"; fi
  fi
  cat > "$flake_path" <<'FLAKE'
{
  description = "Hyper‑NixOS Host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # Use a Git input to avoid path narHash issues; host overrides live under /var/lib/hypervisor/configuration
    hypervisor.url = "__HYP_URL__";
  };

  outputs = { self, nixpkgs, hypervisor }:
    let
      system = "__SYSTEM__";
    in {
      nixosConfigurations.__HOST__ = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          /etc/nixos/hardware-configuration.nix
          (hypervisor + "/configuration/configuration.nix")
        ];
      };
    };

  nixConfig = { experimental-features = [ "nix-command" "flakes" ]; };
}
FLAKE
  sed -i "s|__SYSTEM__|$system|" "$flake_path"
  sed -i "s|__HOST__|$hostname|" "$flake_path"
  sed -i "s|__HYP_URL__|$pinned_url|" "$flake_path"

  # Ensure /etc/nixos points at this flake (symlink for compatibility)
  mkdir -p /etc/nixos
  if [[ -e /etc/nixos/flake.nix && ! -L /etc/nixos/flake.nix ]]; then
    mv /etc/nixos/flake.nix "/etc/nixos/flake.nix.bak.$(date +%s)" || true
  fi
  ln -sfn "$flake_path" /etc/nixos/flake.nix || true
}

escape_nix_string() {
  # Escape backslashes and double quotes for Nix string literals
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

detect_primary_users() {
  # Print login-capable non-system users, skip builders and nologin shells
  # Criteria: uid >= 1000, < 65534, shell not nologin/false, exclude nobody and nixbld*
  awk -F: '($3 >= 1000 && $3 < 65534 && $1 != "nobody" && $1 !~ /^nixbld[0-9]+$/ && $7 !~ /nologin|false/) { print $1 }' /etc/passwd || true
}

write_users_local_nix() {
  local dest_dir="/etc/hypervisor/configuration"
  local dest_file="$dest_dir/users-local.nix"
  local state_dir="/var/lib/hypervisor/configuration"

  mkdir -p "$dest_dir"
  # If exists, check for known problematic entries and regenerate if needed
  if [[ -f "$dest_file" ]]; then
    if grep -Eq 'nixbld[0-9]+' "$dest_file" 2>/dev/null; then
      msg "users-local.nix contains nixbld entries; regenerating a filtered version"
      cp -a "$dest_file" "$dest_file.bak.$(date +%s)" || true
    else
      msg "users-local.nix already exists; skipping carryover generation"
      return 0
    fi
  fi

  local users; mapfile -t users < <(detect_primary_users)
  if (( ${#users[@]} == 0 )); then
    msg "No primary users detected (uid >= 1000). Skipping users-local.nix"
    return 0
  fi

  # If multiple, prefer interactive choice when TUI available; otherwise take the first
  local selected=("${users[@]}")
  if (( ${#users[@]} > 1 )) && [[ -n "$DIALOG" && -t 1 ]]; then
    local items=()
    for u in "${users[@]}"; do items+=("$u" " "); done
    local picked
    picked=$("$DIALOG" --checklist "Select user(s) to carry over" 18 70 8 "${items[@]}" 3>&1 1>&2 2>&3 || true)
    if [[ -n "$picked" ]]; then
      # whiptail/dialog returns quoted names; normalize
      read -r -a selected <<<"$picked"
      # Strip quotes from each entry
      for i in "${!selected[@]}"; do selected[$i]="${selected[$i]//\"/}"; done
    fi
  fi

  {
    echo '{ config, lib, pkgs, ... }:'
    echo '{'
    echo '  users.users = {'
    for user in "${selected[@]}"; do
      [[ -z "$user" ]] && continue
      # Skip known system/builder accounts defensively
      if [[ "$user" =~ ^nixbld[0-9]+$ ]] || [[ "$user" == "root" ]] || [[ "$user" == "nobody" ]] || [[ "$user" == "hypervisor" ]]; then
        continue
      fi
      # Gather user details
      local hash groups
      hash=$(awk -F: -v u="$user" '($1==u){print $2}' /etc/shadow 2>/dev/null || true)
      # If hash looks locked ("!" or "*"), omit it
      if [[ "$hash" == '!' || "$hash" == '*' || -z "$hash" ]]; then
        hash=""
      fi
      # Collect existing groups and ensure access groups
      groups=$(id -nG "$user" 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')
      # Ensure these are present
      for g in wheel kvm libvirtd video; do
        if ! grep -qE "(^| )$g( |$)" <<<"$groups"; then groups+="$g "; fi
      done
      # Emit Nix stanza
      echo "    ${user} = {"
      echo "      isNormalUser = true;"
      echo -n "      extraGroups = ["
      for g in $groups; do echo -n " \"$g\""; done
      echo " ];"
      echo "      createHome = true;"
      if [[ -n "$hash" ]]; then
        local esc; esc=$(escape_nix_string "$hash")
        echo "      hashedPassword = \"$esc\";"
      fi
      echo "    };"
    done
    echo '  };'
    echo '}'
  } >"$dest_file"

  # Mirror into state directory to avoid mutating the flake input path
  mkdir -p "$state_dir"
  cp "$dest_file" "$state_dir/users-local.nix"

  chmod 0600 "$dest_file" || true
  msg "Wrote $dest_file (permissions 0600)"
}

write_system_local_nix() {
  local dest_dir="/etc/hypervisor/configuration"
  local dest_file="$dest_dir/system-local.nix"
  local state_dir="/var/lib/hypervisor/configuration"
  mkdir -p "$dest_dir"
  # Do not overwrite if already present
  if [[ -f "$dest_file" ]]; then
    msg "system-local.nix already exists; skipping carryover generation"
    return 0
  fi

  local host tz locale keymap swap_uuid
  host=$(hostname -s 2>/dev/null || echo hypervisor)
  # Prefer nixos-option for accuracy; fall back if missing
  if command -v nixos-option >/dev/null 2>&1; then
    tz=$(nixos-option time.timeZone 2>/dev/null | sed -n 's/^[^=]*= \"\(.*\)\".*/\1/p' | head -n1 || true)
    locale=$(nixos-option i18n.defaultLocale 2>/dev/null | sed -n 's/^[^=]*= \"\(.*\)\".*/\1/p' | head -n1 || true)
    keymap=$(nixos-option console.keyMap 2>/dev/null | sed -n 's/^[^=]*= \"\(.*\)\".*/\1/p' | head -n1 || true)
  fi
  # Fallbacks
  if [[ -z "$tz" && -L /etc/localtime ]]; then
    tz=$(readlink -f /etc/localtime | sed -n 's#^.*/zoneinfo/\(.*\)$#\1#p')
  fi
  # Try to discover swap by label/uuid
  swap_uuid=$(blkid -t TYPE=swap -o value -s UUID 2>/dev/null | head -n1 || true)

  {
    echo '{ config, lib, pkgs, ... }:'
    echo '{'
    echo "  networking.hostName = lib.mkForce \"$(escape_nix_string "$host")\";"
    if [[ -n "$tz" ]]; then echo "  time.timeZone = lib.mkForce \"$(escape_nix_string "$tz")\";"; fi
    if [[ -n "$locale" ]]; then echo "  i18n.defaultLocale = lib.mkForce \"$(escape_nix_string "$locale")\";"; fi
    if [[ -n "$keymap" ]]; then echo "  console.keyMap = lib.mkForce \"$(escape_nix_string "$keymap")\";"; fi
    # Enable time synchronization by default for reliability during builds
    echo '  services.timesyncd.enable = true;'
    if [[ -n "$swap_uuid" ]]; then
      echo '  swapDevices = [{'
      echo "    device = \"/dev/disk/by-uuid/$swap_uuid\";"
      echo '  }];'
      echo '  powerManagement.resumeDevice = lib.mkDefault (builtins.head (builtins.filter (d: builtins.match ".*swap.*" d != null) (map (d: d.device or "") config.swapDevices) ++ ["/dev/disk/by-uuid/'"$swap_uuid"'"]));'
    fi
    echo '}'
  } >"$dest_file"

  # Mirror into state directory to avoid mutating the flake input path
  mkdir -p "$state_dir"
  cp "$dest_file" "$state_dir/system-local.nix"

  chmod 0644 "$dest_file" || true
  msg "Wrote $dest_file"
}

rebuild_menu() {
  local host="$1"
  local attr="/etc/hypervisor#$host"
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
    build) nr build --impure --flake "$attr" "${RB_OPTS[@]}" ;;
    test) nr test --impure --flake "$attr" "${RB_OPTS[@]}" ;;
    switch)
      nr switch --impure --flake "$attr" "${RB_OPTS[@]}"
      if $REBOOT; then
        systemctl reboot
      else
        systemctl daemon-reload || true
        systemctl enable --now hypervisor-menu.service || true
        command -v chvt >/dev/null 2>&1 && chvt 1 || true
      fi
      ;;
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
      --reboot) REBOOT=true; shift;;
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
    "$DIALOG" --msgbox "We will copy Hyper‑NixOS files to /etc/hypervisor and generate /etc/hypervisor/flake.nix (symlinked from /etc/nixos/flake.nix) for '$hostname' on $system." 12 70 || true
  else
    read -r -p "Hostname [$default_hostname]: " ans || true
    hostname=${ans:-$default_hostname}
  fi

  ensure_hardware_config
  copy_repo_to_etc "$src_root"
  write_host_flake "$system" "$hostname"

  # Generate carry-over local modules for users and base system settings
  write_users_local_nix
  write_system_local_nix

  # Ensure flake.lock reflects the current /etc/hypervisor input (after local files were generated)
  export NIX_CONFIG="experimental-features = nix-command flakes"
  nix flake lock --update-input hypervisor --flake /etc/hypervisor || true

  if [[ -n "$ACTION" ]]; then
    export NIX_CONFIG="experimental-features = nix-command flakes"
    case "$ACTION" in
      build) nr build --impure --flake "/etc/hypervisor#$hostname" "${RB_OPTS[@]}" ;;
      test) nr test --impure --flake "/etc/hypervisor#$hostname" "${RB_OPTS[@]}" ;;
      switch)
        nr switch --impure --flake "/etc/hypervisor#$hostname" "${RB_OPTS[@]}"
        if $REBOOT; then
          systemctl reboot
        else
          systemctl daemon-reload || true
          systemctl enable --now hypervisor-menu.service || true
          command -v chvt >/dev/null 2>&1 && chvt 1 || true
        fi
        ;;
      *) echo "Invalid --action: $ACTION" >&2; exit 1;;
    esac
  else
    # Automated flow with minimal prompts: offer test first, then optional switch
    if ask_yes_no "Run a test activation (nixos-rebuild test) before full switch?" yes; then
      if ! nr test --impure --flake "/etc/hypervisor#$hostname" "${RB_OPTS[@]}"; then
        if [[ -n "$DIALOG" ]]; then "$DIALOG" --msgbox "Test activation failed. Review configuration and retry." 10 70 || true; fi
        echo "Test activation failed." >&2
        exit 1
      fi
      if ask_yes_no "Test succeeded. Proceed with full switch now?" yes; then
        nr switch --impure --flake "/etc/hypervisor#$hostname" "${RB_OPTS[@]}"
        if $REBOOT; then
          systemctl reboot
        else
          systemctl daemon-reload || true
          systemctl enable --now hypervisor-menu.service || true
          command -v chvt >/dev/null 2>&1 && chvt 1 || true
        fi
      else
        msg "Switch skipped per user choice."
      fi
    else
      if ask_yes_no "Proceed directly to full switch now?" yes; then
        nr switch --impure --flake "/etc/hypervisor#$hostname" "${RB_OPTS[@]}"
        if $REBOOT; then
          systemctl reboot
        else
          systemctl daemon-reload || true
          systemctl enable --now hypervisor-menu.service || true
          command -v chvt >/dev/null 2>&1 && chvt 1 || true
        fi
      else
        msg "No rebuild performed."
      fi
    fi
  fi
}

main "$@"
