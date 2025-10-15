# Enhanced VM Configuration Module - Inspired by Proxmox
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.vms;
  
  # Common volume options for different disk types
  volumeOptions = {
    options = {
      size = mkOption {
        type = types.str;
        description = "Size of the volume (e.g., '32G', '100G', '1T')";
        example = "32G";
      };
      
      cache = mkOption {
        type = types.enum [ "none" "writethrough" "writeback" "unsafe" "directsync" ];
        default = "none";
        description = "Cache mode for the disk";
      };
      
      format = mkOption {
        type = types.enum [ "raw" "qcow2" "vmdk" "vdi" ];
        default = "qcow2";
        description = "Disk image format";
      };
      
      discard = mkOption {
        type = types.bool;
        default = false;
        description = "Enable discard/trim support";
      };
      
      iothread = mkOption {
        type = types.bool;
        default = false;
        description = "Enable I/O thread for better performance";
      };
      
      ssd = mkOption {
        type = types.bool;
        default = false;
        description = "Emulate SSD (sets rotation rate to 1)";
      };
      
      backup = mkOption {
        type = types.bool;
        default = true;
        description = "Include this disk in backups";
      };
      
      replicate = mkOption {
        type = types.bool;
        default = false;
        description = "Enable replication for this disk";
      };
      
      aio = mkOption {
        type = types.enum [ "native" "threads" "io_uring" ];
        default = "native";
        description = "Asynchronous I/O mode";
      };
      
      mbps_rd = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Read speed limit in MB/s";
      };
      
      mbps_wr = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Write speed limit in MB/s";
      };
      
      iops_rd = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Read IOPS limit";
      };
      
      iops_wr = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Write IOPS limit";
      };
    };
  };
  
  # Network interface options
  netOptions = {
    options = {
      model = mkOption {
        type = types.enum [ "virtio" "e1000" "e1000e" "rtl8139" "vmxnet3" ];
        default = "virtio";
        description = "Network card model";
      };
      
      bridge = mkOption {
        type = types.str;
        description = "Network bridge to connect to";
        example = "vmbr0";
      };
      
      tag = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "VLAN tag (1-4094)";
      };
      
      firewall = mkOption {
        type = types.bool;
        default = true;
        description = "Enable firewall on this interface";
      };
      
      link_down = mkOption {
        type = types.bool;
        default = false;
        description = "Simulate unplugged cable";
      };
      
      macaddr = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "MAC address (auto-generated if not specified)";
        example = "52:54:00:12:34:56";
      };
      
      mtu = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "MTU size";
      };
      
      queues = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Number of packet queues for multiqueue";
      };
      
      rate = mkOption {
        type = types.nullOr types.float;
        default = null;
        description = "Rate limit in MB/s";
      };
    };
  };
  
  # CPU configuration options
  cpuOptions = {
    options = {
      type = mkOption {
        type = types.str;
        default = "host";
        description = "CPU type (host, kvm64, or specific model)";
        example = "Skylake-Server";
      };
      
      flags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "CPU flags to add/remove";
        example = [ "+aes" "-svm" "+avx2" ];
      };
      
      hidden = mkOption {
        type = types.bool;
        default = false;
        description = "Hide KVM signature from VM";
      };
    };
  };
  
  # Cloud-init options
  cloudInitOptions = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable cloud-init support";
      };
      
      user = mkOption {
        type = types.str;
        default = "cloud-user";
        description = "Default user for cloud-init";
      };
      
      password = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Password for default user (use passwordHash instead)";
      };
      
      passwordHash = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Password hash for default user";
      };
      
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "SSH public keys to add";
      };
      
      nameservers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "DNS nameservers";
        example = [ "8.8.8.8" "8.8.4.4" ];
      };
      
      searchdomain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "DNS search domain";
      };
      
      upgrade = mkOption {
        type = types.bool;
        default = false;
        description = "Upgrade packages on first boot";
      };
      
      packages = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional packages to install";
        example = [ "qemu-guest-agent" "curl" "vim" ];
      };
      
      userData = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Custom cloud-init user data";
      };
    };
  };
  
  # PCI device passthrough options
  pciDeviceOptions = {
    options = {
      host = mkOption {
        type = types.str;
        description = "Host PCI ID (e.g., '01:00.0')";
      };
      
      pcie = mkOption {
        type = types.bool;
        default = false;
        description = "Present as PCIe device (requires Q35 machine type)";
      };
      
      rombar = mkOption {
        type = types.bool;
        default = true;
        description = "Include ROM BAR";
      };
      
      romfile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom ROM file";
      };
      
      x-vga = mkOption {
        type = types.bool;
        default = false;
        description = "Enable VGA mode (for GPU passthrough)";
      };
    };
  };
  
  # VM configuration options
  vmOptions = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create this VM";
      };
      
      # Basic settings
      memory = mkOption {
        type = types.int;
        description = "Memory size in MB";
        example = 4096;
      };
      
      balloon = mkOption {
        type = types.int;
        default = 0;
        description = "Minimum memory for ballooning (0 to disable)";
      };
      
      cores = mkOption {
        type = types.int;
        default = 1;
        description = "Number of CPU cores per socket";
      };
      
      sockets = mkOption {
        type = types.int;
        default = 1;
        description = "Number of CPU sockets";
      };
      
      vcpus = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Number of hotpluggable CPUs";
      };
      
      cpu = mkOption {
        type = types.submodule cpuOptions;
        default = {};
        description = "CPU configuration";
      };
      
      numa = mkOption {
        type = types.bool;
        default = false;
        description = "Enable NUMA support";
      };
      
      # Machine settings
      machine = mkOption {
        type = types.str;
        default = "q35";
        description = "Machine type (pc, q35, etc.)";
      };
      
      bios = mkOption {
        type = types.enum [ "seabios" "ovmf" ];
        default = "seabios";
        description = "BIOS type";
      };
      
      # Boot settings
      boot = mkOption {
        type = types.str;
        default = "order=scsi0;ide2;net0";
        description = "Boot order";
      };
      
      bootdisk = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Primary boot disk";
      };
      
      # Display settings
      vga = mkOption {
        type = types.enum [ "std" "cirrus" "vmware" "qxl" "serial0" "serial1" "serial2" "serial3" "none" "virtio" ];
        default = "std";
        description = "VGA hardware type";
      };
      
      # Disks
      scsi = mkOption {
        type = types.attrsOf (types.submodule volumeOptions);
        default = {};
        description = "SCSI disks";
      };
      
      sata = mkOption {
        type = types.attrsOf (types.submodule volumeOptions);
        default = {};
        description = "SATA disks";
      };
      
      ide = mkOption {
        type = types.attrsOf (types.submodule volumeOptions);
        default = {};
        description = "IDE disks";
      };
      
      virtio = mkOption {
        type = types.attrsOf (types.submodule volumeOptions);
        default = {};
        description = "VirtIO disks";
      };
      
      # Network interfaces
      net = mkOption {
        type = types.attrsOf (types.submodule netOptions);
        default = {};
        description = "Network interfaces";
      };
      
      # PCI passthrough
      hostpci = mkOption {
        type = types.attrsOf (types.submodule pciDeviceOptions);
        default = {};
        description = "PCI devices to pass through";
      };
      
      # USB devices
      usb = mkOption {
        type = types.attrsOf (types.attrs);
        default = {};
        description = "USB devices";
      };
      
      # Serial ports
      serial = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Serial devices";
      };
      
      # Features
      agent = mkOption {
        type = types.bool;
        default = false;
        description = "Enable QEMU Guest Agent";
      };
      
      tablet = mkOption {
        type = types.bool;
        default = true;
        description = "Enable USB tablet device for mouse";
      };
      
      kvm = mkOption {
        type = types.bool;
        default = true;
        description = "Enable KVM hardware virtualization";
      };
      
      acpi = mkOption {
        type = types.bool;
        default = true;
        description = "Enable ACPI";
      };
      
      # Cloud-init
      cloudInit = mkOption {
        type = types.submodule cloudInitOptions;
        default = {};
        description = "Cloud-init configuration";
      };
      
      # Advanced options
      args = mkOption {
        type = types.str;
        default = "";
        description = "Additional QEMU command line arguments";
      };
      
      hookscript = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Hook script for VM lifecycle events";
      };
      
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "VM description";
      };
      
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Tags for grouping/filtering";
      };
      
      protection = mkOption {
        type = types.bool;
        default = false;
        description = "Protect VM from accidental deletion";
      };
      
      # Resource limits
      cpulimit = mkOption {
        type = types.nullOr types.float;
        default = null;
        description = "CPU usage limit (0.0-sockets*cores)";
      };
      
      cpuunits = mkOption {
        type = types.int;
        default = 1024;
        description = "CPU weight for scheduling (1-262144)";
      };
      
      # Migration settings
      migrate_downtime = mkOption {
        type = types.float;
        default = 0.1;
        description = "Maximum downtime during migration (seconds)";
      };
      
      migrate_speed = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum migration speed (MB/s)";
      };
      
      # Startup/shutdown
      onboot = mkOption {
        type = types.bool;
        default = false;
        description = "Start VM on host boot";
      };
      
      startup = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Startup order and delay";
        example = "order=2,up=30";
      };
      
      shutdown = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Shutdown timeout";
        example = "timeout=60";
      };
    };
  };
in
{
  options.hypervisor.vms = mkOption {
    type = types.attrsOf (types.submodule vmOptions);
    default = {};
    description = "Virtual machine definitions";
  };
  
  config = {
    # Generate VM configurations
    # This would integrate with the existing Hyper-NixOS VM management
  };
}