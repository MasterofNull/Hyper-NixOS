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
    users.users.${config.hypervisor.management.userName} = lib.mkDefault {
      isNormalUser = true;
      description = "Hypervisor Management User";
      extraGroups = [ "libvirtd" "kvm" "disk" "audio" "video" ];
      shell = pkgs.bash;
    };
    
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
    environment.systemPackages = with pkgs; [
      libvirt
      qemu
      bridge-utils
      dnsmasq
      ebtables
      iptables
      dmidecode
      pciutils
      usbutils
    ];
    
    # Enable KVM kernel modules
    boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
    
    # Enable IOMMU for PCI passthrough (if supported)
    boot.kernelParams = lib.mkDefault [
      "intel_iommu=on"
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