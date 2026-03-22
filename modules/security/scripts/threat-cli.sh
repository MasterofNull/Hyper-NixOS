#! /usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Hyper-NixOS threat tooling

Usage:
  hv-threats status
  hv-threats tail
  hv-threats help
EOF
}

cmd="${1:-help}"

case "$cmd" in
  status)
    if systemctl is-active hypervisor-threat-detection.service >/dev/null 2>&1; then
      echo "threat-detection: active"
    else
      echo "threat-detection: inactive"
    fi
    ;;
  tail)
    exec journalctl -u hypervisor-threat-detection.service -n 50 --no-pager
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
