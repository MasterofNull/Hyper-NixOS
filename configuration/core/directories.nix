{ config, lib, pkgs, ... }:

# Directory Structure and Permissions
# Consolidated directory creation and permissions management
# Manages /var/lib/hypervisor and related directories

let
  mgmtUser = lib.attrByPath ["hypervisor" "management" "userName"] "hypervisor" config;
  activeProfile = lib.attrByPath ["hypervisor" "security" "profile"] "headless" config;
  isHeadless = activeProfile == "headless";
  isManagement = activeProfile == "management";
in {
  systemd.tmpfiles.rules = lib.mkMerge [
    # ═══════════════════════════════════════════════════════════════
    # Common Directories (all profiles)
    # ═══════════════════════════════════════════════════════════════
    [
      "d /var/log/hypervisor 0750 root root - -"
      "d /var/log/hypervisor/vms 0755 root root -"
      "d /var/www/hypervisor 0755 root root - -"
      "d /var/www/hypervisor/templates 0755 root root - -"
      "d /var/www/hypervisor/static 0755 root root - -"
    ]
    
    # ═══════════════════════════════════════════════════════════════
    # Headless Profile Directories
    # Zero-trust: root:libvirtd ownership, operator has group access
    # ═══════════════════════════════════════════════════════════════
    (lib.mkIf isHeadless [
      "d /var/lib/hypervisor 0755 root libvirtd - -"
      "d /var/lib/hypervisor/isos 0775 root libvirtd - -"
      "d /var/lib/hypervisor/disks 0770 root libvirtd - -"
      "d /var/lib/hypervisor/xml 0775 root libvirtd - -"
      "d /var/lib/hypervisor/vm_profiles 0775 root libvirtd - -"
      "d /var/lib/hypervisor/backups 0770 root libvirtd - -"
      "d /var/lib/hypervisor/logs 0770 root libvirtd - -"
      "d /var/lib/hypervisor/templates 0755 root root -"
      "d /var/lib/hypervisor/reports 0755 root root -"
      "d /var/lib/hypervisor/keys 0700 root root -"
      "d /var/lib/hypervisor/secrets 0700 root root - -"
      "d /var/lib/hypervisor-operator 0700 hypervisor-operator hypervisor-operator - -"
      "d /var/lib/hypervisor-operator/.gnupg 0700 hypervisor-operator hypervisor-operator - -"
    ])
    
    # ═══════════════════════════════════════════════════════════════
    # Management Profile Directories
    # Management user has full ownership
    # ═══════════════════════════════════════════════════════════════
    (lib.mkIf isManagement [
      "d /var/lib/hypervisor 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/isos 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/disks 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/xml 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/vm_profiles 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/gnupg 0700 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/backups 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/logs 0750 ${mgmtUser} ${mgmtUser} - -"
      "d /var/lib/hypervisor/templates 0755 root root -"
      "d /var/lib/hypervisor/reports 0755 root root -"
      "d /var/lib/hypervisor/keys 0700 root root -"
      "d /var/lib/hypervisor/secrets 0700 root root - -"
    ])
  ];
}
