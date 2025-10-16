{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.loadBalancer;
in
{
  options.hypervisor.network.loadBalancer = {
    enable = lib.mkEnableOption "Load balancing";
    algorithm = lib.mkOption { type = lib.types.enum ["roundrobin" "leastconn" "source"]; default = "roundrobin"; };
  };
  
  config = lib.mkIf cfg.enable {
    system.activationScripts.lb = ''echo "Load balancer enabled" >&2'';
  };
}
