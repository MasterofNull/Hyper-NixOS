# VM Templates and Cloning System - Inspired by Proxmox
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.templates;
  
  # Cloud-init configuration options
  cloudInitOptions = {
    options = {
      user = mkOption {
        type = types.str;
        default = "cloud-user";
        description = "Default username";
      };
      
      password = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User password (use passwordHash instead)";
      };
      
      passwordHash = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User password hash";
      };
      
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "SSH public keys";
      };
      
      packages = mkOption {
        type = types.listOf types.str;
        default = [ "qemu-guest-agent" ];
        description = "Packages to install";
      };
      
      runcmd = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Commands to run on first boot";
      };
      
      writeFiles = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = "Files to write";
        example = [{
          path = "/etc/motd";
          content = "Welcome to your cloud instance!";
          permissions = "0644";
        }];
      };
      
      growpart = {
        mode = mkOption {
          type = types.enum [ "auto" "growpart" "off" ];
          default = "auto";
          description = "Partition growing mode";
        };
        
        devices = mkOption {
          type = types.listOf types.str;
          default = [ "/" ];
          description = "Devices to grow";
        };
      };
      
      locale = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = "System locale";
      };
      
      timezone = mkOption {
        type = types.str;
        default = "UTC";
        description = "System timezone";
      };
      
      ntp = {
        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Enable NTP";
        };
        
        servers = mkOption {
          type = types.listOf types.str;
          default = [ "0.pool.ntp.org" "1.pool.ntp.org" ];
          description = "NTP servers";
        };
      };
    };
  };
  
  # Template options
  templateOptions = {
    options = {
      fromVM = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "VM ID to convert to template";
      };
      
      baseImage = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Base image file to use";
      };
      
      description = mkOption {
        type = types.str;
        description = "Template description";
      };
      
      osType = mkOption {
        type = types.enum [ "linux" "windows" "other" ];
        default = "linux";
        description = "Operating system type";
      };
      
      version = mkOption {
        type = types.str;
        default = "1.0";
        description = "Template version";
      };
      
      cloudInit = mkOption {
        type = types.submodule cloudInitOptions;
        default = {};
        description = "Default cloud-init configuration";
      };
      
      defaultConfig = mkOption {
        type = types.attrs;
        default = {};
        description = "Default VM configuration for clones";
        example = {
          memory = 2048;
          cores = 2;
          agent = true;
        };
      };
      
      locked = mkOption {
        type = types.bool;
        default = true;
        description = "Lock template to prevent accidental changes";
      };
      
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Template tags";
      };
      
      minResources = {
        memory = mkOption {
          type = types.int;
          default = 512;
          description = "Minimum memory in MB";
        };
        
        disk = mkOption {
          type = types.str;
          default = "10G";
          description = "Minimum disk size";
        };
        
        cores = mkOption {
          type = types.int;
          default = 1;
          description = "Minimum CPU cores";
        };
      };
    };
  };
  
  # Clone customization options
  cloneCustomizationOptions = {
    options = {
      hostname = mkOption {
        type = types.str;
        description = "Hostname for the clone";
      };
      
      ipconfig = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Network configuration";
        example = {
          net0 = "ip=192.168.1.100/24,gw=192.168.1.1";
          net1 = "ip=dhcp";
        };
      };
      
      nameserver = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "DNS server";
      };
      
      searchdomain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "DNS search domain";
      };
      
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional SSH keys (merged with template)";
      };
      
      userData = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Custom cloud-init user data";
      };
    };
  };
  
  # Generate cloud-init ISO
  generateCloudInitISO = name: template: customization: pkgs.writeShellScript "generate-cloudinit-${name}" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    WORK_DIR=$(mktemp -d)
    trap "rm -rf $WORK_DIR" EXIT
    
    # Generate meta-data
    cat > "$WORK_DIR/meta-data" << EOF
    instance-id: ${customization.hostname}
    local-hostname: ${customization.hostname}
    EOF
    
    # Generate network-config
    cat > "$WORK_DIR/network-config" << EOF
    version: 2
    ethernets:
    ${concatStringsSep "\n" (mapAttrsToList (iface: config: ''
      ${iface}:
        ${if hasInfix "dhcp" config then ''
        dhcp4: true
        '' else ''
        addresses: [${head (splitString "," config)}]
        ${optionalString (hasInfix "gw=" config) ''
        gateway4: ${elemAt (splitString "=" (elemAt (splitString "," config) 1)) 1}
        ''}
        ''}
    '') customization.ipconfig)}
    EOF
    
    # Generate user-data
    if [[ -n "${customization.userData or ""}" ]]; then
        cat > "$WORK_DIR/user-data" << 'EOF'
    ${customization.userData}
    EOF
    else
        cat > "$WORK_DIR/user-data" << EOF
    #cloud-config
    hostname: ${customization.hostname}
    fqdn: ${customization.hostname}${optionalString (customization.searchdomain != null) ".${customization.searchdomain}"}
    
    users:
      - name: ${template.cloudInit.user}
        groups: wheel, adm
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ${optionalString (template.cloudInit.passwordHash != null) ''
        passwd: ${template.cloudInit.passwordHash}
        ''}
        ${optionalString (template.cloudInit.sshKeys != [] || customization.sshKeys != []) ''
        ssh_authorized_keys:
        ${concatMapStringsSep "\n" (key: "  - ${key}") (template.cloudInit.sshKeys ++ customization.sshKeys)}
        ''}
    
    ${optionalString (template.cloudInit.packages != []) ''
    packages:
    ${concatMapStringsSep "\n" (pkg: "  - ${pkg}") template.cloudInit.packages}
    ''}
    
    ${optionalString (template.cloudInit.runcmd != []) ''
    runcmd:
    ${concatMapStringsSep "\n" (cmd: "  - ${cmd}") template.cloudInit.runcmd}
    ''}
    
    ${optionalString (template.cloudInit.writeFiles != []) ''
    write_files:
    ${concatMapStringsSep "\n" (file: ''
      - path: ${file.path}
        content: |
          ${file.content}
        permissions: '${file.permissions or "0644"}'
    '') template.cloudInit.writeFiles}
    ''}
    
    growpart:
      mode: ${template.cloudInit.growpart.mode}
      devices: [${concatStringsSep ", " template.cloudInit.growpart.devices}]
      
    locale: ${template.cloudInit.locale}
    timezone: ${template.cloudInit.timezone}
    
    ${optionalString template.cloudInit.ntp.enabled ''
    ntp:
      enabled: true
      servers:
      ${concatMapStringsSep "\n" (server: "  - ${server}") template.cloudInit.ntp.servers}
    ''}
    
    ${optionalString (customization.nameserver != null) ''
    manage_etc_hosts: true
    manage_resolv_conf: true
    resolv_conf:
      nameservers: ['${customization.nameserver}']
      ${optionalString (customization.searchdomain != null) ''
      searchdomains: ['${customization.searchdomain}']
      ''}
    ''}
    EOF
    fi
    
    # Generate ISO
    genisoimage -output "$1" -volid cidata -joliet -rock \
        "$WORK_DIR/user-data" "$WORK_DIR/meta-data" "$WORK_DIR/network-config" 2>/dev/null
  '';
in
{
  options.hypervisor.templates = mkOption {
    type = types.attrsOf (types.submodule templateOptions);
    default = {};
    description = "VM template definitions";
    example = literalExpression ''
      {
        ubuntu-2204 = {
          description = "Ubuntu 22.04 LTS Server";
          baseImage = ./images/ubuntu-22.04-server.qcow2;
          osType = "linux";
          version = "22.04";
          
          cloudInit = {
            user = "ubuntu";
            packages = [ "qemu-guest-agent" "htop" "vim" ];
            locale = "en_US.UTF-8";
            timezone = "UTC";
          };
          
          defaultConfig = {
            memory = 2048;
            cores = 2;
            agent = true;
            boot = "order=scsi0";
            vga = "qxl";
          };
          
          tags = [ "linux" "ubuntu" "lts" ];
        };
        
        windows-2022 = {
          fromVM = "vm-999";
          description = "Windows Server 2022";
          osType = "windows";
          version = "2022";
          
          defaultConfig = {
            memory = 4096;
            cores = 2;
            bios = "ovmf";
            machine = "q35";
          };
          
          tags = [ "windows" "server" ];
        };
      }
    '';
  };
  
  config = {
    # Template management script
    environment.etc."hypervisor/scripts/template-manager.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # VM Template Management
        
        set -euo pipefail
        
        SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
        source "''${SCRIPT_DIR}/lib/common.sh"
        
        # List templates
        list_templates() {
            echo "Available Templates:"
            echo "==================="
            ${concatStringsSep "\n" (mapAttrsToList (name: template: ''
              echo
              echo "Template: ${name}"
              echo "  Description: ${template.description}"
              echo "  OS Type: ${template.osType}"
              echo "  Version: ${template.version}"
              ${optionalString (template.fromVM != null) ''echo "  Source VM: ${template.fromVM}"''}
              ${optionalString (template.baseImage != null) ''echo "  Base Image: ${template.baseImage}"''}
              echo "  Locked: ${if template.locked then "Yes" else "No"}"
              ${optionalString (template.tags != []) ''echo "  Tags: ${concatStringsSep ", " template.tags}"''}
              echo "  Min Requirements:"
              echo "    Memory: ${toString template.minResources.memory} MB"
              echo "    Disk: ${template.minResources.disk}"
              echo "    Cores: ${toString template.minResources.cores}"
            '') cfg)}
        }
        
        # Create template from VM
        create_template() {
            local vm_id="$1"
            local template_name="$2"
            
            echo "Creating template from VM: $vm_id"
            
            # Check if VM exists
            if ! virsh dominfo "$vm_id" >/dev/null 2>&1; then
                die "VM $vm_id not found"
            fi
            
            # Stop VM if running
            if virsh domstate "$vm_id" | grep -q running; then
                echo "Stopping VM..."
                virsh shutdown "$vm_id"
                
                # Wait for shutdown
                timeout=60
                while [[ $timeout -gt 0 ]] && virsh domstate "$vm_id" | grep -q running; do
                    sleep 1
                    ((timeout--))
                done
            fi
            
            # Convert to template
            template_dir="/var/lib/hypervisor/templates/$template_name"
            mkdir -p "$template_dir"
            
            # Export VM configuration
            virsh dumpxml "$vm_id" > "$template_dir/config.xml"
            
            # Copy disk images
            while read -r disk; do
                source=$(echo "$disk" | awk '{print $2}')
                target="$template_dir/$(basename "$source")"
                echo "Copying disk: $source -> $target"
                cp --sparse=always "$source" "$target"
                
                # Make read-only
                chmod 444 "$target"
            done < <(virsh domblklist "$vm_id" | grep -E '(vd|sd|hd)')
            
            # Lock template
            touch "$template_dir/.locked"
            
            echo "Template created: $template_name"
        }
        
        # Show template info
        show_template() {
            local template_name="$1"
            
            case "$template_name" in
              ${concatStringsSep "\n" (mapAttrsToList (name: template: ''
                ${name})
                  echo "Template: ${name}"
                  echo "Description: ${template.description}"
                  echo "OS Type: ${template.osType}"
                  echo "Version: ${template.version}"
                  echo
                  echo "Cloud-Init Configuration:"
                  echo "  Default User: ${template.cloudInit.user}"
                  echo "  Packages: ${concatStringsSep ", " template.cloudInit.packages}"
                  echo "  Locale: ${template.cloudInit.locale}"
                  echo "  Timezone: ${template.cloudInit.timezone}"
                  echo
                  echo "Default VM Configuration:"
                  ${concatStringsSep "\n" (mapAttrsToList (k: v: 
                    ''echo "  ${k}: ${toString v}"''
                  ) template.defaultConfig)}
                  ;;
              '') cfg)}
              *)
                echo "Unknown template: $template_name"
                return 1
                ;;
            esac
        }
        
        # Main command handling
        case "''${1:-list}" in
            list)
                list_templates
                ;;
            create)
                if [[ $# -lt 3 ]]; then
                    echo "Usage: $0 create <vm-id> <template-name>"
                    exit 1
                fi
                create_template "$2" "$3"
                ;;
            show)
                if [[ -z "''${2:-}" ]]; then
                    echo "Usage: $0 show <template-name>"
                    exit 1
                fi
                show_template "$2"
                ;;
            *)
                echo "Usage: $0 {list|create|show}"
                exit 1
                ;;
        esac
      '';
    };
    
    # VM cloning script
    environment.etc."hypervisor/scripts/vm-clone.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # VM Cloning with Template Support
        
        set -euo pipefail
        
        SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
        source "''${SCRIPT_DIR}/lib/common.sh"
        
        # Default values
        TEMPLATE=""
        NEW_VM_NAME=""
        HOSTNAME=""
        MEMORY=""
        CORES=""
        LINKED_CLONE=false
        FULL_CLONE=false
        START_AFTER_CLONE=false
        
        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -t|--template)
                    TEMPLATE="$2"
                    shift 2
                    ;;
                -n|--name)
                    NEW_VM_NAME="$2"
                    shift 2
                    ;;
                -h|--hostname)
                    HOSTNAME="$2"
                    shift 2
                    ;;
                -m|--memory)
                    MEMORY="$2"
                    shift 2
                    ;;
                -c|--cores)
                    CORES="$2"
                    shift 2
                    ;;
                -l|--linked)
                    LINKED_CLONE=true
                    shift
                    ;;
                -f|--full)
                    FULL_CLONE=true
                    shift
                    ;;
                -s|--start)
                    START_AFTER_CLONE=true
                    shift
                    ;;
                --ip)
                    IP_CONFIG="$2"
                    shift 2
                    ;;
                *)
                    die "Unknown option: $1"
                    ;;
            esac
        done
        
        # Validate inputs
        [[ -z "$TEMPLATE" ]] && die "Template name required (-t)"
        [[ -z "$NEW_VM_NAME" ]] && die "New VM name required (-n)"
        [[ -z "$HOSTNAME" ]] && HOSTNAME="$NEW_VM_NAME"
        
        # Get template configuration
        case "$TEMPLATE" in
          ${concatStringsSep "\n" (mapAttrsToList (name: template: ''
            ${name})
              echo "Using template: ${name}"
              
              # Set defaults from template
              : ''${MEMORY:=${toString template.defaultConfig.memory or 2048}}
              : ''${CORES:=${toString template.defaultConfig.cores or 2}}
              
              # Check minimum requirements
              if [[ $MEMORY -lt ${toString template.minResources.memory} ]]; then
                  die "Memory must be at least ${toString template.minResources.memory} MB"
              fi
              if [[ $CORES -lt ${toString template.minResources.cores} ]]; then
                  die "Cores must be at least ${toString template.minResources.cores}"
              fi
              
              # Clone process
              ${if template.fromVM != null then ''
                # Clone from VM template
                echo "Cloning from VM: ${template.fromVM}"
                
                if [[ "$LINKED_CLONE" == "true" ]]; then
                    virt-clone --original ${template.fromVM} --name "$NEW_VM_NAME" \
                        --preserve-data --file /var/lib/libvirt/images/$NEW_VM_NAME.qcow2 \
                        --check path_exists=off
                else
                    virt-clone --original ${template.fromVM} --name "$NEW_VM_NAME" --auto-clone
                fi
              '' else if template.baseImage != null then ''
                # Clone from base image
                echo "Creating VM from base image: ${template.baseImage}"
                
                # Create VM directory
                vm_dir="/var/lib/libvirt/images/$NEW_VM_NAME"
                mkdir -p "$vm_dir"
                
                # Copy or create linked clone
                if [[ "$LINKED_CLONE" == "true" ]]; then
                    qemu-img create -f qcow2 -b ${template.baseImage} -F qcow2 \
                        "$vm_dir/disk0.qcow2" ${template.minResources.disk}
                else
                    cp --sparse=always ${template.baseImage} "$vm_dir/disk0.qcow2"
                    qemu-img resize "$vm_dir/disk0.qcow2" ${template.minResources.disk}
                fi
                
                # Create VM definition
                virt-install --name "$NEW_VM_NAME" \
                    --memory $MEMORY \
                    --vcpus $CORES \
                    --disk "$vm_dir/disk0.qcow2" \
                    --import \
                    --os-variant ${if template.osType == "linux" then "linux2020" else "win2k19"} \
                    --network bridge=vmbr0 \
                    --graphics spice \
                    --noautoconsole
              '' else ''
                die "Template ${name} has no source VM or base image"
              ''}
              
              # Generate cloud-init ISO if Linux
              ${optionalString (template.osType == "linux") ''
                echo "Generating cloud-init ISO..."
                
                # Create customization
                cat > /tmp/clone-custom-$$.nix << EOF
                {
                  hostname = "$HOSTNAME";
                  ipconfig = {
                    net0 = "''${IP_CONFIG:-ip=dhcp}";
                  };
                  ${optionalString (template.cloudInit.sshKeys != []) ''
                  sshKeys = [
                    ${concatMapStringsSep "\n    " (key: ''"${key}"'') template.cloudInit.sshKeys}
                  ];
                  ''}
                }
                EOF
                
                # Generate ISO
                iso_path="/var/lib/libvirt/images/$NEW_VM_NAME-cloudinit.iso"
                ${generateCloudInitISO name template "$(cat /tmp/clone-custom-$$.nix)"} "$iso_path"
                rm /tmp/clone-custom-$$.nix
                
                # Attach cloud-init ISO
                virsh attach-disk "$NEW_VM_NAME" "$iso_path" hdb --type cdrom --mode readonly
              ''}
              
              # Update VM configuration
              virsh setmemory "$NEW_VM_NAME" --config $(( $MEMORY * 1024 ))
              virsh setvcpus "$NEW_VM_NAME" --config $CORES
              
              echo "Clone created: $NEW_VM_NAME"
              
              ${optionalString START_AFTER_CLONE ''
                echo "Starting VM..."
                virsh start "$NEW_VM_NAME"
              ''}
              ;;
          '') cfg)}
          *)
            die "Unknown template: $TEMPLATE"
            ;;
        esac
      '';
    };
    
    # Quick clone wrapper script
    environment.etc."hypervisor/scripts/quick-deploy.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Quick VM deployment from templates
        
        set -euo pipefail
        
        SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
        
        # Interactive template selection
        echo "Available templates:"
        echo "==================="
        
        templates=(${concatStringsSep " " (attrNames cfg)})
        
        for i in "''${!templates[@]}"; do
            echo "$((i+1))) ''${templates[$i]}"
        done
        
        echo
        read -p "Select template (1-''${#templates[@]}): " selection
        
        if [[ $selection -lt 1 ]] || [[ $selection -gt ''${#templates[@]} ]]; then
            echo "Invalid selection"
            exit 1
        fi
        
        template="''${templates[$((selection-1))]}"
        
        # Get VM details
        read -p "VM name: " vm_name
        read -p "Hostname [$vm_name]: " hostname
        hostname="''${hostname:-$vm_name}"
        
        read -p "Memory (MB) [2048]: " memory
        memory="''${memory:-2048}"
        
        read -p "CPU cores [2]: " cores
        cores="''${cores:-2}"
        
        read -p "IP configuration [dhcp]: " ip_config
        ip_config="''${ip_config:-dhcp}"
        
        read -p "Linked clone? [y/N]: " linked
        linked_opt=""
        if [[ "$linked" =~ ^[Yy]$ ]]; then
            linked_opt="--linked"
        fi
        
        read -p "Start after creation? [Y/n]: " start
        start_opt="--start"
        if [[ "$start" =~ ^[Nn]$ ]]; then
            start_opt=""
        fi
        
        # Create clone
        echo
        echo "Creating VM..."
        "$SCRIPT_DIR/vm-clone.sh" \
            --template "$template" \
            --name "$vm_name" \
            --hostname "$hostname" \
            --memory "$memory" \
            --cores "$cores" \
            --ip "$ip_config" \
            $linked_opt \
            $start_opt
        
        echo
        echo "VM deployed successfully!"
        ${optionalString (cfg != {}) ''
        echo "Default credentials:"
        case "$template" in
          ${concatStringsSep "\n" (mapAttrsToList (name: template: ''
            ${name})
              echo "  User: ${template.cloudInit.user}"
              ${optionalString (template.cloudInit.password != null) ''
              echo "  Password: ${template.cloudInit.password}"
              ''}
              ;;
          '') cfg)}
        esac
        ''}
      '';
    };
    
    # Create template storage directory
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/templates 0755 root root -"
    ];
  };
}