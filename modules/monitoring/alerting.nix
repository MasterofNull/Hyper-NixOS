{ config, lib, pkgs, ... }:

# Alerting Configuration
# Integrates alert_manager.sh with system monitoring

{
  # Install alert dependencies
  environment.systemPackages = [
    pkgs.mailutils  # For email alerts
    pkgs.curl       # For webhooks
  ];
  
  # Systemd service for alert manager
  systemd.services.hypervisor-alert-test = {
    description = "Test Hyper-NixOS Alert System";
    wantedBy = [ ];  # Manual start only
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/alert_manager.sh info 'Alert System' 'Alert system is operational'";
    };
  };
  
  # Example alert configuration file
  environment.etc."hypervisor/alerts.conf.example" = {
    text = ''
      # Hyper-NixOS Alert Configuration
      # Copy to /var/lib/hypervisor/configuration/alerts.conf and configure
      
      # Email Alerts
      EMAIL_ENABLED=false
      EMAIL_TO="admin@example.com"
      EMAIL_FROM="hypervisor@$(hostname)"
      
      # SMTP Configuration (for email)
      SMTP_SERVER="smtp.gmail.com"
      SMTP_PORT=587
      SMTP_USER="your-email@gmail.com"
      SMTP_PASS="CHANGEME_YOUR_APP_PASSWORD"
      
      # Webhook Alerts (Slack, Discord, Teams, etc.)
      WEBHOOK_ENABLED=false
      WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
      
      # Examples:
      # Slack: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
      # Discord: https://discord.com/api/webhooks/000000000000000000/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      # Teams: https://outlook.office.com/webhook/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX@XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/IncomingWebhook/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    '';
  };
}
