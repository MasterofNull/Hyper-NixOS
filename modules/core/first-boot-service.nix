# First Boot Service Module for Hyper-NixOS
# Automatically launches setup wizard on first boot

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf types;
  cfg = config.hypervisor.firstBoot;

in {
  options.hypervisor.firstBoot = {
    enable = mkEnableOption "automatic first-boot wizard";

    autoLaunch = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically launch first-boot wizard on first login";
    };

    wizardScript = mkOption {
      type = types.path;
      default = /etc/nixos/scripts/first-boot-wizard.sh;
      description = "Path to the first-boot wizard script";
    };
  };

  config = mkIf cfg.enable {
    # Systemd service to run once on first boot
    systemd.services.hypervisor-first-boot = {
      description = "Hyper-NixOS First Boot Wizard";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${cfg.wizardScript} --auto";
        RemainAfterExit = true;
        StandardOutput = "journal";
        StandardError = "journal";

        # Only run once - check for completion marker
        ExecCondition = "${pkgs.coreutils}/bin/test ! -f /var/lib/hypervisor/.first-boot-complete";

        # Mark as complete after successful run
        ExecStartPost = "${pkgs.coreutils}/bin/touch /var/lib/hypervisor/.first-boot-complete";
      };

      # Don't block boot if wizard fails
      unitConfig = {
        ConditionPathExists = "!/var/lib/hypervisor/.first-boot-complete";
      };
    };

    # Ensure directory exists
    system.activationScripts.firstBootPrep = ''
      mkdir -p /var/lib/hypervisor
      chmod 755 /var/lib/hypervisor
    '';

    # Add helpful message to MOTD if first boot not complete
    environment.etc."motd.first-boot" = mkIf cfg.autoLaunch {
      text = ''
        ╔═══════════════════════════════════════════════════════════════╗
        ║              Welcome to Hyper-NixOS!                          ║
        ╠═══════════════════════════════════════════════════════════════╣
        ║                                                               ║
        ║  First-time setup detected. Run the setup wizard:            ║
        ║                                                               ║
        ║     $ hv setup                                                ║
        ║                                                               ║
        ║  Or check status:                                             ║
        ║     $ systemctl status hypervisor-first-boot                  ║
        ║                                                               ║
        ║  For help:                                                    ║
        ║     $ hv help                                                 ║
        ║                                                               ║
        ╚═══════════════════════════════════════════════════════════════╝
      '';
    };
  };
}
