{ config, lib, pkgs, ... }:
{
  options.hypervisor.security = {
    strictFirewall = lib.mkEnableOption "Enable default-deny nftables for hypervisor";
    perVmSlices = lib.mkEnableOption "Run each VM in systemd slice with limits";
    migrationTcp = lib.mkEnableOption "Allow libvirt TCP migration ports (16514, 49152-49216)";
  };

  config = lib.mkMerge [
    (lib.mkIf config.hypervisor.security.strictFirewall {
      networking.nftables.enable = true;
      networking.firewall.enable = false;
      networking.nftables.ruleset = ''
        table inet filter {
          chains {
            input { type filter hook input priority 0; policy drop; }
            forward { type filter hook forward priority 0; policy drop; }
            output { type filter hook output priority 0; policy accept; }
            allow_in {
              ct state established,related accept
              iifname "lo" accept
              tcp dport { 22 } accept
              # libvirt bridge services (DNS/DHCP)
              iifname "virbr0" udp dport { 53, 67 } accept
              iifname "virbr0" tcp dport { 53 } accept
              # Optional: libvirt TCP migration and TLS if enabled
'' + (lib.optionalString config.hypervisor.security.migrationTcp ''
              tcp dport { 16514 } accept
              tcp dport 49152-49216 accept
'') + ''
            }
            input add rule inet filter input jump allow_in
          }
        }
      '';
    })
  ];
}
