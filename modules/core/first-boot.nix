# First Boot Setup Service
# Launches comprehensive setup wizard on first boot

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.firstBoot;
  
  # Create the comprehensive setup wizard script
  comprehensiveSetupWizardScript = pkgs.writeScriptBin "comprehensive-setup-wizard" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash ${./../../scripts/comprehensive-setup-wizard.sh} "$@"
  '';
in
{
  options.hypervisor.firstBoot = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable first boot menu system";
    };
    
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically show first boot menu on first boot";
    };
  };
  
  config = mkIf cfg.enable {
    # Install comprehensive setup wizard
    environment.systemPackages = [ 
      comprehensiveSetupWizardScript
    ];
    
    # Ensure the hypervisor directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor 0755 root root -"
      "d /etc/hypervisor/bin 0755 root root -"
      "d /etc/hypervisor/docs 0755 root root -"
    ];
    
    # Create symlinks for easy access
    environment.etc."hypervisor/bin/setup-wizard" = {
      source = "${comprehensiveSetupWizardScript}/bin/comprehensive-setup-wizard";
    };
    
    # Create systemd service for comprehensive setup wizard
    systemd.services.hypervisor-setup-wizard = mkIf cfg.autoStart {
      description = "Hyper-NixOS Comprehensive Setup Wizard";
      
      # Only run on first boot (when setup is not complete and users were migrated)
      unitConfig = {
        ConditionPathExists = [
          "!/var/lib/hypervisor/.setup-complete"
          "/etc/nixos/modules/users-local.nix"  # Only if users were migrated
        ];
      };
      
      serviceConfig = {
        Type = "idle";  # Wait for other services to finish
        RemainAfterExit = true;
        StandardInput = "tty-force";
        StandardOutput = "inherit";
        StandardError = "inherit";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
        
        # Ensure directory exists before running
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/hypervisor";
        
        # Run the comprehensive setup wizard
        ExecStart = "${comprehensiveSetupWizardScript}/bin/comprehensive-setup-wizard";
        
        # Setup complete flag is created by the wizard itself
      };
      
      # Run after basic system is up but before getty
      after = [ "sysinit.target" "basic.target" "multi-user.target" "libvirtd.service" ];
      before = [ "getty@tty1.service" ];
      wants = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      
      # Conflict with getty to take over tty1
      conflicts = [ "getty@tty1.service" ];
    };
    
    # Override getty@tty1 to wait for setup wizard if needed
    systemd.services."getty@tty1" = mkIf cfg.autoStart {
      overrideStrategy = "asDropin";
      unitConfig = {
        # Don't start getty@tty1 until setup is complete
        ConditionPathExists = "/var/lib/hypervisor/.setup-complete";
      };
    };
    
    # Add reconfigure script for easy system reconfiguration
    environment.etc."hypervisor/bin/reconfigure-system" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Reconfigure Hyper-NixOS system
        
        if [[ $EUID -ne 0 ]]; then
          echo "This script must be run as root"
          echo "Please run: sudo reconfigure-system"
          exit 1
        fi
        
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║         Reconfigure Hyper-NixOS System                       ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo
        echo "This will run the comprehensive setup wizard."
        echo "Your current configuration will be backed up."
        echo
        read -p "Continue? (yes/no): " confirm
        
        if [[ $confirm =~ ^[Yy][Ee][Ss]$ ]]; then
          # Remove setup complete flag to allow reconfiguration
          rm -f /var/lib/hypervisor/.setup-complete
          # Run the wizard
          ${comprehensiveSetupWizardScript}/bin/comprehensive-setup-wizard
        else
          echo "Cancelled."
          exit 0
        fi
      '';
    };
    
    # Add helpful aliases to the shell
    programs.bash.shellAliases = {
      setup-wizard = "sudo comprehensive-setup-wizard";
      reconfigure-system = "sudo reconfigure-system";
    };
    
    # Add to MOTD how to access the system
    environment.etc."motd".text = mkDefault ''
      ╔═══════════════════════════════════════════════════════════════╗
      ║              Welcome to Hyper-NixOS                           ║
      ║         Next-Generation Virtualization Platform               ║
      ╚═══════════════════════════════════════════════════════════════╝
      
      ${if builtins.pathExists "/var/lib/hypervisor/.setup-complete" then ''
      ✓ System is configured and ready!
      
      Quick Commands:
        • vm-menu             - Headless VM management menu
        • reconfigure-system  - Run setup wizard again
        • virt-manager        - Launch VM manager GUI (if installed)
        • virsh list --all    - List all VMs
      '' else ''
      ⚠ System setup is not complete!
      
      Run 'comprehensive-setup-wizard' to configure your system.
      The setup wizard will launch automatically on next boot.
      ''}
      
      Documentation: /etc/hypervisor/docs/
    '';
  };
}
