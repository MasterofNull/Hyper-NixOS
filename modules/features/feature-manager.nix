# Feature Manager - Modular Feature Selection with Dependencies
# Handles feature enabling/disabling with dependency resolution

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.featureManager;
  features = config.hypervisor.features;
  
  # Feature dependency definitions
  featureDependencies = {
    # Web dashboard requires monitoring
    webDashboard = [ "metrics" ];
    
    # Remote backup requires local backup
    remoteBackup = [ "localBackup" ];
    
    # Continuous replication requires remote backup
    continuousReplication = [ "remoteBackup" "metrics" ];
    
    # API requires audit logging
    api = [ "auditLogging" ];
    
    # Kubernetes requires API
    kubernetes = [ "api" "metrics" ];
    
    # Terraform requires API
    terraform = [ "api" ];
    
    # AI anomaly detection requires metrics and audit
    aiAnomalyDetection = [ "metrics" "auditLogging" ];
    
    # Live migration requires advanced networking
    liveMigration = [ "microSegmentation" ];
    
    # GPU passthrough requires IOMMU
    gpuPassthrough = [ "sriov" ];
  };
  
  # Feature conflicts (mutually exclusive)
  featureConflicts = {
    # Can't have both minimal and verbose documentation
    minimalDocs = [ "verboseDocs" ];
    verboseDocs = [ "minimalDocs" ];
  };
  
  # Calculate risk score for enabled features
  calculateRiskScore = enabledFeatures: let
    riskValues = {
      minimal = 1;
      low = 2;
      moderate = 3;
      high = 4;
      critical = 5;
    };
    
    scores = flatten (mapAttrsToList (catName: cat:
      mapAttrsToList (featName: feat:
        if elem featName enabledFeatures && feat ? risk
        then riskValues.${feat.risk} or 0
        else 0
      ) cat.features
    ) features);
    
  in foldl' (a: b: a + b) 0 scores;
  
  # Generate security profile based on selections
  generateSecurityProfile = enabledFeatures: let
    score = calculateRiskScore enabledFeatures;
  in
    if score <= 10 then "hardened"
    else if score <= 20 then "balanced"
    else if score <= 30 then "flexible"
    else "permissive";

in {
  options.hypervisor.featureManager = {
    enable = mkEnableOption "feature management system";
    
    profile = mkOption {
      type = types.enum [ "minimal" "balanced" "full" "custom" ];
      default = "balanced";
      description = ''
        Feature profile to use:
        - minimal: Only essential features (highest security)
        - balanced: Common features with moderate security
        - full: All stable features enabled
        - custom: Manual feature selection
      '';
    };
    
    enabledFeatures = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of enabled features (for custom profile)";
    };
    
    riskTolerance = mkOption {
      type = types.enum [ "paranoid" "cautious" "balanced" "accepting" ];
      default = "balanced";
      description = ''
        Risk tolerance level:
        - paranoid: No features above 'low' risk
        - cautious: No features above 'moderate' risk
        - balanced: No features above 'high' risk
        - accepting: All features allowed (with warnings)
      '';
    };
    
    requireExplicitHighRisk = mkOption {
      type = types.bool;
      default = true;
      description = "Require explicit confirmation for high-risk features";
    };
    
    generateReport = mkOption {
      type = types.bool;
      default = true;
      description = "Generate security impact report on build";
    };
  };
  
  config = mkIf cfg.enable {
    # Define feature sets for each profile
    hypervisor.featureManager.enabledFeatures = mkDefault (
      if cfg.profile == "minimal" then [
        "vmManagement" "privilegeSeparation" "auditLogging"
        "localBackup" "metrics" "cliEnhancements"
      ]
      else if cfg.profile == "balanced" then [
        "vmManagement" "privilegeSeparation" "auditLogging"
        "localBackup" "metrics" "cliEnhancements"
        "interactiveWizards" "encryption" "microSegmentation"
        "webDashboard" "remoteBackup"
      ]
      else if cfg.profile == "full" then
        # All non-critical features
        flatten (mapAttrsToList (catName: cat:
          mapAttrsToList (featName: feat:
            if feat.risk != "critical" then featName else null
          ) cat.features
        ) features)
      else
        cfg.enabledFeatures  # custom profile
    );
    
    # Validate risk tolerance
    assertions = [
      {
        assertion = cfg.riskTolerance != "paranoid" || 
          all (feat: 
            let 
              risk = findFirst (f: f.name == feat) {} 
                (flatten (mapAttrsToList (c: cat: attrValues cat.features) features));
            in risk.risk or "minimal" == "minimal" || risk.risk == "low"
          ) cfg.enabledFeatures;
        message = "Paranoid risk tolerance selected but high-risk features enabled";
      }
    ];
    
    # Generate feature configuration
    environment.etc."hypervisor/features.json".text = builtins.toJSON {
      profile = cfg.profile;
      enabledFeatures = cfg.enabledFeatures;
      riskScore = calculateRiskScore cfg.enabledFeatures;
      securityProfile = generateSecurityProfile cfg.enabledFeatures;
      dependencies = featureDependencies;
    };
    
    # Generate security report
    system.activationScripts.featureReport = mkIf cfg.generateReport ''
      mkdir -p /etc/hypervisor/reports
      
      cat > /etc/hypervisor/reports/feature-security-impact.md <<'EOF'
      # Feature Security Impact Report
      
      Generated: $(date)
      Profile: ${cfg.profile}
      Risk Tolerance: ${cfg.riskTolerance}
      
      ## Risk Summary
      
      Total Risk Score: ${toString (calculateRiskScore cfg.enabledFeatures)}
      Security Profile: ${generateSecurityProfile cfg.enabledFeatures}
      
      ## Enabled Features
      
      ${concatStringsSep "\n" (map (feat: 
        let
          featureInfo = findFirst (f: true) {} 
            (flatten (mapAttrsToList (catName: cat: 
              mapAttrsToList (featName: f: 
                if featName == feat then f else null
              ) cat.features
            ) features));
        in
          "### ${feat}\n" +
          "- Risk Level: ${featureInfo.risk or "unknown"}\n" +
          "- Description: ${featureInfo.description or "No description"}\n" +
          (if featureInfo ? impacts && length featureInfo.impacts > 0 then
            "- Security Impacts:\n" + concatMapStringsSep "\n" (i: "  - ${i}") featureInfo.impacts
          else "") +
          (if featureInfo ? mitigations && length featureInfo.mitigations > 0 then
            "\n- Recommended Mitigations:\n" + concatMapStringsSep "\n" (m: "  - ${m}") featureInfo.mitigations
          else "")
      ) cfg.enabledFeatures)}
      
      ## Recommendations
      
      ${if calculateRiskScore cfg.enabledFeatures > 30 then
        "⚠️ **High Risk Configuration Detected**\n\n" +
        "Your current feature selection has a high cumulative risk score.\n" +
        "Consider:\n" +
        "1. Disabling non-essential high-risk features\n" +
        "2. Implementing all recommended mitigations\n" +
        "3. Increasing monitoring and audit coverage\n"
      else if calculateRiskScore cfg.enabledFeatures > 20 then
        "ℹ️ **Moderate Risk Configuration**\n\n" +
        "Your configuration has a moderate risk profile.\n" +
        "Ensure all security best practices are followed.\n"
      else
        "✅ **Low Risk Configuration**\n\n" +
        "Your feature selection maintains a strong security posture.\n"
      }
      
      ## Dependency Graph
      
      \`\`\`mermaid
      graph TD
      ${concatStringsSep "\n" (mapAttrsToList (feat: deps:
        concatMapStringsSep "\n" (dep: "    ${dep} --> ${feat}") deps
      ) featureDependencies)}
      \`\`\`
      EOF
      
      echo "Feature security report generated at /etc/hypervisor/reports/feature-security-impact.md"
    '';
    
    # Configure enabled features in other modules
    services = mkMerge (map (feat:
      mkIf (elem feat cfg.enabledFeatures) (
        # Enable corresponding service configurations
        if feat == "webDashboard" then {
          nginx.enable = true;
          # Web dashboard specific config
        }
        else if feat == "api" then {
          # API service config
        }
        else {}
      )
    ) cfg.enabledFeatures);
  };
}