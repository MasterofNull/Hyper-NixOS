{ config, lib, pkgs, ... }:
let cfg = config.hypervisor.storage-management.distributed;
in {
  options.hypervisor.storage-management.distributed.enable = lib.mkEnableOption "distributed feature";
  config = lib.mkIf cfg.enable {
    environment.etc."hypervisor/features/distributed.conf".text = ''
      FEATURE_NAME="distributed"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
    '';
  };
}
