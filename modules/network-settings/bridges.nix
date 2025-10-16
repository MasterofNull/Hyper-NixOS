{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.bridges;
in
{
  options.hypervisor.network.bridges = {
    enable = lib.mkEnableOption "Bridge management";
    bridges = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interfaces = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
          stp = lib.mkOption { type = lib.types.bool; default = true; };
        };
      });
      default = {};
    };
  };
  
  config = lib.mkIf cfg.enable {
    networking.bridges = lib.mapAttrs (name: bcfg: { interfaces = bcfg.interfaces; }) cfg.bridges;
    system.activationScripts.bridges = ''echo "Bridges: ${toString (builtins.attrNames cfg.bridges)}" >&2'';
  };
}
