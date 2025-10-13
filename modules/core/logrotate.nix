{ config, lib, pkgs, ... }:

# Log Rotation Configuration
# Consolidated logrotate settings for hypervisor logs

{
  services.logrotate = {
    enable = true;
    settings = {
      # Hypervisor application logs
      "/var/lib/hypervisor/logs/*.log" = {
        frequency = "daily";
        rotate = 7;
        compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip";
        compressext = ".gz";
        missingok = true;
        notifempty = true;
        sharedscripts = true;
        postrotate = "systemctl reload hypervisor-menu.service 2>/dev/null || true";
      };
      
      # System hypervisor logs
      "/var/log/hypervisor/*.log" = {
        frequency = "daily";
        rotate = lib.mkDefault 90;  # 90 days for compliance
        compress = true;
        compresscmd = "${pkgs.gzip}/bin/gzip";
        compressext = ".gz";
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "0640 root root";
        sharedscripts = true;
        postrotate = "systemctl reload syslog-ng.service > /dev/null 2>&1 || true";
      };
      
      # VM-specific logs
      "/var/log/hypervisor/vms/*.log" = {
        frequency = "weekly";
        rotate = 12;  # 12 weeks
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "0640 root root";
      };
    };
  };
}
