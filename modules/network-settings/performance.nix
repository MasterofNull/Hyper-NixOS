{ config, lib, pkgs, ... }:

# Network Performance Tuning
# TCP buffer sizes and connection optimization for high-throughput operations

{
  boot.kernel.sysctl = {
    # ═══════════════════════════════════════════════════════════════
    # TCP Buffer Optimization
    # ═══════════════════════════════════════════════════════════════
    
    # Increase TCP buffer sizes for better throughput
    "net.core.rmem_max" = lib.mkDefault 134217728;  # 128MB receive buffer
    "net.core.wmem_max" = lib.mkDefault 134217728;  # 128MB send buffer
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 87380 134217728";
    
    # ═══════════════════════════════════════════════════════════════
    # Connection Optimization
    # ═══════════════════════════════════════════════════════════════
    
    # Enable TCP fast open for faster connection establishment
    "net.ipv4.tcp_fastopen" = lib.mkDefault 3;
    
    # Increase max connection queue sizes
    "net.core.somaxconn" = lib.mkDefault 4096;
    "net.core.netdev_max_backlog" = lib.mkDefault 5000;
  };
}
