{ config, lib, pkgs, ... }:
let cfg = config.hypervisor.gui.remote_desktop;
in {
  options.hypervisor.gui.remote_desktop.enable = lib.mkEnableOption "remote-desktop feature";
  config = lib.mkIf cfg.enable {
    environment.etc."hypervisor/features/remote-desktop.conf".text = ''
      FEATURE_NAME="remote-desktop"
      FEATURE_STATUS="enabled"
      FEATURE_VERSION="1.0.0"
    '';
  };
}
