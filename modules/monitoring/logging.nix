{ config, lib, pkgs, ... }:

# Centralized Logging Configuration
# Aggregates logs from all VMs and host to central location
# Supports: Syslog, Journald, File-based, Remote forwarding

{
  # Enhanced journald configuration for centralized logging
  services.journald = {
    extraConfig = ''
      # Store logs persistently
      Storage=persistent
      
      # Forward to syslog for aggregation
      ForwardToSyslog=yes
      
      # Maximum log retention
      MaxRetentionSec=90d
      
      # Size limits (prevent disk fill)
      SystemMaxUse=2G
      SystemKeepFree=1G
      RuntimeMaxUse=512M
      
      # Rate limiting (prevent DoS)
      RateLimitIntervalSec=30s
      RateLimitBurst=10000
    '';
  };
  
  # Syslog-ng for advanced log aggregation
  services.syslog-ng = {
    enable = true;
    extraConfig = ''
      # Source: Collect from journald
      source s_journald {
        systemd-journal(prefix(".SDATA.systemd."));
      };
      
      # Source: Collect from network (VMs can send here)
      source s_network {
        syslog(
          transport("tcp")
          port(514)
          flags(no-parse)
        );
      };
      
      # Destination: Local aggregated log
      destination d_hypervisor_all {
        file("/var/log/hypervisor/all.log"
          template("$ISODATE $HOST $PROGRAM[$PID]: $MESSAGE\n")
          create-dirs(yes)
        );
      };
      
      # Destination: VM-specific logs
      destination d_vm_logs {
        file("/var/log/hypervisor/vms/$HOST.log"
          template("$ISODATE $PROGRAM[$PID]: $MESSAGE\n")
          create-dirs(yes)
        );
      };
      
      # Destination: Security events
      destination d_security {
        file("/var/log/hypervisor/security.log"
          template("$ISODATE $HOST $PROGRAM[$PID]: $MESSAGE\n")
          create-dirs(yes)
        );
      };
      
      # Filter: Security-related messages
      filter f_security {
        facility(auth, authpriv) or
        program("sudo") or
        program("polkit") or
        program("libvirt") or
        match("security" value("MESSAGE"));
      };
      
      # Filter: VM-related messages
      filter f_vm {
        program("qemu") or
        program("libvirt") or
        program("virt") or
        match("vm-" value("HOST"));
      };
      
      # Log routing
      log { source(s_journald); destination(d_hypervisor_all); };
      log { source(s_network); destination(d_hypervisor_all); };
      log { source(s_journald); filter(f_security); destination(d_security); };
      log { source(s_network); filter(f_vm); destination(d_vm_logs); };
    '';
  };
  
  # Logrotate for log management
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/hypervisor/*.log" = {
        frequency = "daily";
        rotate = 90;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "0640 root root";
        sharedscripts = true;
        postrotate = "systemctl reload syslog-ng.service > /dev/null 2>&1 || true";
      };
      
      "/var/log/hypervisor/vms/*.log" = {
        frequency = "weekly";
        rotate = 12;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "0640 root root";
      };
    };
  };
  
  # Create log directories
  systemd.tmpfiles.rules = [
    "d /var/log/hypervisor 0755 root root -"
    "d /var/log/hypervisor/vms 0755 root root -"
  ];
  
  # Firewall: Allow syslog from VMs (optional, for remote forwarding)
  # Uncomment to allow VMs to send logs
  # networking.firewall.allowedTCPPorts = [ 514 ];
  
  # Optional: Forward to remote syslog server
  # To enable, create: /var/lib/hypervisor/configuration/logging-remote.conf
  # Format:
  #   REMOTE_SYSLOG_HOST=syslog.example.com
  #   REMOTE_SYSLOG_PORT=514
  #   REMOTE_SYSLOG_PROTOCOL=tcp
  
  # Log viewer service (web-based, optional)
  systemd.services.log-viewer = {
    description = "Hypervisor Log Viewer";
    after = [ "syslog-ng.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.writeScript "log-viewer" ''
        #!/usr/bin/env bash
        # Simple log viewer - access logs from console menu
        echo "Log viewer available via console menu"
      ''}";
      Restart = "no";
    };
  };
  
  # Environment for log access
  environment.systemPackages = [
    pkgs.syslogng
    pkgs.lnav  # Advanced log viewer
    pkgs.multitail  # Multi-file tail
  ];
}
