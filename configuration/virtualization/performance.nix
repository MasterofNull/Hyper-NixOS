{ config, lib, pkgs, ... }:
{
  options.hypervisor.performance = {
    enableHugepages = lib.mkEnableOption "Enable hugepages (can improve performance, reduces memory flexibility)";
    disableSMT = lib.mkEnableOption "Disable SMT/Hyper-Threading (mitigates side-channels; can reduce throughput)";
  };

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
