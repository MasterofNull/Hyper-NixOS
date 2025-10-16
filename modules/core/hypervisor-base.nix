{ config, lib, pkgs, ... }:

# Base Hypervisor Module
# Sets up core virtualization services when hypervisor.enable is true

{
  config = lib.mkIf config.hypervisor.enable {
    # Enable libvirt virtualization
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
      
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };
    
    # Enable virt-manager for GUI environments
    programs.virt-manager.enable = lib.mkDefault true;
    
    # Add hypervisor management user if it doesn't exist
    # CRITICAL: Only create when mutableUsers = true to prevent password wipes on rebuild
    users.users.${config.hypervisor.management.userName} = lib.mkIf config.users.mutableUsers (lib.mkDefault {
      isNormalUser = true;
      description = "Hypervisor Management User";
      extraGroups = [ "libvirtd" "kvm" "disk" "audio" "video" ];
      shell = pkgs.bash;
      # Password MUST be set after first boot with: passwd <username>
      # If using mutableUsers = false, you MUST set hashedPassword in your configuration.nix
    });
    
    # Ensure required groups exist
    users.groups.libvirtd.members = lib.mkDefault [ config.hypervisor.management.userName ];
    
    # Core hypervisor directories
    systemd.tmpfiles.rules = [
      "d /etc/hypervisor 0755 root root - -"
      "d /etc/hypervisor/scripts 0755 root root - -"
      "d /etc/hypervisor/config 0755 root root - -"
      "d /var/lib/hypervisor 0755 ${config.hypervisor.management.userName} users - -"
      "d /var/log/hypervisor 0755 ${config.hypervisor.management.userName} users - -"
    ];
    
    # Basic packages for hypervisor functionality
    environment.systemPackages = [
      pkgs.libvirt
      pkgs.qemu
      pkgs.bridge-utils
      pkgs.dnsmasq
      pkgs.ebtables
      pkgs.iptables
      pkgs.dmidecode
      pkgs.pciutils
      pkgs.usbutils
    ];
    
    # Enable KVM kernel modules
    # Note: Both modules are loaded by default. The kernel will only use the one
    # that matches your CPU. You may see a harmless warning about the other module
    # already being loaded. To suppress this, you can set:
    # boot.kernelModules = [ "kvm-amd" ];  # For AMD CPUs
    # boot.kernelModules = [ "kvm-intel" ]; # For Intel CPUs
    boot.kernelModules = lib.mkDefault [ "kvm-intel" "kvm-amd" ];
    
    # Enable IOMMU for PCI passthrough (if supported)
    # Note: Both Intel and AMD IOMMU parameters are included.
    # The kernel ignores parameters for hardware it doesn't have.
    boot.kernelParams = lib.mkDefault [
      "intel_iommu=on"
      "amd_iommu=on"
      "iommu=pt"
    ];
    
    # Sysctl settings for virtualization
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
      "vm.swappiness" = 10;
    };
    
    # Enable nested virtualization
    boot.extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_amd nested=1
    '';
    
    # Security settings for virtualization
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.libvirt.unix.manage" &&
            subject.isInGroup("libvirtd")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}