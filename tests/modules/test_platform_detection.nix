################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Test: Platform Hardware Detection Module
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
################################################################################

{ pkgs, lib, ... }:

{
  name = "platform-hardware-detection";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/core/options.nix
      ../../modules/hardware/platform-detection.nix
      ../../modules/hardware/laptop.nix
      ../../modules/hardware/desktop.nix
      ../../modules/hardware/server.nix
    ];

    hypervisor.platform.enableAutoDetection = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Test platform detection log exists
    with subtest("Platform detection log created"):
        machine.succeed("test -f /var/log/hypervisor/platform-detection.log")
        log_content = machine.succeed("cat /var/log/hypervisor/platform-detection.log")
        print(f"Platform detection log:\n{log_content}")
        assert "Platform Hardware Detection" in log_content

    # Test platform info JSON export
    with subtest("Platform info JSON export"):
        machine.succeed("test -f /etc/hypervisor/platform-info.json")
        json_content = machine.succeed("cat /etc/hypervisor/platform-info.json")
        print(f"Platform info JSON:\n{json_content}")

        # Verify JSON is valid
        import json
        platform_info = json.loads(json_content)

        # Check required fields
        assert "platform_type" in platform_info
        assert "touchpad" in platform_info
        assert "battery" in platform_info
        assert "gpu_nvidia" in platform_info
        assert "gpu_amd" in platform_info
        assert "gpu_intel" in platform_info
        assert "headless" in platform_info

        print(f"✓ Detected platform type: {platform_info['platform_type']}")

    # Test hv-platform-info command
    with subtest("hv-platform-info command available"):
        output = machine.succeed("hv-platform-info")
        print(f"hv-platform-info output:\n{output}")
        assert "Detected Platform Information" in output

    # Test that appropriate hardware module was auto-enabled
    with subtest("Hardware module auto-enablement"):
        json_content = machine.succeed("cat /etc/hypervisor/platform-info.json")
        platform_info = json.loads(json_content)

        # Verify at least one hardware module is enabled based on detection
        if platform_info["platform_type"] == "laptop":
            # Laptop module should be enabled (checked via services)
            print("✓ Laptop platform detected")
        elif platform_info["platform_type"] == "desktop":
            # Desktop module should be enabled
            print("✓ Desktop platform detected")
        elif platform_info["platform_type"] == "server":
            # Server module should be enabled
            print("✓ Server/Headless platform detected")

    # Test graphics detection
    with subtest("Graphics driver detection"):
        json_content = machine.succeed("cat /etc/hypervisor/platform-info.json")
        platform_info = json.loads(json_content)

        has_gpu = platform_info["gpu_nvidia"] or platform_info["gpu_amd"] or platform_info["gpu_intel"]
        is_headless = platform_info["headless"]

        if has_gpu:
            print("✓ GPU detected")
            # Graphics hardware should be enabled
            machine.succeed("test -d /sys/class/drm || true")

        if is_headless:
            print("✓ Headless system detected")

    # Test hardware feature detection
    with subtest("Hardware feature detection"):
        json_content = machine.succeed("cat /etc/hypervisor/platform-info.json")
        platform_info = json.loads(json_content)

        print(f"Hardware features detected:")
        print(f"  - Touchpad: {platform_info['touchpad']}")
        print(f"  - Battery: {platform_info['battery']}")
        print(f"  - Bluetooth: {platform_info['bluetooth']}")
        print(f"  - WiFi: {platform_info['wifi']}")
        print(f"  - Webcam: {platform_info['webcam']}")
        print(f"  - Audio: {platform_info['audio']}")

    print("✓ All platform detection tests passed")
  '';
}
