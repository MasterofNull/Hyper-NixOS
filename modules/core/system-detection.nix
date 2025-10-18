# Hyper-NixOS System Detection and Capabilities Module
# Centralizes hardware detection and capability checking

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.systemDetection;
  
  # System detection script that consolidates existing detection logic
  systemDetectionScript = pkgs.writeScriptBin "hv-detect-system" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Output format (json, text, or silent)
    OUTPUT_FORMAT="''${1:-json}"
    
    # Initialize detection results
    declare -A CAPABILITIES
    declare -A HARDWARE
    
    # CPU Detection
    HARDWARE["cpu_count"]=$(${pkgs.coreutils}/bin/nproc)
    HARDWARE["cpu_model"]=$(${pkgs.gawk}/bin/awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)
    
    # Memory Detection
    MEM_KB=$(${pkgs.gnugrep}/bin/grep MemTotal /proc/meminfo | ${pkgs.gawk}/bin/awk '{print $2}')
    HARDWARE["ram_mb"]=$((MEM_KB / 1024))
    HARDWARE["ram_gb"]=$((MEM_KB / 1024 / 1024))
    
    # Disk Detection
    HARDWARE["disk_gb"]=$(${pkgs.coreutils}/bin/df -BG / | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.gawk}/bin/awk '{print $4}' | ${pkgs.gnused}/bin/sed 's/G//')
    
    # Architecture
    HARDWARE["arch"]=$(${pkgs.coreutils}/bin/uname -m)

    # Detect if ARM architecture
    if [[ "''${HARDWARE["arch"]}" =~ ^(aarch64|armv7l|armv8)$ ]]; then
        HARDWARE["is_arm"]="true"

        # ARM platform detection
        if ${pkgs.gnugrep}/bin/grep -qi "Raspberry Pi 5" /proc/cpuinfo 2>/dev/null; then
            HARDWARE["arm_platform"]="rpi5"
        elif ${pkgs.gnugrep}/bin/grep -qi "Raspberry Pi 4" /proc/cpuinfo 2>/dev/null; then
            HARDWARE["arm_platform"]="rpi4"
        elif ${pkgs.gnugrep}/bin/grep -qi "Raspberry Pi 3" /proc/cpuinfo 2>/dev/null; then
            HARDWARE["arm_platform"]="rpi3"
        elif ${pkgs.gnugrep}/bin/grep -qi "rockchip.*rk3399" /proc/cpuinfo 2>/dev/null; then
            HARDWARE["arm_platform"]="rockpro64"
        else
            HARDWARE["arm_platform"]="generic-arm"
        fi
    else
        HARDWARE["is_arm"]="false"
        HARDWARE["arm_platform"]="none"
    fi

    # Virtualization Capabilities (x86 and ARM)
    if [[ "''${HARDWARE["is_arm"]}" == "true" ]]; then
        # ARM virtualization detection
        if ${pkgs.gnugrep}/bin/grep -q -E 'Features.*:.*fp' /proc/cpuinfo && \
           [[ -e /dev/kvm ]]; then
            CAPABILITIES["cpu_virt"]="true"
            HARDWARE["virt_type"]="ARM KVM"
        else
            CAPABILITIES["cpu_virt"]="false"
            HARDWARE["virt_type"]="none"
        fi
    else
        # x86 virtualization detection
        if ${pkgs.gnugrep}/bin/grep -q -E '(vmx|svm)' /proc/cpuinfo; then
            CAPABILITIES["cpu_virt"]="true"
            HARDWARE["virt_type"]=$(${pkgs.gnugrep}/bin/grep -q vmx /proc/cpuinfo && echo "Intel VT-x" || echo "AMD-V")
        else
            CAPABILITIES["cpu_virt"]="false"
            HARDWARE["virt_type"]="none"
        fi
    fi
    
    # AVX Support (for AI/ML workloads)
    if ${pkgs.gnugrep}/bin/grep -q avx /proc/cpuinfo; then
        CAPABILITIES["cpu_avx"]="true"
        if ${pkgs.gnugrep}/bin/grep -q avx2 /proc/cpuinfo; then
            CAPABILITIES["cpu_avx2"]="true"
        else
            CAPABILITIES["cpu_avx2"]="false"
        fi
    else
        CAPABILITIES["cpu_avx"]="false"
        CAPABILITIES["cpu_avx2"]="false"
    fi
    
    # GPU Detection (reuse existing hardware_detect.sh logic)
    if ${pkgs.pciutils}/bin/lspci 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E "(VGA|3D)" | ${pkgs.gnugrep}/bin/grep -iE "(nvidia|amd|intel)" > /dev/null; then
        CAPABILITIES["gpu_present"]="true"
        GPU_INFO=$(${pkgs.pciutils}/bin/lspci | ${pkgs.gnugrep}/bin/grep -E "(VGA|3D)" | head -1)
        if echo "$GPU_INFO" | ${pkgs.gnugrep}/bin/grep -qi nvidia; then
            HARDWARE["gpu_vendor"]="nvidia"
        elif echo "$GPU_INFO" | ${pkgs.gnugrep}/bin/grep -qi amd; then
            HARDWARE["gpu_vendor"]="amd"
        else
            HARDWARE["gpu_vendor"]="intel"
        fi
    else
        CAPABILITIES["gpu_present"]="false"
        HARDWARE["gpu_vendor"]="none"
    fi
    
    # IOMMU Detection (for passthrough)
    if [[ -d /sys/kernel/iommu_groups ]] && [[ $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l) -gt 0 ]]; then
        CAPABILITIES["iommu_enabled"]="true"
        HARDWARE["iommu_groups"]=$(ls /sys/kernel/iommu_groups | wc -l)
    else
        CAPABILITIES["iommu_enabled"]="false"
        HARDWARE["iommu_groups"]="0"
    fi
    
    # ECC RAM Detection (if dmidecode available)
    if command -v dmidecode >/dev/null 2>&1 && [[ $EUID -eq 0 ]]; then
        if dmidecode -t memory 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "Error Correction Type: Multi-bit ECC"; then
            CAPABILITIES["ram_ecc"]="true"
        else
            CAPABILITIES["ram_ecc"]="false"
        fi
    else
        CAPABILITIES["ram_ecc"]="unknown"
    fi
    
    # Network Interface Detection
    NIC_COUNT=$(${pkgs.iproute2}/bin/ip link show | ${pkgs.gnugrep}/bin/grep -c "^[0-9]" || echo 1)
    HARDWARE["nic_count"]=$NIC_COUNT
    if [[ $NIC_COUNT -gt 2 ]]; then
        CAPABILITIES["network_multi"]="true"
    else
        CAPABILITIES["network_multi"]="false"
    fi
    
    # Container/VM Detection
    VIRT_TYPE="none"
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT_TYPE=$(systemd-detect-virt || echo "none")
    fi
    HARDWARE["virt_environment"]="$VIRT_TYPE"
    
    # Output results based on format
    case "$OUTPUT_FORMAT" in
        json)
            # Build JSON output
            echo "{"
            echo '  "hardware": {'
            first=true
            for key in "''${!HARDWARE[@]}"; do
                [[ $first == true ]] && first=false || echo ","
                printf '    "%s": "%s"' "$key" "''${HARDWARE[$key]}"
            done
            echo ""
            echo '  },'
            echo '  "capabilities": {'
            first=true
            for key in "''${!CAPABILITIES[@]}"; do
                [[ $first == true ]] && first=false || echo ","
                printf '    "%s": %s' "$key" "''${CAPABILITIES[$key]}"
            done
            echo ""
            echo '  },'
            echo '  "recommended_tier": "'$(recommend_tier)'"'
            echo "}"
            ;;
        text)
            echo "=== Hardware Information ==="
            for key in "''${!HARDWARE[@]}"; do
                echo "$key: ''${HARDWARE[$key]}"
            done | sort
            echo ""
            echo "=== System Capabilities ==="
            for key in "''${!CAPABILITIES[@]}"; do
                echo "$key: ''${CAPABILITIES[$key]}"
            done | sort
            echo ""
            echo "=== Recommended Configuration ==="
            echo "Tier: $(recommend_tier)"
            ;;
        silent)
            # Just run detection, no output
            ;;
    esac
    
    # Helper function to recommend tier based on hardware
    recommend_tier() {
        local ram_gb=''${HARDWARE["ram_gb"]}
        local cpu_count=''${HARDWARE["cpu_count"]}
        
        if [[ $ram_gb -ge 32 ]] && [[ $cpu_count -ge 16 ]]; then
            echo "enterprise"
        elif [[ $ram_gb -ge 16 ]] && [[ $cpu_count -ge 8 ]]; then
            echo "professional"
        elif [[ $ram_gb -ge 8 ]] && [[ $cpu_count -ge 4 ]]; then
            echo "enhanced"
        elif [[ $ram_gb -ge 4 ]] && [[ $cpu_count -ge 4 ]]; then
            echo "standard"
        else
            echo "minimal"
        fi
    }
  '';
  
  # Cache file for detection results
  cacheFile = "/var/cache/hypervisor/system-detection.json";
  
in {
  options.hypervisor.systemDetection = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable system detection and capability checking";
    };
    
    cacheResults = mkOption {
      type = types.bool;
      default = true;
      description = "Cache detection results to avoid repeated hardware queries";
    };
    
    cacheMaxAge = mkOption {
      type = types.int;
      default = 86400; # 24 hours
      description = "Maximum age of cached results in seconds";
    };
    
    autoDetect = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically run detection on boot";
    };
    
    capabilities = mkOption {
      type = types.attrs;
      default = {};
      description = "Detected system capabilities (populated at runtime)";
    };
    
    hardware = mkOption {
      type = types.attrs;
      default = {};
      description = "Detected hardware information (populated at runtime)";
    };
  };
  
  config = mkIf cfg.enable {
    # Install detection script
    environment.systemPackages = [ systemDetectionScript ];
    
    # Create cache directory
    systemd.tmpfiles.rules = [
      "d /var/cache/hypervisor 0755 root root -"
      "d /var/lib/hypervisor 0755 root root -"
    ];
    
    # System detection service
    systemd.services.hypervisor-system-detection = mkIf cfg.autoDetect {
      description = "Hyper-NixOS System Detection";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${systemDetectionScript}/bin/hv-detect-system json";
        StandardOutput = "truncate:${cacheFile}";
        
        # Run with necessary privileges for hardware detection
        PrivilegeEscalation = true;
        CapabilityBoundingSet = [ "CAP_SYS_RAWIO" "CAP_SYS_ADMIN" ];
      };
      
      # Refresh cache periodically
      startAt = mkIf cfg.cacheResults "daily";
    };
    
    # Integration with feature manager
    environment.etc."hypervisor/detection-integration.sh" = {
      text = ''
        #!/bin/bash
        # Integration helper for feature manager and other tools
        
        get_cached_detection() {
          local cache_file="${cacheFile}"
          local max_age=${toString cfg.cacheMaxAge}
          
          # Check if cache exists and is recent
          if [[ -f "$cache_file" ]]; then
            local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
            if [[ $file_age -lt $max_age ]]; then
              cat "$cache_file"
              return 0
            fi
          fi
          
          # Run detection and cache results
          hv-detect-system json | tee "$cache_file"
        }
        
        # Check specific capability
        check_capability() {
          local capability="$1"
          local result=$(get_cached_detection | ${pkgs.jq}/bin/jq -r ".capabilities.$capability // \"false\"")
          [[ "$result" == "true" ]]
        }
        
        # Get hardware info
        get_hardware_info() {
          local key="$1"
          get_cached_detection | ${pkgs.jq}/bin/jq -r ".hardware.$key // \"unknown\""
        }
        
        # Export functions for use in other scripts
        export -f get_cached_detection check_capability get_hardware_info
      '';
      mode = "0755";
    };
    
    # Shell aliases for convenience
    environment.shellAliases = {
      "hv-detect" = "hv-detect-system";
      "hv-caps" = "hv-detect-system text | grep -A20 'System Capabilities'";
      "hv-hw" = "hv-detect-system text | grep -A20 'Hardware Information'";
    };
    
    # Update existing hardware_detect.sh to use this module
    system.activationScripts.updateHardwareDetect = ''
      # Link new detection to old location for compatibility
      if [[ -f /etc/hypervisor/src/scripts/hardware_detect.sh ]]; then
        # Backup original
        cp /etc/hypervisor/src/scripts/hardware_detect.sh \
           /etc/hypervisor/src/scripts/hardware_detect.sh.orig 2>/dev/null || true
        
        # Create wrapper that uses new detection
        cat > /etc/hypervisor/src/scripts/hardware_detect.sh << 'EOF'
      #!/usr/bin/env bash
      # Wrapper for compatibility with existing scripts
      # Now uses centralized system detection
      
      OUT_JSON="''${1:-}"
      
      # Use new detection system
      detection_output=$(hv-detect-system json)
      
      # Extract VFIO suggestions (maintain compatibility)
      gpu_vendor=$(echo "$detection_output" | jq -r '.hardware.gpu_vendor // "none"')
      vfio_ids=()
      
      if [[ "$gpu_vendor" != "none" ]]; then
        # Get PCI IDs for GPUs
        mapfile -t gpu_ids < <(lspci -Dn | awk '/VGA compatible controller|3D controller/ {print $3}')
        vfio_ids+=("''${gpu_ids[@]}")
      fi
      
      # CPU pinning suggestion
      cpu_count=$(echo "$detection_output" | jq -r '.hardware.cpu_count')
      reserve=$(( cpu_count>4 ? 2 : 1 ))
      pinning=()
      for ((i=reserve;i<cpu_count;i++)); do pinning+=("$i"); done
      
      # Build compatible output
      json=$(jq -n \
        --argjson ids "$(printf '%s\n' "''${vfio_ids[@]}" | jq -R . | jq -s .)" \
        --argjson pin "$(printf '%s\n' "''${pinning[@]}" | jq -R . | jq -s .)" \
        '{vfio_ids:$ids, cpu_pinning:$pin}')
      
      if [[ -n "''${OUT_JSON}" ]]; then
        echo "$json" > "$OUT_JSON"
      else
        echo "$json"
      fi
      EOF
        chmod +x /etc/hypervisor/src/scripts/hardware_detect.sh
      fi
    '';
  };
}