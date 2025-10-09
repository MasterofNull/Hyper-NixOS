{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../scripts/vfio-boot.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "hypervisor";
  time.timeZone = "UTC";

  # Hardened kernel and auditing
  boot.kernelPackages = pkgs.linuxPackages_hardened;
  services.auditd.enable = true;
  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
  };

  # Minimal packages
  environment.systemPackages = with pkgs; [
    qemu_full
    OVMF
    jq
    python3
    curl
    newt  # provides `whiptail`
    dialog
    nano
    libvirt
    virt-install
    pciutils
    looking-glass-client
    gnupg
  ];

  # Provide menu and profiles from this repository at runtime
  environment.etc."hypervisor/menu.py".source = ../hypervisor_manager/menu.py;
  environment.etc."hypervisor/vm_profiles".source = ../vm_profiles;
  environment.etc."hypervisor/isos".source = ../isos;
  environment.etc."hypervisor/scripts".source = ../scripts;
  environment.etc."hypervisor/config.json".source = ../configuration/config.json;

  # Create an unprivileged user that can access KVM
  users.users.hypervisor = {
    isNormalUser = true;
    extraGroups = [ "kvm" "libvirtd" "video" ];
    createHome = false;
  };

  # Create state dirs for OVMF vars, disks, XML, profiles, ISOs
  systemd.tmpfiles.rules = [
    "d /var/lib/hypervisor 0750 hypervisor hypervisor - -"
    "d /var/lib/hypervisor/isos 0750 hypervisor hypervisor - -"
    "d /var/lib/hypervisor/disks 0750 hypervisor hypervisor - -"
    "d /var/lib/hypervisor/xml 0750 hypervisor hypervisor - -"
    "d /var/lib/hypervisor/vm_profiles 0750 hypervisor hypervisor - -"
    "d /var/lib/hypervisor/gnupg 0700 hypervisor hypervisor - -"
    "d /var/lib/hypervisor/backups 0750 hypervisor hypervisor - -"
    "d /var/log/hypervisor 0750 hypervisor hypervisor - -"
  ];

  # Enable libvirt for virsh/XML workflows
  virtualisation.libvirtd.enable = true;

  # Start the VM selection menu at boot on the console
  systemd.services.hypervisor-menu = {
    description = "Boot-time Hypervisor VM Menu";
    wantedBy = [ "multi-user.target" ];
    after = [ "getty@tty1.service" "network-online.target" ];
    wants = [ "getty@tty1.service" "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /etc/hypervisor/scripts/menu.sh";
      WorkingDirectory = "/etc/hypervisor";
      User = "hypervisor";
      SupplementaryGroups = [ "kvm" "video" ];
      Restart = "always";
      RestartSec = 2;
      Environment = [
        "SDL_VIDEODRIVER=kmsdrm"
        "SDL_AUDIODRIVER=alsa"
        "XDG_RUNTIME_DIR=/run/user/$(id -u hypervisor)"
      ];

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = false; # allow /dev/kvm
      DeviceAllow = [ "/dev/kvm rw" "/dev/dri/* rw" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      SystemCallFilter = [ "@system-service" "@pkey" "@chown" ];
    };
  };

  # Security hardening
  networking.firewall.enable = true;
  services.openssh.enable = false;
  security.apparmor.enable = true;
  boot.kernelParams = [ "apparmor=1" "security=apparmor" ];

  # Avoid starting unnecessary daemons
  services.printing.enable = false;
  hardware.pulseaudio.enable = false;
  sound.enable = false;
  services.xserver.enable = false;
  hardware.opengl.enable = true;
}

