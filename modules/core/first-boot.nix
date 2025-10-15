# First Boot Menu Service
# Shows welcome menu on first boot and provides access to setup wizard

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.firstBoot;
  
  # Create the first boot menu script
  firstBootMenuScript = pkgs.writeScriptBin "first-boot-menu" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash ${./../../scripts/first-boot-menu.sh} "$@"
  '';
  
  # Create the system setup wizard script
  systemSetupWizardScript = pkgs.writeScriptBin "system-setup-wizard" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash ${./../../scripts/system-setup-wizard.sh} "$@"
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
    # Install both menu and wizard scripts
    environment.systemPackages = [ 
      firstBootMenuScript 
      systemSetupWizardScript
    ];
    
    # Ensure the hypervisor directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor 0755 root root -"
      "d /etc/hypervisor/bin 0755 root root -"
      "d /etc/hypervisor/docs 0755 root root -"
    ];
    
    # Create symlinks for easy access
    environment.etc."hypervisor/bin/first-boot-menu" = {
      source = "${firstBootMenuScript}/bin/first-boot-menu";
    };
    
    environment.etc."hypervisor/bin/system-setup-wizard" = {
      source = "${systemSetupWizardScript}/bin/system-setup-wizard";
    };
    
    # Create systemd service for first boot menu
    systemd.services.hypervisor-first-boot-menu = mkIf cfg.autoStart {
      description = "Hyper-NixOS First Boot Menu";
      
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
        
        # Run the first boot menu
        ExecStart = "${firstBootMenuScript}/bin/first-boot-menu";
        
        # Create first boot flag after menu exits
        ExecStartPost = "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/.first-boot-complete";
      };
      
      # Run after basic system is up but before getty
      after = [ "sysinit.target" "basic.target" "multi-user.target" ];
      before = [ "getty@tty1.service" ];
      wantedBy = [ "multi-user.target" ];
      
      # Conflict with getty to take over tty1
      conflicts = [ "getty@tty1.service" ];
    };
    
    # Override getty@tty1 to wait for first-boot menu if needed
    systemd.services."getty@tty1" = mkIf cfg.autoStart {
      overrideStrategy = "asDropin";
      unitConfig = {
        # Don't start getty@tty1 until first boot menu has run
        ConditionPathExists = "/var/lib/hypervisor/.first-boot-complete";
      };
    };
    
    # Add reconfigure script for easy tier changes
    environment.etc."hypervisor/bin/reconfigure-tier" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Reconfigure system tier
        
        if [[ $EUID -ne 0 ]]; then
          echo "This script must be run as root"
          echo "Please run: sudo reconfigure-tier"
          exit 1
        fi
        
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║         Reconfigure Hyper-NixOS System Tier                  ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo
        echo "This will run the system setup wizard to change your tier."
        echo "Your current configuration will be backed up."
        echo
        read -p "Continue? (yes/no): " confirm
        
        if [[ $confirm =~ ^[Yy][Ee][Ss]$ ]]; then
          # Run the setup wizard
          ${systemSetupWizardScript}/bin/system-setup-wizard
        else
          echo "Cancelled."
          exit 0
        fi
      '';
    };
    
    # Add helpful aliases to the shell
    programs.bash.shellAliases = {
      first-boot-menu = "sudo first-boot-menu";
      setup-wizard = "sudo system-setup-wizard";
      reconfigure-tier = "sudo reconfigure-tier";
    };
    
    # Add to MOTD how to access the menu
    environment.etc."motd".text = mkDefault ''
      ╔═══════════════════════════════════════════════════════════════╗
      ║              Welcome to Hyper-NixOS                           ║
      ║         Next-Generation Virtualization Platform               ║
      ╚═══════════════════════════════════════════════════════════════╝
      
      ${if builtins.pathExists "/var/lib/hypervisor/.setup-complete" then ''
      ✓ System is configured and ready!
      
      Quick Commands:
        • first-boot-menu     - View welcome menu
        • reconfigure-tier    - Change system tier
        • virt-manager        - Launch VM manager GUI
        • virsh list --all    - List all VMs
      '' else ''
      ⚠ System setup is not complete!
      
      Run 'first-boot-menu' to start the setup wizard.
      Or run 'system-setup-wizard' directly to configure your tier.
      ''}
      
      Documentation: /etc/hypervisor/docs/
    '';
  };
}
