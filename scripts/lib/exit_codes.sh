#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Exit Codes Library
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Standard exit codes for all Hyper-NixOS scripts
# Source this file after common.sh to use standardized exit codes
#

# Success
readonly EXIT_SUCCESS=0

# General errors (1-10)
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_MISSING_DEPENDENCY=2
readonly EXIT_PERMISSION_DENIED=3
readonly EXIT_INVALID_ARGUMENT=4
readonly EXIT_NETWORK_ERROR=5
readonly EXIT_CONFIG_ERROR=6
readonly EXIT_VM_ERROR=7
readonly EXIT_STORAGE_ERROR=8
readonly EXIT_TIMEOUT=9
readonly EXIT_USER_CANCEL=10

# File/IO errors (11-20)
readonly EXIT_FILE_NOT_FOUND=11
readonly EXIT_FILE_ACCESS_ERROR=12
readonly EXIT_DISK_FULL=13
readonly EXIT_IO_ERROR=14

# VM-specific errors (21-30)
readonly EXIT_VM_NOT_FOUND=21
readonly EXIT_VM_ALREADY_EXISTS=22
readonly EXIT_VM_RUNNING=23
readonly EXIT_VM_NOT_RUNNING=24
readonly EXIT_VM_LOCKED=25
readonly EXIT_VM_INVALID_STATE=26

# System errors (31-40)
readonly EXIT_SERVICE_ERROR=31
readonly EXIT_LIBVIRT_ERROR=32
readonly EXIT_QEMU_ERROR=33
readonly EXIT_MEMORY_ERROR=34
readonly EXIT_CPU_ERROR=35

# Security errors (41-50)
readonly EXIT_AUTH_FAILED=41
readonly EXIT_SECURITY_VIOLATION=42
readonly EXIT_CERTIFICATE_ERROR=43

# Helper function to exit with standardized message
exit_with_error() {
    local exit_code="$1"
    local message="$2"
    
    # Log the error
    log_error "Exit code $exit_code: $message"
    
    # Print to stderr
    echo "ERROR: $message" >&2
    
    # Exit with the specified code
    exit "$exit_code"
}

# Map exit codes to human-readable descriptions
get_exit_code_description() {
    local code="$1"
    case "$code" in
        0) echo "Success" ;;
        1) echo "General error" ;;
        2) echo "Missing dependency" ;;
        3) echo "Permission denied" ;;
        4) echo "Invalid argument" ;;
        5) echo "Network error" ;;
        6) echo "Configuration error" ;;
        7) echo "VM error" ;;
        8) echo "Storage error" ;;
        9) echo "Operation timeout" ;;
        10) echo "User cancelled" ;;
        11) echo "File not found" ;;
        12) echo "File access error" ;;
        13) echo "Disk full" ;;
        14) echo "I/O error" ;;
        21) echo "VM not found" ;;
        22) echo "VM already exists" ;;
        23) echo "VM is running" ;;
        24) echo "VM is not running" ;;
        25) echo "VM is locked" ;;
        26) echo "VM in invalid state" ;;
        31) echo "Service error" ;;
        32) echo "Libvirt error" ;;
        33) echo "QEMU error" ;;
        34) echo "Memory error" ;;
        35) echo "CPU error" ;;
        41) echo "Authentication failed" ;;
        42) echo "Security violation" ;;
        43) echo "Certificate error" ;;
        *) echo "Unknown error code: $code" ;;
    esac
}