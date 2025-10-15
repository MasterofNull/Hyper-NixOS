{ config, lib, pkgs, ... }:

# VPN Server Module
# Provides WireGuard and OpenVPN server configurations

let
  cfg = config.hypervisor.networking.vpnServer;
in
{
  options.hypervisor.networking.vpnServer = {
    enable = lib.mkEnableOption "VPN server support";
    
    wireguard = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable WireGuard VPN server";
      };
      
      interface = lib.mkOption {
        type = lib.types.str;
        default = "wg0";
        description = "WireGuard interface name";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 51820;
        description = "WireGuard listening port";
      };
      
      subnet = lib.mkOption {
        type = lib.types.str;
        default = "10.100.0.0/24";
        description = "VPN subnet for WireGuard clients";
      };
      
      serverIP = lib.mkOption {
        type = lib.types.str;
        default = "10.100.0.1/24";
        description = "Server IP address in VPN subnet";
      };
      
      peers = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Client name";
            };
            publicKey = lib.mkOption {
              type = lib.types.str;
              description = "Client public key";
            };
            allowedIPs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Allowed IP addresses for this peer";
            };
          };
        });
        default = [];
        description = "WireGuard peer configurations";
      };
    };
    
    openvpn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OpenVPN server";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 1194;
        description = "OpenVPN listening port";
      };
      
      protocol = lib.mkOption {
        type = lib.types.enum [ "tcp" "udp" ];
        default = "udp";
        description = "OpenVPN protocol";
      };
      
      subnet = lib.mkOption {
        type = lib.types.str;
        default = "10.200.0.0/24";
        description = "VPN subnet for OpenVPN clients";
      };
    };
    
    dnsServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "1.1.1.1";
      description = "DNS server to push to VPN clients";
    };
    
    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "0.0.0.0/0" ];
      description = "Networks accessible through VPN";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # WireGuard configuration
    networking.wireguard.interfaces = lib.mkIf cfg.wireguard.enable {
      ${cfg.wireguard.interface} = {
        ips = [ cfg.wireguard.serverIP ];
        listenPort = cfg.wireguard.port;
        
        # Generate private key on first run
        privateKeyFile = "/var/lib/wireguard/${cfg.wireguard.interface}.key";
        
        # Peer configurations
        peers = map (peer: {
          publicKey = peer.publicKey;
          allowedIPs = if peer.allowedIPs == [] 
            then [ "${peer.name}/32" ]  # Default to single IP if not specified
            else peer.allowedIPs;
        }) cfg.wireguard.peers;
        
        # Post-up and post-down rules for NAT
        postSetup = ''
          ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.wireguard.subnet} -o eth0 -j MASQUERADE
          ${pkgs.iptables}/bin/iptables -A FORWARD -i ${cfg.wireguard.interface} -j ACCEPT
          ${pkgs.iptables}/bin/iptables -A FORWARD -o ${cfg.wireguard.interface} -j ACCEPT
        '';
        
        postShutdown = ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.wireguard.subnet} -o eth0 -j MASQUERADE
          ${pkgs.iptables}/bin/iptables -D FORWARD -i ${cfg.wireguard.interface} -j ACCEPT
          ${pkgs.iptables}/bin/iptables -D FORWARD -o ${cfg.wireguard.interface} -j ACCEPT
        '';
      };
    };
    
    # OpenVPN configuration
    services.openvpn.servers = lib.mkIf cfg.openvpn.enable {
      hypervisor = {
        config = ''
          port ${toString cfg.openvpn.port}
          proto ${cfg.openvpn.protocol}
          dev tun
          
          # Certificates and keys
          ca /var/lib/openvpn/ca.crt
          cert /var/lib/openvpn/server.crt
          key /var/lib/openvpn/server.key
          dh /var/lib/openvpn/dh2048.pem
          tls-auth /var/lib/openvpn/ta.key 0
          
          # Network configuration
          server ${lib.head (lib.splitString "/" cfg.openvpn.subnet)} ${lib.elemAt (lib.splitString "/" cfg.openvpn.subnet) 1}
          ifconfig-pool-persist /var/lib/openvpn/ipp.txt
          
          # Push routes to clients
          ${lib.concatMapStrings (net: ''
            push "route ${net}"
          '') cfg.allowedNetworks}
          
          ${lib.optionalString (cfg.dnsServer != null) ''
            push "dhcp-option DNS ${cfg.dnsServer}"
          ''}
          
          # Security
          cipher AES-256-CBC
          auth SHA256
          user nobody
          group nogroup
          persist-key
          persist-tun
          
          # Logging
          status /var/log/openvpn/status.log
          log-append /var/log/openvpn/openvpn.log
          verb 3
        '';
      };
    };
    
    # Enable IP forwarding for VPN
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    
    # Firewall rules
    networking.firewall = {
      allowedUDPPorts = lib.optional cfg.wireguard.enable cfg.wireguard.port
        ++ lib.optional (cfg.openvpn.enable && cfg.openvpn.protocol == "udp") cfg.openvpn.port;
      
      allowedTCPPorts = lib.optional (cfg.openvpn.enable && cfg.openvpn.protocol == "tcp") cfg.openvpn.port;
      
      trustedInterfaces = lib.optional cfg.wireguard.enable cfg.wireguard.interface
        ++ lib.optional cfg.openvpn.enable "tun+";
    };
    
    # VPN management tools
    environment.systemPackages = [
      pkgs.wireguard-tools
      pkgs.qrencode  # For generating QR codes for mobile clients
    ] ++ lib.optionals cfg.openvpn.enable [
      pkgs.openvpn
      pkgs.easy-rsa  # For managing OpenVPN certificates
    ];
    
    # Directory setup
    systemd.tmpfiles.rules = [
      "d /var/lib/wireguard 0700 root root - -"
      "d /var/lib/openvpn 0700 root root - -"
      "d /var/log/openvpn 0755 root root - -"
      "d /etc/hypervisor/vpn 0755 root root - -"
    ];
    
    # Generate WireGuard keys if they don't exist
    system.activationScripts.wireguard-keys = lib.mkIf cfg.wireguard.enable ''
      if [ ! -f /var/lib/wireguard/${cfg.wireguard.interface}.key ]; then
        mkdir -p /var/lib/wireguard
        ${pkgs.wireguard-tools}/bin/wg genkey > /var/lib/wireguard/${cfg.wireguard.interface}.key
        chmod 600 /var/lib/wireguard/${cfg.wireguard.interface}.key
        
        # Generate public key
        ${pkgs.wireguard-tools}/bin/wg pubkey < /var/lib/wireguard/${cfg.wireguard.interface}.key > /var/lib/wireguard/${cfg.wireguard.interface}.pub
        chmod 644 /var/lib/wireguard/${cfg.wireguard.interface}.pub
        
        echo "WireGuard keys generated. Public key:"
        cat /var/lib/wireguard/${cfg.wireguard.interface}.pub
      fi
    '';
    
    # Feature status file
    environment.etc."hypervisor/features/vpn-server.conf".text = ''
      # VPN Server Configuration
      FEATURE_NAME="vpn-server"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
      
      WIREGUARD_ENABLED="${if cfg.wireguard.enable then "yes" else "no"}"
      OPENVPN_ENABLED="${if cfg.openvpn.enable then "yes" else "no"}"
      
      ${lib.optionalString cfg.wireguard.enable ''
        WIREGUARD_PORT="${toString cfg.wireguard.port}"
        WIREGUARD_SUBNET="${cfg.wireguard.subnet}"
        WIREGUARD_INTERFACE="${cfg.wireguard.interface}"
      ''}
      
      ${lib.optionalString cfg.openvpn.enable ''
        OPENVPN_PORT="${toString cfg.openvpn.port}"
        OPENVPN_PROTOCOL="${cfg.openvpn.protocol}"
        OPENVPN_SUBNET="${cfg.openvpn.subnet}"
      ''}
    '';
    
    # VPN management scripts
    environment.systemPackages = [
      (pkgs.writeScriptBin "vpn-add-client" ''
        #!${pkgs.bash}/bin/bash
        set -e
        
        if [ $# -ne 1 ]; then
          echo "Usage: vpn-add-client <client-name>"
          exit 1
        fi
        
        CLIENT_NAME="$1"
        CONFIG_DIR="/etc/hypervisor/vpn/clients"
        mkdir -p "$CONFIG_DIR"
        
        ${lib.optionalString cfg.wireguard.enable ''
          # Generate WireGuard config
          PRIVATE_KEY=$(${pkgs.wireguard-tools}/bin/wg genkey)
          PUBLIC_KEY=$(echo "$PRIVATE_KEY" | ${pkgs.wireguard-tools}/bin/wg pubkey)
          SERVER_PUBLIC_KEY=$(cat /var/lib/wireguard/${cfg.wireguard.interface}.pub)
          
          # Get next available IP
          LAST_IP=$(wg show ${cfg.wireguard.interface} allowed-ips | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -1 | cut -d. -f4)
          NEXT_IP=$((LAST_IP + 1))
          CLIENT_IP="10.100.0.$NEXT_IP/24"
          
          # Create client config
          cat > "$CONFIG_DIR/$CLIENT_NAME-wg.conf" <<EOF
          [Interface]
          PrivateKey = $PRIVATE_KEY
          Address = $CLIENT_IP
          DNS = ${cfg.dnsServer or "1.1.1.1"}
          
          [Peer]
          PublicKey = $SERVER_PUBLIC_KEY
          Endpoint = YOUR_SERVER_IP:${toString cfg.wireguard.port}
          AllowedIPs = 0.0.0.0/0
          PersistentKeepalive = 25
          EOF
          
          echo "WireGuard client configuration created: $CONFIG_DIR/$CLIENT_NAME-wg.conf"
          echo "Client public key (add to server): $PUBLIC_KEY"
          echo ""
          echo "QR Code for mobile devices:"
          ${pkgs.qrencode}/bin/qrencode -t ansiutf8 < "$CONFIG_DIR/$CLIENT_NAME-wg.conf"
        ''}
      '')
      
      (pkgs.writeScriptBin "vpn-status" ''
        #!${pkgs.bash}/bin/bash
        echo "VPN Server Status"
        echo "================="
        
        ${lib.optionalString cfg.wireguard.enable ''
          echo ""
          echo "WireGuard (${cfg.wireguard.interface}):"
          echo "  Port: ${toString cfg.wireguard.port}"
          echo "  Subnet: ${cfg.wireguard.subnet}"
          echo ""
          ${pkgs.wireguard-tools}/bin/wg show ${cfg.wireguard.interface}
        ''}
        
        ${lib.optionalString cfg.openvpn.enable ''
          echo ""
          echo "OpenVPN:"
          echo "  Port: ${toString cfg.openvpn.port} (${cfg.openvpn.protocol})"
          echo "  Subnet: ${cfg.openvpn.subnet}"
          echo ""
          if systemctl is-active --quiet openvpn-hypervisor; then
            echo "  Status: ✓ Running"
            cat /var/log/openvpn/status.log 2>/dev/null | head -20 || true
          else
            echo "  Status: ✗ Not running"
          fi
        ''}
      '')
    ];
  };
}
