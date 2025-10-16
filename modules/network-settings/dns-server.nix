{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.dnsServer;
  phaseConfig = config.hypervisor.security.phaseManagement or { currentPhase = 1; };
in
{
  options.hypervisor.network.dnsServer = {
    enable = lib.mkEnableOption "DNS server with ad-blocking";
    upstream = lib.mkOption { type = lib.types.listOf lib.types.str; default = ["1.1.1.1" "8.8.8.8"]; };
    adBlocking = {
      enable = lib.mkOption { type = lib.types.bool; default = true; };
      lists = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
    };
  };
  
  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      settings = {
        server = cfg.upstream;
        cache-size = 10000;
      };
    };
    system.activationScripts.dns-setup = ''echo "DNS Server enabled" >&2'';
  };
}
