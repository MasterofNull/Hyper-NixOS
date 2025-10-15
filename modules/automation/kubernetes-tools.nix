{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.automation.kubernetesTools;
in
{
  options.hypervisor.automation.kubernetesTools = {
    enable = lib.mkEnableOption "Kubernetes management tools";
  };
  
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.kubectl
      pkgs.kubernetes-helm
      pkgs.k9s
      pkgs.kubectx
      pkgs.kustomize
    ];
    
    environment.etc."hypervisor/features/kubernetes-tools.conf".text = ''
      FEATURE_NAME="kubernetes-tools"
      FEATURE_STATUS="enabled"
    '';
  };
}
