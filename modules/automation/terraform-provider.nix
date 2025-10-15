{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.automation.terraform;
in
{
  options.hypervisor.automation.terraform = {
    enable = lib.mkEnableOption "Terraform provider for Hyper-NixOS";
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.terraform pkgs.terraform-ls ];
    
    environment.etc."hypervisor/features/terraform.conf".text = ''
      FEATURE_NAME="terraform"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
    '';
  };
}
