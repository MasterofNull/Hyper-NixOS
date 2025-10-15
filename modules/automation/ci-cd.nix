{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.automation.cicd;
in
{
  options.hypervisor.automation.cicd = {
    enable = lib.mkEnableOption "CI/CD pipeline support";
    runner = lib.mkOption {
      type = lib.types.enum [ "gitlab" "github" "both" ];
      default = "gitlab";
    };
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pkgs.gitlab-runner
      pkgs.act  # GitHub Actions locally
    ];
    
    services.gitlab-runner.enable = lib.mkIf (cfg.runner == "gitlab" || cfg.runner == "both") true;
    
    environment.etc."hypervisor/features/ci-cd.conf".text = ''
      FEATURE_NAME="ci-cd"
      FEATURE_STATUS="enabled"
      RUNNER="${cfg.runner}"
    '';
  };
}
