#!/usr/bin/env bash
#
# Check for potentially missing services in NixOS modules
# This helps prevent "option does not exist" errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/../../modules"

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

echo "Checking for potentially missing services in NixOS modules..."
echo "============================================================"

# Services that might not exist in minimal configurations
OPTIONAL_SERVICES=(
    "auditd"
    "fprintd"
    "acpid"
    "nginx"
    "pipewire"
    "victoriametrics"
    "nats"
    "rtkit"
    "apache-kafka"
    "elasticsearch"
    "redis"
    "postgresql"
    "mysql"
    "mongodb"
    "docker"
    "podman"
    "k3s"
    "kubernetes"
)

# Security options that might not exist
OPTIONAL_SECURITY=(
    "audit"
    "apparmor"
    "selinux"
    "grsecurity"
    "pax"
)

issues_found=0

# Function to check if a service is used without conditional checks
check_service_usage() {
    local service="$1"
    local type="$2"  # "services" or "security"
    
    echo -e "\nChecking for ${type}.${service}..."
    
    # Find files that reference this service
    files=$(grep -r "${type}\.${service}\." "$MODULES_DIR" --include="*.nix" 2>/dev/null | grep -v "mkIf.*${type}.*${service}" | grep -v "${type}\s*\?\s*${service}" || true)
    
    if [[ -n "$files" ]]; then
        # Check each file for conditional usage
        while IFS=: read -r file line_content; do
            # Skip if it's in a comment
            if echo "$line_content" | grep -q "^\s*#"; then
                continue
            fi
            
            # Skip if it's checking for existence
            if echo "$line_content" | grep -q "${type}\s*\?\s*${service}"; then
                continue
            fi
            
            # Check if the file has any conditional wrapper for this service
            if ! grep -B5 -A5 "$line_content" "$file" | grep -q "mkIf.*${type}.*${service}\|${type}\s*\?\s*${service}"; then
                echo -e "${YELLOW}WARNING${NC}: $file may use ${type}.${service} without checking if it exists"
                echo "  Line: $line_content"
                ((issues_found++))
            fi
        done <<< "$files"
    fi
}

# Check all optional services
for service in "${OPTIONAL_SERVICES[@]}"; do
    check_service_usage "$service" "services"
done

# Check all optional security options
for option in "${OPTIONAL_SECURITY[@]}"; do
    check_service_usage "$option" "security"
done

echo -e "\n============================================================"
if [[ $issues_found -eq 0 ]]; then
    echo -e "${GREEN}✓ No issues found!${NC} All optional services appear to have proper conditional checks."
else
    echo -e "${YELLOW}⚠ Found $issues_found potential issues${NC}"
    echo "These modules might fail if the corresponding services aren't available."
    echo "Consider adding conditional checks like:"
    echo "  lib.mkIf (config.services ? serviceName)"
    echo "  lib.mkIf (config.security ? optionName)"
fi