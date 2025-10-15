{ config, lib, pkgs, ... }:
let cfg = config.hypervisor.enterprise.federation;
in {
  options.hypervisor.enterprise.federation.enable = lib.mkEnableOption "federation feature";
  config = lib.mkIf cfg.enable {
    environment.etc."hypervisor/features/federation.conf".text = ''
      FEATURE_NAME="federation"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
    '';
  };
}
