# Feature Categories and Risk Assessment Framework
# This module defines all available features with their security impact

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types optionalString;
  cfg = config.hypervisor.features;
  
  # Risk level definitions
  riskLevels = {
    minimal = {
      level = 1;
      color = "green";
      description = "Minimal security impact";
      icon = "🟢";
    };
    low = {
      level = 2;
      color = "blue";
      description = "Low security impact";
      icon = "🔵";
    };
    moderate = {
      level = 3;
      color = "yellow";
      description = "Moderate security impact - review recommended";
      icon = "🟡";
    };
    high = {
      level = 4;
      color = "orange";
      description = "High security impact - careful consideration required";
      icon = "🟠";
    };
    critical = {
      level = 5;
      color = "red";
      description = "Critical security impact - only enable if absolutely necessary";
      icon = "🔴";
    };
  };
  
  # Feature categories with their features and risk assessments
  featureCategories = {
    core = {
      name = "Core Features";
      description = "Essential VM management capabilities";
      icon = "🏗️";
      features = {
        vmManagement = {
          name = "Basic VM Management";
          description = "Start, stop, create, delete VMs";
          risk = "minimal";
          enabled = true;
          required = true;
          impacts = [];
        };
        privilegeSeparation = {
          name = "Privilege Separation";
          description = "Separate VM operations from system operations";
          risk = "minimal";
          enabled = true;
          required = true;
          impacts = [];
        };
        auditLogging = {
          name = "Audit Logging";
          description = "Log all operations for security tracking";
          risk = "minimal";
          enabled = true;
          impacts = [];
        };
      };
    };
    
    userExperience = {
      name = "User Experience";
      description = "Enhanced interfaces and usability features";
      icon = "🎨";
      features = {
        webDashboard = {
          name = "Web Dashboard";
          description = "Browser-based VM management interface";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Opens web ports (default: 8443)"
            "Requires TLS certificate management"
            "Increases attack surface via web interface"
          ];
          mitigations = [
            "Use strong authentication (MFA recommended)"
            "Restrict access by IP/network"
            "Regular security updates"
          ];
        };
        cliEnhancements = {
          name = "Enhanced CLI";
          description = "Advanced command-line features and auto-completion";
          risk = "low";
          enabled = true;
          impacts = [
            "Stores command history"
            "May cache sensitive data in shell completion"
          ];
        };
        interactiveWizards = {
          name = "Interactive Wizards";
          description = "Guided setup and configuration wizards";
          risk = "minimal";
          enabled = true;
          impacts = [];
        };
      };
    };
    
    networking = {
      name = "Advanced Networking";
      description = "Enhanced network capabilities and security";
      icon = "🌐";
      features = {
        microSegmentation = {
          name = "Network Micro-segmentation";
          description = "Per-VM firewall rules and isolation";
          risk = "low";
          enabled = false;
          impacts = [
            "Complexity in network configuration"
            "Potential for misconfiguration"
          ];
          benefits = [
            "Improved VM isolation"
            "Reduced lateral movement risk"
            "Granular traffic control"
          ];
        };
        sriov = {
          name = "SR-IOV Support";
          description = "Direct hardware network access for VMs";
          risk = "high";
          enabled = false;
          impacts = [
            "VMs get direct hardware access"
            "Bypasses hypervisor network controls"
            "Potential for hardware-level attacks"
          ];
          requirements = [
            "Compatible network hardware"
            "IOMMU enabled"
            "Trusted VM workloads only"
          ];
        };
        publicBridge = {
          name = "Public Network Bridge";
          description = "Allow VMs direct access to public networks";
          risk = "critical";
          enabled = false;
          impacts = [
            "VMs exposed to internet"
            "Bypasses NAT protection"
            "Direct attack surface"
          ];
          mitigations = [
            "Per-VM firewall rules mandatory"
            "IDS/IPS recommended"
            "Regular security updates critical"
          ];
        };
      };
    };
    
    storage = {
      name = "Storage Features";
      description = "Advanced storage capabilities";
      icon = "💾";
      features = {
        encryption = {
          name = "Storage Encryption";
          description = "Encrypt VM disks at rest";
          risk = "minimal";
          enabled = true;
          impacts = [
            "Slight performance overhead"
            "Key management complexity"
          ];
          benefits = [
            "Data protection at rest"
            "Compliance support"
          ];
        };
        deduplication = {
          name = "Storage Deduplication";
          description = "Reduce storage usage via deduplication";
          risk = "low";
          enabled = false;
          impacts = [
            "CPU overhead for dedup processing"
            "Potential data correlation attacks"
          ];
        };
        remoteStorage = {
          name = "Remote Storage Backends";
          description = "Support for NFS, iSCSI, S3 storage";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Network dependency for storage"
            "Credential management required"
            "Data leaves local system"
          ];
        };
      };
    };
    
    integration = {
      name = "External Integrations";
      description = "Third-party service integrations";
      icon = "🔌";
      features = {
        kubernetes = {
          name = "Kubernetes Integration";
          description = "Use VMs as Kubernetes nodes or storage";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Requires API exposure"
            "Complex permission model"
            "Container escape risks"
          ];
        };
        terraform = {
          name = "Terraform Provider";
          description = "Infrastructure as Code support";
          risk = "moderate";
          enabled = false;
          impacts = [
            "API exposure required"
            "Credentials in code risk"
            "State file security"
          ];
        };
        slack = {
          name = "Slack Notifications";
          description = "Send alerts to Slack";
          risk = "low";
          enabled = false;
          impacts = [
            "Webhook URL exposure"
            "Potential information leakage"
          ];
        };
        ldap = {
          name = "LDAP/AD Integration";
          description = "Central authentication via LDAP/AD";
          risk = "high";
          enabled = false;
          impacts = [
            "External authentication dependency"
            "Credential relay attacks"
            "Single point of failure"
          ];
          benefits = [
            "Centralized user management"
            "Enterprise integration"
          ];
        };
      };
    };
    
    monitoring = {
      name = "Monitoring & Analytics";
      description = "System monitoring and performance analytics";
      icon = "📊";
      features = {
        metrics = {
          name = "Performance Metrics";
          description = "Collect and display VM performance data";
          risk = "minimal";
          enabled = true;
          impacts = [
            "Disk usage for metrics storage"
          ];
        };
        prometheus = {
          name = "Prometheus Export";
          description = "Export metrics to Prometheus";
          risk = "low";
          enabled = false;
          impacts = [
            "Opens metrics endpoint"
            "Potential information disclosure"
          ];
        };
        aiAnomalyDetection = {
          name = "AI Anomaly Detection";
          description = "ML-based security anomaly detection";
          risk = "moderate";
          enabled = false;
          impacts = [
            "High CPU/memory usage"
            "False positive potential"
            "Model training data sensitivity"
          ];
        };
      };
    };
    
    backup = {
      name = "Backup & Recovery";
      description = "Data protection and disaster recovery";
      icon = "🔄";
      features = {
        localBackup = {
          name = "Local Backups";
          description = "Backup VMs to local storage";
          risk = "minimal";
          enabled = true;
          impacts = [
            "Storage space usage"
          ];
        };
        remoteBackup = {
          name = "Remote Backup";
          description = "Backup to remote locations";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Network bandwidth usage"
            "Remote credential management"
            "Data leaves premises"
          ];
        };
        continuousReplication = {
          name = "Continuous Replication";
          description = "Real-time VM replication";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Network bandwidth usage"
            "Performance overhead"
            "Complex failure scenarios"
          ];
        };
      };
    };
    
    developer = {
      name = "Developer Tools";
      description = "Development and automation features";
      icon = "🛠️";
      features = {
        api = {
          name = "REST/GraphQL API";
          description = "Programmatic access to VM operations";
          risk = "high";
          enabled = false;
          impacts = [
            "API attack surface"
            "Authentication complexity"
            "Rate limiting required"
          ];
          mitigations = [
            "API key rotation"
            "IP whitelisting"
            "Request signing"
          ];
        };
        cicd = {
          name = "CI/CD Integration";
          description = "Automated VM provisioning for CI/CD";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Automated access required"
            "Potential for resource exhaustion"
          ];
        };
        devEnvironments = {
          name = "Development Environments";
          description = "Pre-configured development VMs";
          risk = "low";
          enabled = false;
          impacts = [
            "Potential for insecure defaults"
            "Development tool vulnerabilities"
          ];
        };
      };
    };
    
    experimental = {
      name = "Experimental Features";
      description = "Cutting-edge features (use with caution)";
      icon = "⚡";
      features = {
        liveMigration = {
          name = "Live Migration";
          description = "Move running VMs between hosts";
          risk = "high";
          enabled = false;
          impacts = [
            "Memory contents transmitted"
            "Network security critical"
            "Complex failure modes"
          ];
        };
        gpuPassthrough = {
          name = "GPU Passthrough";
          description = "Direct GPU access for VMs";
          risk = "high";
          enabled = false;
          impacts = [
            "Hardware-level access"
            "Driver vulnerabilities"
            "Resource contention"
          ];
        };
        nestedVirt = {
          name = "Nested Virtualization";
          description = "Run VMs inside VMs";
          risk = "moderate";
          enabled = false;
          impacts = [
            "Performance overhead"
            "Complex security boundaries"
            "Escape attack chains"
          ];
        };
      };
    };
  };

in {
  options.hypervisor.features = mkOption {
    type = types.attrs;
    default = {};
    description = "Feature configuration with risk assessment";
  };
  
  config = lib.mkIf config.hypervisor.enable {
    # Export feature definitions for use by other modules
    hypervisor.features = featureCategories;
    
    # Generate security report
    system.activationScripts.featureSecurityReport = mkIf (config.hypervisor ? featureManager && config.hypervisor.featureManager.enable) ''
      echo "Generating feature security report..."
      mkdir -p /etc/hypervisor
      cat > /etc/hypervisor/FEATURE_SECURITY_REPORT.txt <<EOF
      Hyper-NixOS Feature Security Report
      Generated: $(date)
      
      Enabled Features by Risk Level:
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (catName: cat:
        lib.concatStringsSep "\n" (lib.mapAttrsToList (featName: feat:
          optionalString (lib.elem featName config.hypervisor.featureManager.enabledFeatures)
            "${feat.risk} - ${cat.name}/${feat.name}: ${feat.description}"
        ) cat.features)
      ) featureCategories)}
      
      Security Recommendations:
      - Review all features marked as 'high' or 'critical' risk
      - Ensure mitigations are in place for enabled risky features
      - Regularly audit feature usage and disable unnecessary features
      EOF
    '';
  };
}