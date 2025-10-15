# Headless VM Menu Module
# Provides boot-time VM menu with auto-select functionality

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault types;
  cfg = config.hypervisor.headlessMenu;
  
  # Create the headless VM menu script
  headlessVmMenuScript = pkgs.writeScriptBin "headless-vm-menu" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash ${./../../scripts/headless-vm-menu.sh} "$@"
  '';
in
{
  options.hypervisor.headlessMenu = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable headless VM menu at boot";
    };
    
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start headless menu on boot";
    };
    
    autoSelectTimeout = mkOption {
      type = types.int;
      default = 10;
      description = "Seconds to wait before auto-selecting last VM";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install the headless VM menu script
    environment.systemPackages = [ headlessVmMenuScript ];
    
    # Create systemd service for headless menu
    systemd.services.hypervisor-headless-menu = mkIf cfg.autoStart {
      description = "Hyper-NixOS Headless VM Menu";
      
      # Only run after setup is complete
      unitConfig = {
        ConditionPathExists = "/var/lib/hypervisor/.setup-complete";
      };
      
      serviceConfig = {
        Type = "idle";  # Wait for system to be ready
        RemainAfterExit = true;
        StandardInput = "tty-force";
        StandardOutput = "inherit";
        StandardError = "inherit";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
        Restart = "on-failure";
        RestartSec = 5;
        
        # Run the menu
        ExecStart = "${headlessVmMenuScript}/bin/headless-vm-menu";
      };
      
      # Run after libvirtd is ready
      after = [ "libvirtd.service" "multi-user.target" ];
      requires = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      
      # Take over tty1 from getty
      conflicts = [ "getty@tty1.service" ];
    };
    
    # Override getty@tty1 to not start if headless menu is active
    systemd.services."getty@tty1" = mkIf cfg.autoStart {
      overrideStrategy = "asDropin";
      unitConfig = {
        # Only start if headless menu service is not active
        ConditionPathExists = "!/var/lib/hypervisor/.setup-complete";
      };
      # Also make it conflict
      conflicts = [ "hypervisor-headless-menu.service" ];
    };
    
    # Add shell alias for easy access
    programs.bash.shellAliases = {
      vm-menu = "sudo headless-vm-menu";
    };
    
    # Create symlink in /etc/hypervisor/bin
    environment.etc."hypervisor/bin/vm-menu" = {
      source = "${headlessVmMenuScript}/bin/headless-vm-menu";
    };
  };
}
