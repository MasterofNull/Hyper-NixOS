{ config, lib, pkgs, ... }:
let cfg = config.hypervisor.monitoring.tracing;
in {
  options.hypervisor.monitoring.tracing.enable = lib.mkEnableOption "distributed tracing with Jaeger";
  config = lib.mkIf cfg.enable {
    services.jaegertracing = {
      enable = true;
      collector.enable = true;
      query.enable = true;
    };
    environment.etc."hypervisor/features/tracing.conf".text = "FEATURE_NAME=tracing\nFEATURE_STATUS=enabled";
  };
}
