{ config, lib, pkgs, ... }:

# Binary Cache and Download Optimization
# Significantly speeds up package downloads and builds

{
  nix.settings = {
    # Parallel downloads - MAJOR speed improvement
    # Default is 1 connection, this allows 25 parallel downloads
    http-connections = lib.mkDefault 25;
    
    # Parallel build jobs - use all CPU cores
    # Default is 1, "auto" uses all available cores
    max-jobs = lib.mkDefault "auto";
    
    # Use all cores for each build
    # 0 = use all available cores
    cores = lib.mkDefault 0;
    
    # Binary cache substituters (official + community)
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    
    # Trust official cache
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    
    # Keep build artifacts in cache longer
    tarball-ttl = 86400;  # 24 hours
    
    # Build on local machine if not in cache
    # But try cache first
    builders-use-substitutes = true;
    
    # Optimize for bandwidth
    # Keep downloaded files to avoid re-downloading
    keep-outputs = true;
    keep-derivations = true;
    
    # Use hard links when possible (saves disk space)
    auto-optimise-store = true;
  };
  
  # Additional Nix configuration
  nix.extraOptions = ''
    # Connection optimization
    connect-timeout = 10
    stalled-download-timeout = 60
    
    # Use HTTP/2 for better performance
    http2 = true
    
    # Retry failed downloads automatically
    download-attempts = 3
    
    # Warn instead of error for untrusted substituters
    require-sigs = true
  '';
  
  # Note: TCP optimization sysctl settings have been moved to
  # modules/security/kernel-hardening.nix to avoid duplicates
  
  # Garbage collection to save space
  # But keep recent builds
  nix.gc = {
    automatic = lib.mkDefault false;  # Manual GC only
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  
  # Optimize Nix store automatically
  nix.optimise = {
    automatic = lib.mkDefault true;
    dates = [ "weekly" ];
  };
}
