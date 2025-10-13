{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.vfio;
in {
  options.hypervisor.vfio = {
    enable = lib.mkEnableOption "Enable VFIO/IOMMU for PCI passthrough";
    pcieIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "10de:1b80" "10de:10f0" ];
      description = "List of PCI vendor:device IDs to bind to vfio-pci.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];

    boot.initrd.kernelModules = [ "vfio" "vfio_pci" "vfio_iommu_type1" ];
    boot.kernelModules = [ "vfio_pci" ];

    # Bind specified PCI IDs to vfio-pci at boot
    boot.extraModprobeConfig = (
      let ids = lib.concatStringsSep "," cfg.pcieIds; in
      if cfg.pcieIds != [] then ''
        options vfio-pci ids=${ids}
      '' else ""
    );
  };
}

