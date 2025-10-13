{ config, lib, pkgs, ... }:

# VM Scheduling and Automation
# Automated VM operations, scheduled tasks, and resource reporting

{
  # VM management tools
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    libguestfs
    jq
    bc
  ];
  
  # ═══════════════════════════════════════════════════════════════
  # VM Scheduler Service
  # Executes scheduled VM operations (start, stop, snapshot, etc.)
  # ═══════════════════════════════════════════════════════════════
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
  
  # ═══════════════════════════════════════════════════════════════
  # Daily Resource Reporting
  # Generates daily reports on VM resource usage
  # ═══════════════════════════════════════════════════════════════
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
  
  # Note: Directory structure for reports is managed in core/directories.nix
}
