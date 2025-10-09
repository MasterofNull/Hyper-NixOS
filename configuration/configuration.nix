{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../scripts/vfio-boot.nix
    ./security.nix
  ]
  ++ lib.optional (builtins.pathExists ./performance.nix) ./performance.nix
  ++ lib.optional (builtins.pathExists ./perf-local.nix) ./perf-local.nix
  ++ lib.optional (builtins.pathExists ./security-local.nix) ./security-local.nix;

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
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "kernel.kexec_load_disabled" = 1;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
  };

  # Minimal packages
  environment.systemPackages = with pkgs; [
    qemu_full
    OVMF
    jq
    python3
    python3Packages.jsonschema
    curl
    newt  # provides `whiptail`
    dialog
    nano
    libvirt
    virt-install
    pciutils
    looking-glass-client
    gnupg
    swtpm
    openssh
    genisoimage
    nfs-utils
    openssh
  ];

  # Provide menu and profiles from this repository at runtime
  # Python TUI not exposed; primary UI is shell menu for reduced surface
  environment.etc."hypervisor/vm_profiles".source = ../vm_profiles;
  environment.etc."hypervisor/isos".source = ../isos;
  environment.etc."hypervisor/scripts".source = ../scripts;
  environment.etc."hypervisor/config.json".source = ../configuration/config.json;
  environment.etc."hypervisor/docs".source = ../docs;
  environment.etc."hypervisor/vm_profile.schema.json".source = ../configuration/vm_profile.schema.json;
  # Install libvirt hook for per-VM slice limits
  environment.etc."libvirt/hooks/qemu".source = ../scripts/libvirt_hooks/qemu;

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
  virtualisation.libvirtd.qemuRunAsRoot = false;
  virtualisation.libvirtd.extraConfig = ''
    security_driver = "apparmor"
    dynamic_ownership = 1
    clear_emulator_capabilities = 1
    seccomp_sandbox = 1
    namespaces = [ "mount", "uts", "ipc", "pid", "net" ]
  '';

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
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
    };
  };

  # First-boot wizard (runs once, then marks completion)
  systemd.services.hypervisor-first-boot = {
    description = "First-boot Setup Wizard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -lc 'if [ ! -f /var/lib/hypervisor/.first_boot_done ]; then /etc/hypervisor/scripts/setup_wizard.sh || true; touch /var/lib/hypervisor/.first_boot_done; fi'";
      User = "hypervisor";
      WorkingDirectory = "/etc/hypervisor";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  # Security hardening
  networking.firewall.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      KbdInteractiveAuthentication = false;
    };
  };
  security.apparmor.enable = true;
  security.apparmor.policies = {
    "qemu-system-x86_64".profile = builtins.readFile ../configuration/apparmor/qemu-system-x86_64;
  };
  boot.kernelParams = [ "apparmor=1" "security=apparmor" ];

  # Avoid starting unnecessary daemons
  services.printing.enable = false;
  hardware.pulseaudio.enable = false;
  sound.enable = false;
  services.xserver.enable = false;
  hardware.opengl.enable = true;
}

