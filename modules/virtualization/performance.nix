{ config, lib, pkgs, ... }:
{

  config = lib.mkMerge [
    (lib.mkIf config.hypervisor.performance.enableHugepages {
      boot.kernelParams = [ "transparent_hugepage=never" ];
      # Example: reserve some hugepages; tune per host
      boot.kernel.sysctl."vm.nr_hugepages" = 512;
    })
    (lib.mkIf config.hypervisor.performance.disableSMT {
      boot.kernelParams = [ "nosmt" ];
    })
  ];
}
