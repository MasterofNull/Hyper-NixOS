{ config, lib, pkgs, ... }:
let cfg = config.hypervisor.enterprise.disaster_recovery;
in {
  options.hypervisor.enterprise.disaster_recovery.enable = lib.mkEnableOption "disaster-recovery feature";
  config = lib.mkIf cfg.enable {
    environment.etc."hypervisor/features/disaster-recovery.conf".text = ''
      FEATURE_NAME="disaster-recovery"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
    '';
  };
}
