{ config, lib, pkgs, ... }:

# Hypervisor Management Profile
# System administration with expanded sudo capabilities
# For initial setup, configuration changes, and maintenance

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
in {
  # Management user with sudo privileges
  users.users = lib.mkIf (mgmtUser == "hypervisor") {
    hypervisor = {
      isNormalUser = true;
      extraGroups = [ "wheel" "kvm" "libvirtd" "video" "input" ];
      createHome = false;
    };
  };

  # Conditional autologin for management convenience
  services.getty.autologinUser = lib.mkIf 
    ((lib.attrByPath ["hypervisor" "menu" "enableAtBoot"] true config || 
      lib.attrByPath ["hypervisor" "firstBootWizard" "enableAtBoot"] false config) && 
     !(lib.attrByPath ["hypervisor" "gui" "enableAtBoot"] false config)) 
    mgmtUser;

  # Sudo configuration for management operations
  security.sudo.wheelNeedsPassword = true;
  security.sudo.extraRules = [
    {
      users = [ mgmtUser ];
      commands = [
        # VM lifecycle operations - NOPASSWD for convenience
        { command = "${pkgs.libvirt}/bin/virsh list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh start"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh shutdown"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh reboot"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh destroy"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh suspend"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh resume"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh dominfo"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh domstate"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh domuuid"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh domifaddr"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh console"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh define"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh undefine"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-create-as"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-revert"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh snapshot-delete"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-list"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-info"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.libvirt}/bin/virsh net-dhcp-leases"; options = [ "NOPASSWD" ]; }
      ];
    }
    # Full sudo access (with password) for system administration
    { users = [ mgmtUser ]; commands = [ { command = "ALL"; } ]; }
  ];

  # Directory ownership for management user
  systemd.tmpfiles.rules = [
    "d /var/lib/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/isos 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/disks 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/xml 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/vm_profiles 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/gnupg 0700 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/backups 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/log/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
    "d /var/lib/hypervisor/logs 0750 ${mgmtUser} ${mgmtUser} - -"
  ];
}
