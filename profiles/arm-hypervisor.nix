# ARM-specific hypervisor profile
# Optimized for Raspberry Pi and other ARM single-board computers
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/core/arm-detection.nix
    ../modules/core/system-detection.nix
    ../modules/virtualization
    ../modules/security
  ];

  # Enable ARM support
  hypervisor.hardware.arm = {
    enable = true;
    autoDetect = true;
    virtualization.enable = true;

    optimizations = {
      enableCpuGovernor = true;
      enableZram = true; # Important for memory-constrained boards
    };
  };

  # Optimized virtualization for ARM
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;

      # ARM-specific QEMU options
      verbatimConfig = ''
        user = "root"
        group = "kvm"

        # Recommended for ARM performance
        dynamic_ownership = 1
        remember_owner = 0
      '';
    };
  };

  # Kernel optimizations for ARM virtualization
  boot.kernel.sysctl = {
    # Increase inotify limits for container management
    "fs.inotify.max_user_instances" = 256;
    "fs.inotify.max_user_watches" = 65536;

    # VM memory management
    "vm.swappiness" = 10; # Reduce swap usage
    "vm.vfs_cache_pressure" = 50; # Keep caches longer

    # Network performance
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 67108864";
    "net.ipv4.tcp_wmem" = "4096 65536 67108864";
  };

  # ARM-appropriate system tier
  # Most ARM boards will be enhanced or minimal
  hypervisor.systemTier = lib.mkDefault "enhanced";

  # Recommended features for ARM
  hypervisor.features = {
    vm-management.enable = true;
    networking.enable = true;
    security-baseline.enable = true;

    # Disable resource-intensive features by default
    ai-monitoring.enable = lib.mkDefault false;
    gpu-passthrough.enable = lib.mkDefault false;
  };

  # Security optimizations for ARM
  hypervisor.security = {
    profile = "baseline"; # Strict mode may be too resource-intensive
    privilegeSeparation.enable = true;
    passwordProtection.enable = true;
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
    ];
  };

  # Helpful ARM-specific packages
  environment.systemPackages = with pkgs; [
    htop
    iotop
    nethogs # Network monitoring
    stress-ng # Stress testing
    cpufrequtils # CPU frequency management
  ];

  # Service optimizations
  systemd.services = {
    # Reduce journald memory usage
    systemd-journald.serviceConfig = {
      SystemMaxUse = "50M";
      RuntimeMaxUse = "50M";
    };
  };

  # Documentation and guidance for ARM users
  environment.etc."hypervisor/README-ARM.txt".text = ''
    ╔═══════════════════════════════════════════════════════════════╗
    ║                    ARM Hypervisor Profile                      ║
    ╚═══════════════════════════════════════════════════════════════╝

    This system is running Hyper-NixOS optimized for ARM architecture.

    PLATFORM DETECTION
    ──────────────────
    Run: hv-detect-system
    This will show your specific ARM platform and capabilities.

    PERFORMANCE TIPS
    ────────────────
    1. ARM boards often have limited RAM - use lightweight VMs
    2. Consider Alpine Linux or similar minimal distributions for VMs
    3. Monitor temperature: watch -n 1 'cat /sys/class/thermal/thermal_zone*/temp'
    4. Use zram (already enabled) for memory compression

    LIMITATIONS
    ───────────
    - GPU passthrough is limited on most ARM boards
    - Nested virtualization may not be available
    - Some x86-only features are disabled

    RECOMMENDED VM CONFIGURATIONS
    ─────────────────────────────
    - Raspberry Pi 4 (8GB): 2-3 VMs with 2GB RAM each
    - Raspberry Pi 4 (4GB): 1-2 VMs with 1-2GB RAM each
    - RockPro64: 2-4 VMs with 1-2GB RAM each

    GETTING HELP
    ────────────
    Check documentation: /usr/share/doc/hypervisor/ARM_SUPPORT.md
    Run: hv help
  '';
}
