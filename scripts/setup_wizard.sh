#!/usr/bin/env bash
#
# Compatibility shim for historical setup wizard path checks.
# The first-boot wizard is the maintained entrypoint.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
exec "$SCRIPT_DIR/first-boot-wizard.sh" "$@"
