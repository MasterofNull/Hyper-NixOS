{ config, pkgs, lib, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.security.ssh.enhanced;
  
  # SSH mount helper script
  sshmScript = pkgs.writeScriptBin "sshm" ''
    #!${pkgs.bash}/bin/bash
    # SSH with automatic filesystem mount
    
    TARGET_HOST=$(echo "$@" | ${pkgs.gnugrep}/bin/grep -oE '[^@]+$' | ${pkgs.coreutils}/bin/cut -d' ' -f1)
    if [[ "$@" == *"@"* ]]; then
        TARGET_USER=$(echo "$@" | ${pkgs.gnugrep}/bin/grep -oE '^[^@]+')
    else
        TARGET_USER="$USER"
    fi
    
    # Create mount directory with timestamp
    TARGET_DIR="$HOME/mnt/''${TARGET_HOST}_$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S)"
    ${pkgs.coreutils}/bin/mkdir -p "$TARGET_DIR"
    
    echo -e "\033[1;33mMounting ''${TARGET_USER}@''${TARGET_HOST} to ''${TARGET_DIR}\033[0m"
    
    # Mount and connect
    if ${pkgs.sshfs}/bin/sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
        "''${TARGET_USER}@''${TARGET_HOST}:/" "$TARGET_DIR" 2>/dev/null; then
        
        echo -e "\033[0;32mFilesystem mounted. Connecting...\033[0m"
        ${pkgs.openssh}/bin/ssh "$@"
        
        # Cleanup on exit
        echo -e "\033[1;33mUnmounting filesystem...\033[0m"
        ${pkgs.fuse}/bin/fusermount -u "$TARGET_DIR" 2>/dev/null
        ${pkgs.coreutils}/bin/rmdir "$TARGET_DIR" 2>/dev/null
    else
        echo -e "\033[0;31mFailed to mount filesystem. Connecting without mount...\033[0m"
        ${pkgs.openssh}/bin/ssh "$@"
    fi
  '';
  
  # SSH monitoring script
  sshMonitorScript = pkgs.writeScript "ssh-monitor" ''
    #!${pkgs.bash}/bin/bash
    
    if [[ -n "$SSH_CONNECTION" ]]; then
        TIMESTAMP=$(${pkgs.coreutils}/bin/date +"%Y-%m-%d %H:%M:%S")
        CLIENT_IP=$(echo $SSH_CONNECTION | ${pkgs.gawk}/bin/awk '{print $1}')
        
        # Log connection
        echo "[$TIMESTAMP] SSH Login - User: $USER, From: $CLIENT_IP" >> /var/log/ssh-monitor.log
        
        # Send notification
        ${optionalString cfg.desktopNotifications ''
        if [[ -n "$DISPLAY" ]]; then
            ${pkgs.libnotify}/bin/notify-send \
                "SSH Login Alert" \
                "Connection from $CLIENT_IP" \
                -u critical \
                -i security-high
        fi
        ''}
        
        # Send to systemd journal
        echo "SSH Login: $USER from $CLIENT_IP" | ${pkgs.systemd}/bin/systemd-cat -t ssh-login -p warning
        
        # Webhook notification if configured
        ${optionalString (cfg.webhookUrl != null) ''
        ${pkgs.curl}/bin/curl -X POST \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"SSH Login: $USER from $CLIENT_IP\", \"timestamp\":\"$TIMESTAMP\"}" \
            "${cfg.webhookUrl}" 2>/dev/null || true
        ''}
    fi
  '';
in
{
  options.security.ssh.enhanced = {
    enable = mkEnableOption "enhanced SSH security features";
    
    autoMount = mkOption {
      type = types.bool;
      default = true;
      description = "Enable SSHFS auto-mounting for SSH connections";
    };
    
    loginMonitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Enable SSH login monitoring and alerts";
    };
    
    desktopNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Send desktop notifications for SSH logins";
    };
    
    webhookUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Webhook URL for SSH login notifications";
      example = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL";
    };
    
    whitelistIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "IP addresses that won't trigger alerts";
      example = [ "192.168.1.100" "10.0.0.50" ];
    };
  };
  
  config = mkIf cfg.enable {
    # Install required packages
    environment.systemPackages =  [
    pkgs.sshfs
    pkgs.fuse
    pkgs.libnotify
    ] ++ optional cfg.autoMount sshmScript;
    
    # SSH login monitoring
    programs.bash.interactiveShellInit = mkIf cfg.loginMonitoring ''
      # SSH Login Monitoring
      source ${sshMonitorScript}
    '';
    
    programs.zsh.interactiveShellInit = mkIf cfg.loginMonitoring ''
      # SSH Login Monitoring
      source ${sshMonitorScript}
    '';
    
    # Create log file with proper permissions
    systemd.tmpfiles.rules = mkIf cfg.loginMonitoring [
      "f /var/log/ssh-monitor.log 0640 root wheel -"
    ];
    
    # Log rotation
    services.logrotate.settings = mkIf cfg.loginMonitoring {
      "/var/log/ssh-monitor.log" = {
        frequency = "weekly";
        rotate = 4;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
      };
    };
    
    # Create whitelist file if IPs are specified
    environment.etc."ssh/whitelist.ips" = mkIf (cfg.whitelistIPs != []) {
      text = concatStringsSep "\n" cfg.whitelistIPs;
      mode = "0644";
    };
  };
}