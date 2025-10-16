{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.performanceTuning;
in
{
  options.hypervisor.network.performanceTuning = {
    enable = lib.mkEnableOption "Network performance tuning";
    tcpCongestion = lib.mkOption { type = lib.types.str; default = "bbr"; };
    jumboFrames = lib.mkOption { type = lib.types.bool; default = false; };
  };
  
  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = cfg.tcpCongestion;
      "net.core.rmem_max" = lib.mkIf cfg.jumboFrames 134217728;
      "net.core.wmem_max" = lib.mkIf cfg.jumboFrames 134217728;
    };
  };
}
