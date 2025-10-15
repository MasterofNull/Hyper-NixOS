#!/usr/bin/env bash
# Intelligent Template Processor
# Processes VM profile templates with AUTO_DETECT placeholders
# Part of Design Ethos - Third Pillar: Learning Through Guidance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/system_discovery.sh"

# Process intelligent template
# Usage: process_intelligent_template <template_file> [output_file]
process_intelligent_template() {
    local template_file=$1
    local output_file=${2:-/dev/stdout}
    
    if [ ! -f "$template_file" ]; then
        echo "Error: Template file not found: $template_file" >&2
        return 1
    fi
    
    # Detect system
    local cpu_cores=$(get_cpu_cores)
    local total_ram=$(get_total_ram_mb)
    local storage_type=$(detect_storage_type)
    local default_bridge=$(get_default_bridge)
    
    # Read OS type from template
    local os_type=$(jq -r '.os // "linux"' "$template_file" 2>/dev/null || echo "linux")
    
    # Calculate recommendations based on OS
    local min_vcpus=2
    local ram_per_vcpu=2048
    local min_ram=4096
    
    case "$os_type" in
        windows)
            min_vcpus=4
            ram_per_vcpu=4096
            min_ram=8192
            ;;
        linux|ubuntu|debian|fedora|arch)
            min_vcpus=2
            ram_per_vcpu=2048
            min_ram=4096
            ;;
    esac
    
    # Calculate values
    local rec_vcpus=$(calculate_recommended_vcpus "$cpu_cores" 25 "$min_vcpus")
    local rec_ram=$(calculate_recommended_ram "$total_ram" "$rec_vcpus" "$ram_per_vcpu")
    
    # Ensure minimum RAM
    if [ "$rec_ram" -lt "$min_ram" ]; then
        rec_ram=$min_ram
    fi
    
    local rec_disk_format=$(recommend_disk_format "$storage_type")
    
    # Process template and replace AUTO_DETECT values
    jq \
        --arg vcpus "$rec_vcpus" \
        --arg ram "$rec_ram" \
        --arg disk_format "$rec_disk_format" \
        --arg bridge "$default_bridge" \
        '
        # Replace AUTO_DETECT values
        if .cpus == "AUTO_DETECT" or .cpus == "AUTO_DETECT_MIN_4" then
            .cpus = ($vcpus | tonumber)
        else . end |
        
        if .memory_mb == "AUTO_DETECT" or .memory_mb == "AUTO_DETECT_MIN_8192" then
            .memory_mb = ($ram | tonumber)
        else . end |
        
        if .disk_format == "AUTO_DETECT" then
            .disk_format = $disk_format
        else . end |
        
        if .network.bridge == "AUTO_DETECT" then
            .network.bridge = $bridge
        else . end |
        
        # Add detection metadata
        ._intelligent_defaults = {
            "detected_at": now | strftime("%Y-%m-%d %H:%M:%S"),
            "host_cpu_cores": ($vcpus | tonumber),
            "host_ram_mb": ($ram | tonumber),
            "storage_type": $disk_format,
            "reasoning": {
                "vcpus": "Allocated 25% of \($vcpus) host cores for balanced performance",
                "memory": "Allocated 2-4GB per vCPU, not exceeding 50% of host RAM",
                "disk_format": "\($disk_format) optimal for detected storage type",
                "network": "Default bridge \($bridge) detected and configured"
            }
        }
        ' "$template_file" > "$output_file"
}

# Generate VM profile from intelligent template
# Usage: generate_vm_profile <template_name> <vm_name> [output_file]
generate_vm_profile() {
    local template_name=$1
    local vm_name=$2
    local output_file=${3:-/var/lib/hypervisor/vm_profiles/${vm_name}.json}
    
    local template_dir="/workspace/vm_profiles"
    local template_file="${template_dir}/${template_name}.json"
    
    if [ ! -f "$template_file" ]; then
        echo "Error: Template not found: $template_file" >&2
        echo "Available templates:" >&2
        ls -1 "$template_dir"/intelligent-*.json 2>/dev/null | sed 's/.*\///' | sed 's/\.json$//' >&2
        return 1
    fi
    
    # Process template
    process_intelligent_template "$template_file" > /tmp/processed_template.json
    
    # Update name
    jq --arg name "$vm_name" '.name = $name' /tmp/processed_template.json > "$output_file"
    
    rm -f /tmp/processed_template.json
    
    echo "Generated VM profile: $output_file"
    echo ""
    echo "Intelligent defaults applied:"
    jq -r '._intelligent_defaults.reasoning | to_entries[] | "  • \(.key): \(.value)"' "$output_file"
}

# List available intelligent templates
list_intelligent_templates() {
    local template_dir="/workspace/vm_profiles"
    
    echo "Available Intelligent Templates:"
    echo "================================="
    
    for template in "$template_dir"/intelligent-*.json; do
        if [ -f "$template" ]; then
            local name=$(basename "$template" .json)
            local desc=$(jq -r '.description // "No description"' "$template")
            echo "  • $name"
            echo "    $desc"
            echo ""
        fi
    done
}

# Export functions
export -f process_intelligent_template
export -f generate_vm_profile
export -f list_intelligent_templates
