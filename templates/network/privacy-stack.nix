# Privacy Stack Template
# Maximum privacy and anonymity configuration

{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/network-settings/ipv6.nix
    ../../modules/network-settings/vpn.nix
    ../../modules/network-settings/tor.nix
    ../../modules/network-settings/dns-server.nix
    ../../modules/network-settings/mac-spoofing.nix
    ../../modules/network-settings/ip-spoofing.nix
  ];

  hypervisor.network = {
    # IPv6 with maximum privacy
    ipv6 = {
      enable = true;
      privacy = "temporary";  # RFC 4941 temporary addresses
      randomize.enable = true;
      randomize.intervalDays = 1;  # New address daily
      spoof.enable = true;
      spoof.mode = "fully-random";
    };
    
    # VPN with kill switch
    vpn = {
      enable = true;
      type = "wireguard";
      killSwitch = {
        enable = true;
        allowLAN = false;  # Block all non-VPN traffic
      };
    };
    
    # Tor integration
    tor = {
      enable = true;
      transparentProxy = true;
    };
    
    # DNS with ad-blocking
    dnsServer = {
      enable = true;
      adBlocking.enable = true;
      upstream = [ "1.1.1.1" ];  # Cloudflare DNS over HTTPS
    };
    
    # Random MAC addresses
    macSpoof = {
      enable = true;
      mode = "random";
      persistMACs = false;
    };
    
    # IP rotation
    ipSpoof = {
      enable = true;
      mode = "rotation";
    };
  };
}
