{ config, lib, pkgs, ... }:

# Production Security Configuration
# Additional production-specific security hardening
# 
# Note: Most security settings have been extracted to specialized modules:
# - Kernel hardening: security/kernel-hardening.nix
# - SSH configuration: security/ssh.nix
# - Firewall: security/firewall.nix
# - Audit/Libvirt/AppArmor: security/base.nix
#
# This module is now a placeholder for future production-specific settings.

{
  # Import note: This file is kept for backwards compatibility
  # Most settings have been consolidated into other security modules
  
  # Add any production-specific overrides here
}
