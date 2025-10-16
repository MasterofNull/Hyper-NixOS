{ config, lib, pkgs, ... }:
let
  cfg = config.hypervisor.network.packetCapture;
in
{
  options.hypervisor.network.packetCapture = {
    enable = lib.mkEnableOption "Automated packet capture";
    interfaces = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
    filter = lib.mkOption { type = lib.types.str; default = ""; };
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ tcpdump wireshark-cli ];
    system.activationScripts.pcap = ''echo "Packet capture on: ${toString cfg.interfaces}" >&2'';
  };
}
