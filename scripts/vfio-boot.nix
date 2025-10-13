{ config, lib, pkgs, ... }:

{
  # Note: All options are now centralized in modules/core/options.nix

  config = lib.mkIf config.hypervisor.vfio.enable {
    boot.kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];

    boot.initrd.kernelModules = [ "vfio" "vfio_pci" "vfio_iommu_type1" ];
    boot.kernelModules = [ "vfio_pci" ];

    # Bind specified PCI IDs to vfio-pci at boot
    boot.extraModprobeConfig = 
      if (config.hypervisor.vfio.pcieIds != []) 
      then (
        let ids = lib.concatStringsSep "," config.hypervisor.vfio.pcieIds; in
        ''
          options vfio-pci ids=${ids}
        ''
      )
      else "";
  };
}

