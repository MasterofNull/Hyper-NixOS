{ config, pkgs, lib, ... }:

{
  imports = [
    ../hardware-configuration.nix
    ../modules/core/options.nix
    ../modules/core/hypervisor-base.nix
    ../modules/core/base-system.nix
    ../modules/system-tiers.nix  # System tier definitions
    ../modules/security/ssh-enhanced.nix
    ../modules/security/docker-enhanced.nix
    ../modules/monitoring/enhanced-monitoring.nix
  ];

  # Enable hypervisor
  hypervisor.enable = true;

  # Enhanced SSH Security
  security.ssh.enhanced = {
    enable = true;
    autoMount = true;
    loginMonitoring = true;
    desktopNotifications = true;
    whitelistIPs = [ "10.0.0.0/8" "192.168.0.0/16" ];
  };

  # Enhanced Docker Security
  security.docker.enhanced = {
    enable = true;
    volumeRestrictions = [ "/" "/etc" "/root" "/home" ];
    enableCaching = true;
    securityScanning = true;
    resourceLimits = {
      memory = "4g";
      cpus = "2.0";
    };
  };

  # Enhanced Monitoring
  monitoring.enhanced = {
    enable = true;
    notifications = {
      enable = true;
      webhooks = [ ];  # Add webhook URLs here
    };
  };

  # Additional security packages
  environment.systemPackages = with pkgs; [
    # Security tools
    trivy
    lynis
    chkrootkit
    aide
    
    # Monitoring tools
    prometheus
    grafana
    alertmanager
    
    # Automation tools
    parallel
    jq
    yq
    
    # Custom scripts
    (writeScriptBin "security-scan" (builtins.readFile ./scripts/security/automated-security-scan.sh))
    (writeScriptBin "parallel-update" (builtins.readFile ./scripts/automation/parallel-git-update.sh))
    (writeScriptBin "deploy-stack" (builtins.readFile ./scripts/tools/deploy-security-stack.sh))
  ];

  # Systemd services
  systemd.services = {
    ssh-monitor = {
      description = "SSH Login Monitor";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash ${./scripts/security/ssh-monitor.sh}";
        Restart = "always";
      };
    };
    
    security-scan = {
      description = "Automated Security Scanner";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${./scripts/security/automated-security-scan.sh}";
      };
    };
  };

  # Timers
  systemd.timers = {
    security-scan = {
      description = "Daily Security Scan";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };

  # Shell initialization
  programs.bash.interactiveShellInit = ''
    # Load security functions
    [[ -f ${./scripts/security/security-aliases.sh} ]] && source ${./scripts/security/security-aliases.sh}
    [[ -f ${./scripts/automation/advanced-security-functions.sh} ]] && source ${./scripts/automation/advanced-security-functions.sh}
    
    # Parallel execution framework
    [[ -f ${./scripts/automation/parallel-framework.sh} ]] && source ${./scripts/automation/parallel-framework.sh}
  '';

  programs.zsh.interactiveShellInit = config.programs.bash.interactiveShellInit;
}
