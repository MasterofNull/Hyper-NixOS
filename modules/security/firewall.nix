{ config, lib, pkgs, ... }:

# Firewall Configuration
# Consolidated firewall settings for the hypervisor
# Supports both iptables and nftables

{
  options.hypervisor.security = {
    strictFirewall = lib.mkEnableOption "Enable default-deny nftables for hypervisor";
    migrationTcp = lib.mkEnableOption "Allow libvirt TCP migration ports (16514, 49152-49216)";
  };

  config = lib.mkMerge [
    # ═══════════════════════════════════════════════════════════════
    # Standard Firewall (iptables-based)
    # Default configuration for most deployments
    # ═══════════════════════════════════════════════════════════════
    (lib.mkIf (!config.hypervisor.security.strictFirewall) {
      networking.firewall = {
        enable = true;
        
        # Only allow SSH by default
        allowedTCPPorts = [ 22 ];
        
        # Log dropped packets for monitoring
        logRefusedConnections = true;
        logRefusedPackets = true;
      };
    })
    
    # ═══════════════════════════════════════════════════════════════
    # Strict Firewall (nftables-based)
    # Default-deny with explicit allowlist
    # Enable with: hypervisor.security.strictFirewall = true;
    # ═══════════════════════════════════════════════════════════════
    (lib.mkIf config.hypervisor.security.strictFirewall {
      networking.nftables.enable = true;
      networking.firewall.enable = false;
      
      networking.nftables.ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;
            
            # Allow established connections
            ct state established,related accept
            
            # Allow loopback
            iifname "lo" accept
            
            # Allow SSH
            tcp dport { 22 } accept
            
            # libvirt bridge services (DNS/DHCP)
            iifname "virbr0" udp dport { 53, 67 } accept
            iifname "virbr0" tcp dport { 53 } accept
            
            # Optional: libvirt TCP migration and TLS
      '' + (lib.optionalString config.hypervisor.security.migrationTcp ''
            tcp dport { 16514 } accept
            tcp dport 49152-49216 accept
      '') + ''
          }
          
          chain forward {
            type filter hook forward priority 0; policy drop;
            
            # Allow VM traffic through bridges
            iifname "virbr*" accept
            oifname "virbr*" accept
          }
          
          chain output {
            type filter hook output priority 0; policy accept;
          }
        }
      '';
    })
  ];
}
