#!/usr/bin/env bash
#
# Compatibility shim for historical security audit path checks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
exec "$SCRIPT_DIR/audit/quick_security_audit.sh" "$@"
