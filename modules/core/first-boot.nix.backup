# First Boot Configuration Service
# Runs the configuration wizard on first boot

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.firstBoot;
  
  firstBootScript = pkgs.writeScriptBin "first-boot-wizard" ''
    #!${pkgs.bash}/bin/bash
    ${builtins.readFile ../../scripts/first-boot-wizard.sh}
  '';
in
{
  options.hypervisor.firstBoot = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable first boot configuration wizard";
    };
    
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start wizard on first boot";
    };
  };
  
  config = mkIf cfg.enable {
    # Install the wizard script
    environment.systemPackages = [ firstBootScript ];
    
    # Create systemd service for first boot
    systemd.services.hypervisor-first-boot = mkIf cfg.autoStart {
      description = "Hyper-NixOS First Boot Configuration Wizard";
      
      # Only run on first boot
      unitConfig = {
        ConditionPathExists = "!/var/lib/hypervisor/.first-boot-complete";
      };
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        
        # Run the wizard
        ExecStart = "${firstBootScript}/bin/first-boot-wizard";
        
        # Create completion flag
        ExecStartPost = "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/.first-boot-complete";
      };
      
      # Run after basic system is up but before login
      after = [ "multi-user.target" ];
      before = [ "getty.target" ];
      wantedBy = [ "multi-user.target" ];
    };
    
    # Also provide a manual way to run the wizard
    environment.etc."hypervisor/bin/reconfigure-tier" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Remove first boot flag and run wizard
        
        if [[ $EUID -ne 0 ]]; then
          echo "This script must be run as root"
          exit 1
        fi
        
        echo "This will reconfigure your system tier."
        read -p "Continue? (y/N): " confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
          rm -f /var/lib/hypervisor/.first-boot-complete
          ${firstBootScript}/bin/first-boot-wizard
        else
          echo "Cancelled."
        fi
      '';
    };
  };
}