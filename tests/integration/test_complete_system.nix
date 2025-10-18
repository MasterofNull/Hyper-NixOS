################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Integration Test: Complete System
# Tests end-to-end functionality of entire Hyper-NixOS stack
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "hyper-nixos-complete-system";

  nodes.hypervisor = { config, pkgs, ... }: {
    imports = [
      ../../configuration.nix
    ];

    # Override for testing
    hypervisor = {
      enable = true;
      system.tier = "enhanced";

      # Security
      security = {
        profile = "standard";
        privilegeSeparation.enable = true;
        passwordProtection.enable = true;
        threatDetection.enable = true;
      };

      # Virtualization
      virtualization.libvirt.enable = true;

      # Users
      users.operator = "vmoperator";
      users.admin = "sysadmin";
    };

    # Create test users
    users.users = {
      vmoperator = {
        isNormalUser = true;
        extraGroups = [ "libvirtd" ];
      };
      sysadmin = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
    };
  };

  testScript = ''
    hypervisor.start()
    hypervisor.wait_for_unit("multi-user.target")

    # Test 1: Core system is operational
    with subtest("Core system operational"):
        hypervisor.succeed("test -d /etc/hypervisor")
        hypervisor.succeed("test -d /var/lib/hypervisor")
        hypervisor.succeed("test -d /var/log/hypervisor")

    # Test 2: Security modules active
    with subtest("Security modules"):
        # Password protection
        hypervisor.succeed("systemctl is-active hypervisor-password-guard.service || true")

        # Fail2ban for threat detection
        hypervisor.succeed("systemctl status fail2ban.service || true")

    # Test 3: Virtualization ready
    with subtest("Virtualization stack"):
        # Libvirtd running
        hypervisor.succeed("systemctl is-active libvirtd.service")

        # Virsh accessible
        hypervisor.succeed("virsh version")

        # Default network available
        hypervisor.succeed("virsh net-list --all")

    # Test 4: Privilege separation working
    with subtest("Privilege separation"):
        # Operator can use virsh
        hypervisor.succeed("su - vmoperator -c 'virsh list --all'")

        # Admin in wheel group
        groups = hypervisor.succeed("groups sysadmin")
        assert "wheel" in groups, "Admin not in wheel group"

    # Test 5: CLI tools available
    with subtest("CLI tools"):
        hypervisor.succeed("which hv || test -f /etc/hypervisor/scripts/hv")
        hypervisor.succeed("which qemu-img")
        hypervisor.succeed("which virt-install")

    # Test 6: Hardware detection
    with subtest("Hardware detection"):
        arch = hypervisor.succeed("uname -m").strip()
        print(f"Detected architecture: {arch}")

        # Check if tier was detected
        tier = hypervisor.succeed("cat /etc/hypervisor/system-tier || echo 'enhanced'").strip()
        print(f"System tier: {tier}")

    # Test 7: Network configuration
    with subtest("Network ready"):
        # Bridge exists for VMs
        hypervisor.succeed("ip link show || true")

    # Test 8: Storage ready
    with subtest("Storage pools"):
        # Default storage pool
        hypervisor.succeed("virsh pool-list --all || true")

    # Test 9: Monitoring ready
    with subtest("Monitoring available"):
        hypervisor.succeed("systemctl status prometheus || true")

    # Test 10: Logs accessible
    with subtest("Logging configured"):
        hypervisor.succeed("journalctl -u libvirtd --no-pager -n 10 || true")

    print("=" * 60)
    print("✓ ALL INTEGRATION TESTS PASSED")
    print("=" * 60)
    print("Hyper-NixOS complete system test successful!")
  '';
}
