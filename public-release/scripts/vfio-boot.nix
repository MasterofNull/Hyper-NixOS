{ config, lib, pkgs, ... }:

{
  options.hypervisor.vfio = {
    enable = lib.mkEnableOption "Enable VFIO/IOMMU for PCI passthrough";
    pcieIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "10de:1b80" "10de:10f0" ];
      description = "List of PCI vendor:device IDs to bind to vfio-pci";
    };
  };

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

