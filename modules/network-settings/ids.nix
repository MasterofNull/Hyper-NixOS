{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.ids;
in
{
  options.hypervisor.network.ids = {
    enable = lib.mkEnableOption "Intrusion Detection System";
    engine = lib.mkOption { type = lib.types.enum ["suricata" "snort"]; default = "suricata"; };
  };
  
  config = lib.mkIf cfg.enable {
    services.suricata = lib.mkIf (cfg.engine == "suricata") {
      enable = true;
    };
  };
}
