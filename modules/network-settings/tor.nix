{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.tor;
in
{
  options.hypervisor.network.tor = {
    enable = lib.mkEnableOption "Tor integration";
    transparentProxy = lib.mkOption { type = lib.types.bool; default = false; };
  };
  
  config = lib.mkIf cfg.enable {
    services.tor = {
      enable = true;
      client.enable = true;
      client.transparentProxy.enable = cfg.transparentProxy;
    };
  };
}
