# Storage Abstraction Layer - Enterprise Storage Management
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.storage;
  
  # Storage pool types and their options
  storageTypes = {
    # Directory storage
    dir = {
      options = {
        path = mkOption {
          type = types.path;
          description = "Directory path for storage";
          example = "/var/lib/hypervisor/images";
        };
        
        preallocate = mkOption {
          type = types.bool;
          default = false;
          description = "Preallocate space for images";
        };
      };
    };
    
    # LVM storage
    lvm = {
      options = {
        vgname = mkOption {
          type = types.str;
          description = "LVM volume group name";
          example = "vg-hypervisor";
        };
        
        thin = mkOption {
          type = types.bool;
          default = true;
          description = "Use LVM thin provisioning";
        };
        
        thinpool = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Thin pool name (auto-created if null)";
        };
      };
    };
    
    # ZFS storage
    zfs = {
      options = {
        pool = mkOption {
          type = types.str;
          description = "ZFS pool/dataset name";
          example = "tank/vms";
        };
        
        compression = mkOption {
          type = types.enum [ "off" "lz4" "lzjb" "gzip" "zle" "zstd" ];
          default = "lz4";
          description = "ZFS compression algorithm";
        };
        
        snapshots = mkOption {
          type = types.bool;
          default = true;
          description = "Enable ZFS snapshots";
        };
        
        recordsize = mkOption {
          type = types.str;
          default = "64K";
          description = "ZFS record size";
        };
      };
    };
    
    # Btrfs storage
    btrfs = {
      options = {
        path = mkOption {
          type = types.path;
          description = "Btrfs filesystem path";
          example = "/mnt/btrfs-pool";
        };
        
        subvolume = mkOption {
          type = types.str;
          default = "vms";
          description = "Btrfs subvolume for VMs";
        };
        
        compression = mkOption {
          type = types.enum [ "none" "zlib" "lzo" "zstd" ];
          default = "zstd";
          description = "Btrfs compression algorithm";
        };
      };
    };
    
    # NFS storage
    nfs = {
      options = {
        server = mkOption {
          type = types.str;
          description = "NFS server address";
          example = "nas.local";
        };
        
        export = mkOption {
          type = types.str;
          description = "NFS export path";
          example = "/export/vms";
        };
        
        options = mkOption {
          type = types.str;
          default = "rw,hard,intr,nfsvers=4.2";
          description = "NFS mount options";
        };
      };
    };
    
    # Ceph/RBD storage
    rbd = {
      options = {
        pool = mkOption {
          type = types.str;
          default = "vms";
          description = "Ceph pool name";
        };
        
        monhost = mkOption {
          type = types.listOf types.str;
          description = "Ceph monitor hosts";
          example = [ "mon1.local" "mon2.local" "mon3.local" ];
        };
        
        username = mkOption {
          type = types.str;
          default = "admin";
          description = "Ceph username";
        };
        
        keyring = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to Ceph keyring";
        };
      };
    };
    
    # GlusterFS storage
    glusterfs = {
      options = {
        server = mkOption {
          type = types.str;
          description = "GlusterFS server";
        };
        
        volume = mkOption {
          type = types.str;
          description = "GlusterFS volume name";
        };
        
        options = mkOption {
          type = types.str;
          default = "defaults,_netdev";
          description = "Mount options";
        };
      };
    };
    
    # iSCSI storage
    iscsi = {
      options = {
        portal = mkOption {
          type = types.str;
          description = "iSCSI portal address";
          example = "192.168.1.10:3260";
        };
        
        target = mkOption {
          type = types.str;
          description = "iSCSI target IQN";
        };
        
        lun = mkOption {
          type = types.int;
          default = 0;
          description = "LUN number";
        };
      };
    };
  };
  
  # Storage pool configuration
  poolOptions = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable this storage pool";
      };
      
      type = mkOption {
        type = types.enum [ "dir" "lvm" "zfs" "btrfs" "nfs" "rbd" "glusterfs" "iscsi" ];
        description = "Storage pool type";
      };
      
      content = mkOption {
        type = types.listOf (types.enum [ "images" "iso" "vztmpl" "backup" "snippets" ]);
        default = [ "images" ];
        description = "Allowed content types";
      };
      
      # Dynamic options based on type
      options = mkOption {
        type = types.attrs;
        default = {};
        description = "Type-specific storage options";
      };
      
      # Common options
      priority = mkOption {
        type = types.int;
        default = 50;
        description = "Storage pool priority (0-100)";
      };
      
      maxFiles = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum number of files";
      };
      
      restricted = mkOption {
        type = types.bool;
        default = false;
        description = "Restrict to specific users/groups";
      };
      
      nodes = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Restrict to specific nodes (null = all nodes)";
      };
      
      disable = mkOption {
        type = types.bool;
        default = false;
        description = "Temporarily disable storage";
      };
    };
  };
  
  # Storage migration options
  migrationOptions = {
    options = {
      enableLiveMigration = mkOption {
        type = types.bool;
        default = true;
        description = "Enable live storage migration";
      };
      
      defaultPool = mkOption {
        type = types.str;
        default = "local";
        description = "Default storage pool for new VMs";
      };
      
      bandwidthLimit = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Migration bandwidth limit (MB/s)";
      };
      
      compression = mkOption {
        type = types.bool;
        default = true;
        description = "Compress data during migration";
      };
    };
  };
  
  # Generate storage pool service
  generatePoolService = name: pool: {
    "hypervisor-storage-${name}" = {
      description = "Hypervisor Storage Pool - ${name}";
      after = [ "network.target" ] ++ (
        if pool.type == "nfs" || pool.type == "iscsi" then [ "network-online.target" ] else []
      );
      wants = optional (pool.type == "nfs" || pool.type == "iscsi") "network-online.target";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c '${
          if pool.type == "dir" then ''
            mkdir -p ${pool.options.path}
            chown hypervisor:hypervisor ${pool.options.path}
            chmod 755 ${pool.options.path}
          '' else if pool.type == "nfs" then ''
            mkdir -p /mnt/hypervisor-storage/${name}
            mount -t nfs -o ${pool.options.options} ${pool.options.server}:${pool.options.export} /mnt/hypervisor-storage/${name}
          '' else if pool.type == "zfs" then ''
            zfs list ${pool.options.pool} >/dev/null 2>&1 || zfs create ${pool.options.pool}
            zfs set compression=${pool.options.compression} ${pool.options.pool}
            zfs set recordsize=${pool.options.recordsize} ${pool.options.pool}
          '' else if pool.type == "lvm" then ''
            vgdisplay ${pool.options.vgname} >/dev/null 2>&1 || exit 1
            ${if pool.options.thin then ''
              lvdisplay ${pool.options.vgname}/${pool.options.thinpool or "thinpool"} >/dev/null 2>&1 || \
                lvcreate -L 90%FREE -T ${pool.options.vgname}/${pool.options.thinpool or "thinpool"}
            '' else ""}
          '' else if pool.type == "btrfs" then ''
            mkdir -p ${pool.options.path}/${pool.options.subvolume}
            [[ -d ${pool.options.path}/${pool.options.subvolume} ]] || \
              btrfs subvolume create ${pool.options.path}/${pool.options.subvolume}
            btrfs property set ${pool.options.path}/${pool.options.subvolume} compression ${pool.options.compression}
          '' else ""
        }'";
        
        ExecStop = optionalString (pool.type == "nfs") ''
          ${pkgs.umount}/bin/umount /mnt/hypervisor-storage/${name}
        '';
      };
    };
  };
in
{
  options.hypervisor.storage = {
    pools = mkOption {
      type = types.attrsOf (types.submodule poolOptions);
      default = {};
      description = "Storage pool definitions";
      example = literalExpression ''
        {
          local = {
            type = "dir";
            options.path = "/var/lib/hypervisor/images";
            content = [ "images" "iso" ];
          };
          
          fast-ssd = {
            type = "lvm";
            options = {
              vgname = "vg-ssd";
              thin = true;
            };
            content = [ "images" ];
            priority = 80;
          };
          
          backup = {
            type = "nfs";
            options = {
              server = "nas.local";
              export = "/export/backups";
            };
            content = [ "backup" ];
          };
        }
      '';
    };
    
    migration = mkOption {
      type = types.submodule migrationOptions;
      default = {};
      description = "Storage migration settings";
    };
    
    # Convenience options for common setups
    defaultPools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable default storage pools";
      };
      
      localPath = mkOption {
        type = types.path;
        default = "/var/lib/hypervisor/storage";
        description = "Path for default local storage";
      };
    };
  };
  
  config = mkMerge [
    # Default pools if enabled
    (mkIf cfg.defaultPools.enable {
      hypervisor.storage.pools = {
        local = {
          type = "dir";
          options.path = "${cfg.defaultPools.localPath}/images";
          content = [ "images" "iso" "vztmpl" ];
          priority = 50;
        };
        
        local-backups = {
          type = "dir";
          options.path = "${cfg.defaultPools.localPath}/backups";
          content = [ "backup" ];
          priority = 40;
        };
      };
    })
    
    # Generate systemd services for each pool
    {
      systemd.services = mkMerge (
        mapAttrsToList generatePoolService (filterAttrs (_: pool: pool.enable && !pool.disable) cfg.pools)
      );
      
      # Storage management script
      environment.etc."hypervisor/scripts/storage-manager.sh" = {
        mode = "0755";
        text = ''
          #!/usr/bin/env bash
          # Storage pool management script
          
          set -euo pipefail
          
          SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
          source "''${SCRIPT_DIR}/lib/common.sh"
          
          # List storage pools
          list_pools() {
              echo "Storage Pools:"
              echo "=============="
              ${concatStringsSep "\n" (mapAttrsToList (name: pool: ''
                echo "${name}:"
                echo "  Type: ${pool.type}"
                echo "  Content: ${concatStringsSep ", " pool.content}"
                echo "  Priority: ${toString pool.priority}"
                ${optionalString (pool.type == "dir") ''echo "  Path: ${pool.options.path}"''}
                ${optionalString (pool.type == "zfs") ''echo "  Pool: ${pool.options.pool}"''}
                ${optionalString (pool.type == "lvm") ''echo "  VG: ${pool.options.vgname}"''}
                echo ""
              '') cfg.pools)}
          }
          
          # Check pool status
          check_pool() {
              local pool_name="$1"
              case "$pool_name" in
                ${concatStringsSep "\n" (mapAttrsToList (name: pool: ''
                  ${name})
                    ${if pool.type == "dir" then ''
                      if [[ -d "${pool.options.path}" ]]; then
                        echo "Pool ${name}: OK"
                        df -h "${pool.options.path}"
                      else
                        echo "Pool ${name}: Directory not found"
                        return 1
                      fi
                    '' else if pool.type == "zfs" then ''
                      if zfs list "${pool.options.pool}" >/dev/null 2>&1; then
                        echo "Pool ${name}: OK"
                        zfs list -o name,used,avail,refer,mountpoint "${pool.options.pool}"
                      else
                        echo "Pool ${name}: ZFS dataset not found"
                        return 1
                      fi
                    '' else if pool.type == "lvm" then ''
                      if vgdisplay "${pool.options.vgname}" >/dev/null 2>&1; then
                        echo "Pool ${name}: OK"
                        vgdisplay -s "${pool.options.vgname}"
                      else
                        echo "Pool ${name}: Volume group not found"
                        return 1
                      fi
                    '' else ''
                      echo "Pool ${name}: Type ${pool.type} status check not implemented"
                    ''}
                    ;;
                '') cfg.pools)}
                *)
                  echo "Unknown pool: $pool_name"
                  return 1
                  ;;
              esac
          }
          
          # Main command handling
          case "''${1:-list}" in
            list)
              list_pools
              ;;
            status)
              if [[ -n "''${2:-}" ]]; then
                check_pool "$2"
              else
                for pool in ${concatStringsSep " " (attrNames cfg.pools)}; do
                  check_pool "$pool" || true
                  echo ""
                done
              fi
              ;;
            *)
              echo "Usage: $0 {list|status [pool-name]}"
              exit 1
              ;;
          esac
        '';
      };
      
      # Storage allocation script
      environment.etc."hypervisor/scripts/allocate-storage.sh" = {
        mode = "0755";
        text = ''
          #!/usr/bin/env bash
          # Allocate storage for VMs based on content type and priority
          
          set -euo pipefail
          
          allocate_storage() {
              local content_type="$1"
              local size="$2"
              local name="$3"
              
              # Find suitable storage pools sorted by priority
              local suitable_pools=()
              ${concatStringsSep "\n" (mapAttrsToList (name: pool: ''
                if [[ " ${concatStringsSep " " pool.content} " =~ " $content_type " ]]; then
                  suitable_pools+=("${toString pool.priority}:${name}")
                fi
              '') cfg.pools)}
              
              # Sort by priority (highest first)
              IFS=$'\n' sorted_pools=($(sort -rn <<<"''${suitable_pools[*]}"))
              
              # Try allocation in priority order
              for pool_entry in "''${sorted_pools[@]}"; do
                local pool_name="''${pool_entry#*:}"
                echo "Trying to allocate in pool: $pool_name"
                
                # Pool-specific allocation logic would go here
                # For now, just select the first available
                echo "Allocated in pool: $pool_name"
                echo "$pool_name"
                return 0
              done
              
              echo "No suitable storage pool found for content type: $content_type"
              return 1
          }
          
          # Parse arguments
          if [[ $# -lt 3 ]]; then
              echo "Usage: $0 <content-type> <size> <name>"
              echo "Content types: images, iso, vztmpl, backup, snippets"
              exit 1
          fi
          
          allocate_storage "$@"
        '';
      };
    }
  ];
}