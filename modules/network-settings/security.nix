{ config, lib, pkgs, ... }:

# Network Security Hardening
# Network-related sysctl settings for preventing attacks and securing network stack

{
  boot.kernel.sysctl = {
    # ═══════════════════════════════════════════════════════════════
    # IP Security
    # ═══════════════════════════════════════════════════════════════
    
    # IP Forwarding (enabled for VM networking)
    # "net.ipv4.ip_forward" = 1;  # Managed by libvirt
    
    # Reverse path filtering (prevent IP spoofing)
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    
    # Disable source routing (prevent routing manipulation)
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    
    # ═══════════════════════════════════════════════════════════════
    # ICMP Security
    # ═══════════════════════════════════════════════════════════════
    
    # Disable ICMP redirects (prevent MITM attacks)
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    
    # Ignore broadcast pings (prevent smurf attacks)
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    
    # ═══════════════════════════════════════════════════════════════
    # TCP Security
    # ═══════════════════════════════════════════════════════════════
    
    # Enable SYN cookies (prevent SYN flood attacks)
    "net.ipv4.tcp_syncookies" = 1;
  };
}
