{ config, lib, pkgs, ... }:
let cfg = config.hypervisor.monitoring.metrics_export;
in {
  options.hypervisor.monitoring.metrics_export.enable = lib.mkEnableOption "metrics-export feature";
  config = lib.mkIf cfg.enable {
    environment.etc."hypervisor/features/metrics-export.conf".text = ''
      FEATURE_NAME="metrics-export"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
    '';
  };
}
