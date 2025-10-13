#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"
trap 'exit $?' EXIT HUP INT TERM

# Generate a cloud-init seed ISO (cidata)
# Usage: cloud_init_seed.sh <output_iso> <user_data> <meta_data> [network_config]

out_iso="$1"; user_data="$2"; meta_data="$3"; net_cfg="${4:-}"
if [[ -z "$out_iso" || -z "$user_data" || -z "$meta_data" ]]; then
  echo "Usage: $0 <output_iso> <user_data> <meta_data> [network_config]" >&2
  exit 2
fi

require() { for b in genisoimage xorriso; do command -v "$b" >/dev/null 2>&1 || true; done }

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

cp "$user_data" "$workdir/user-data"
cp "$meta_data" "$workdir/meta-data"
[[ -n "$net_cfg" ]] && cp "$net_cfg" "$workdir/network-config"

if command -v genisoimage >/dev/null 2>&1; then
  genisoimage -output "$out_iso" -volid cidata -joliet -rock "$workdir/user-data" "$workdir/meta-data" ${net_cfg:+"$workdir/network-config"}
elif command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -o "$out_iso" -V cidata -J -R "$workdir/user-data" "$workdir/meta-data" ${net_cfg:+"$workdir/network-config"}
else
  echo "Missing genisoimage/xorriso" >&2; exit 1
fi

echo "$out_iso"
