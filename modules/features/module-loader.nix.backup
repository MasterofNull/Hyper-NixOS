# Module Loader
# Conditionally imports modules based on enabled features
# This is the proper way to handle modular configurations

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hypervisor.featureManager;
  
  # Define which modules are needed for each feature
  featureModules = {
    # Core modules (always loaded when hypervisor is enabled)
    core = [
      ../core/system.nix
      ../core/packages.nix
      ../core/directories.nix
      ../virtualization/libvirt.nix
      ../security/base.nix
    ];
    
    # Security features
    privilegeSeparation = [
      ../security/privilege-separation.nix
      ../security/polkit-rules.nix
    ];
    
    threatDetection = [
      ../security/threat-detection.nix
      ../security/threat-response.nix
      ../security/threat-intelligence.nix
      ../security/behavioral-analysis.nix
    ];
    
    # Performance features
    optimization = [
      ../core/optimized-system.nix
      ../virtualization/performance.nix
    ];
    
    # Documentation features
    documentation = [
      ./adaptive-docs.nix
      ./educational-content.nix
    ];
  };
  
  # Determine which modules to load based on configuration
  modulesToLoad = 
    (if config.hypervisor.enable then featureModules.core else []) ++
    (if cfg.enable && elem "privilegeSeparation" cfg.enabledFeatures then featureModules.privilegeSeparation else []) ++
    (if cfg.enable && elem "threatDetection" cfg.enabledFeatures then featureModules.threatDetection else []) ++
    (if cfg.enable && elem "optimization" cfg.enabledFeatures then featureModules.optimization else []) ++
    (if cfg.enable && elem "documentation" cfg.enabledFeatures then featureModules.documentation else []);

in {
  imports = modulesToLoad;
  
  # Module loader configuration
  options.hypervisor.moduleLoader = {
    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Print loaded modules for debugging";
    };
  };
  
  config = mkIf config.hypervisor.moduleLoader.debug {
    warnings = [ "Loaded modules: ${toString modulesToLoad}" ];
  };
}