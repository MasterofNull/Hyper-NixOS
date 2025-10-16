# Performance Stack Template
# High-throughput server configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/network-settings/bonding.nix
    ../../modules/network-settings/traffic-shaping.nix
    ../../modules/network-settings/performance-tuning.nix
    ../../modules/network-settings/monitoring.nix
  ];

  hypervisor.network = {
    # Network bonding for bandwidth aggregation
    bonding = {
      enable = true;
      bonds."bond0" = {
        interfaces = [ "eth0" "eth1" ];
        mode = "802.3ad";  # LACP
        transmitHashPolicy = "layer3+4";
        lacpRate = "fast";
      };
    };
    
    # Traffic shaping for QoS
    qos = {
      enable = true;
      defaultUpload = "10gbit";
      defaultDownload = "10gbit";
      algorithm = "fq_codel";  # Low latency
    };
    
    # Performance optimizations
    performanceTuning = {
      enable = true;
      tcpCongestion = "bbr";  # Google BBR
      jumboFrames = true;  # 9000 MTU
    };
    
    # Network monitoring
    monitoring = {
      enable = true;
      prometheus = true;
    };
  };
}
