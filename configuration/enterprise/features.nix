{ config, lib, pkgs, ... }:

# Enterprise Features Configuration
# Aggregates all enterprise features for easy enable/disable

{
  imports = [
    ../monitoring/logging.nix
    ./quotas.nix
    ./network-isolation.nix
    ./storage-quotas.nix
    ./snapshots.nix
    ./encryption.nix
  ];
  
  # Install enterprise management tools
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    libguestfs
    jq
    bc
  ];
  
  # Systemd timer for VM scheduler
  systemd.services.vm-scheduler-run = {
    description = "Execute Scheduled VM Operations";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/hypervisor/scripts/vm_scheduler.sh run";
    };
  };
  
  systemd.timers.vm-scheduler-run = {
    description = "VM Scheduler (every minute)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "minutely";
      Persistent = true;
    };
  };
  
  # Daily resource reporting
  systemd.services.daily-resource-report = {
    description = "Generate Daily Resource Report";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeScript "daily-report" ''
        #!/usr/bin/env bash
        /etc/hypervisor/scripts/resource_reporter.sh daily > /var/lib/hypervisor/reports/daily-$(date +%Y-%m-%d).txt
      ''}";
    };
  };
  
  systemd.timers.daily-resource-report = {
    description = "Daily Resource Report";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
  
  # Create directory structure
  systemd.tmpfiles.rules = [
    "d /var/lib/hypervisor/templates 0755 root root -"
    "d /var/lib/hypervisor/reports 0755 root root -"
    "d /var/lib/hypervisor/keys 0700 root root -"
  ];
}
