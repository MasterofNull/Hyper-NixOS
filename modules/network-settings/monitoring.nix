{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.monitoring;
in
{
  options.hypervisor.network.monitoring = {
    enable = lib.mkEnableOption "Network monitoring";
    interfaces = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
    prometheus = lib.mkOption { type = lib.types.bool; default = true; };
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ iftop nethogs bmon ];
    system.activationScripts.monitoring = ''echo "Monitoring: ${toString cfg.interfaces}" >&2'';
  };
}
