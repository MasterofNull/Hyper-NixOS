{ config, lib, pkgs, ... }:

# Core System Settings
# Basic system-wide configuration (non-network)

{
  # Timezone
  time.timeZone = lib.mkDefault "UTC";
  
  # Disable unnecessary services
  services.printing.enable = false;
  hardware.pulseaudio.enable = false;
  sound.enable = false;
  
  # Hypervisor data directories
  environment.etc."hypervisor/vm-profiles".source = ../../vm-profiles;
  environment.etc."hypervisor/isos".source = ../../isos;
  environment.etc."hypervisor/scripts".source = ../../scripts;
  environment.etc."hypervisor/config.json".source = ../config.json;
  environment.etc."hypervisor/docs".source = ../../docs;
  environment.etc."hypervisor/vm_profile.schema.json".source = ../vm_profile.schema.json;
}
