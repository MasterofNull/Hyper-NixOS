# Resource Pools and Permissions Module - Inspired by Proxmox
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.resources;
  
  # Resource pool options
  poolOptions = {
    options = {
      members = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "VM IDs that belong to this pool";
        example = [ "vm-100" "vm-101" "vm-102" ];
      };
      
      limits = {
        cpu = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum CPU cores for this pool";
        };
        
        memory = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Maximum memory for this pool";
          example = "64G";
        };
        
        storage = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Maximum storage for this pool";
          example = "500G";
        };
        
        vms = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum number of VMs in this pool";
        };
      };
      
      reserved = mkOption {
        type = types.bool;
        default = false;
        description = "Reserve resources (guaranteed allocation)";
      };
      
      priority = mkOption {
        type = types.int;
        default = 50;
        description = "Pool priority (1-100, higher = more important)";
      };
      
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Pool description";
      };
      
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Tags for categorization";
      };
    };
  };
  
  # Permission options
  permissionOptions = types.enum [
    # VM permissions
    "VM.Allocate"
    "VM.Clone"
    "VM.Config.Disk"
    "VM.Config.CDROM"
    "VM.Config.CPU"
    "VM.Config.Memory"
    "VM.Config.Network"
    "VM.Config.HWType"
    "VM.Config.Options"
    "VM.Config.Cloudinit"
    "VM.Console"
    "VM.Backup"
    "VM.Snapshot"
    "VM.Snapshot.Rollback"
    "VM.PowerMgmt"
    "VM.Monitor"
    "VM.Migrate"
    "VM.Audit"
    
    # System permissions
    "Sys.Audit"
    "Sys.Syslog"
    "Sys.Console"
    "Sys.Modify"
    "Sys.PowerMgmt"
    
    # Storage permissions
    "Datastore.Allocate"
    "Datastore.AllocateSpace"
    "Datastore.AllocateTemplate"
    "Datastore.Audit"
    
    # Pool permissions
    "Pool.Allocate"
    "Pool.Audit"
    
    # User management
    "User.Modify"
    "Group.Allocate"
    "Realm.Allocate"
    "Realm.AllocateUser"
    
    # Special
    "Permissions.Modify"
  ];
  
  # Role options
  roleOptions = {
    options = {
      permissions = mkOption {
        type = types.listOf permissionOptions;
        default = [];
        description = "List of permissions for this role";
      };
      
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Role description";
      };
      
      builtin = mkOption {
        type = types.bool;
        default = false;
        internal = true;
        description = "Whether this is a built-in role";
      };
    };
  };
  
  # User permission options
  userPermOptions = {
    options = {
      pools = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Resource pools this user can access";
      };
      
      permissions = mkOption {
        type = types.listOf permissionOptions;
        default = [];
        description = "Direct permissions (in addition to role permissions)";
      };
      
      roles = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles assigned to this user";
      };
      
      paths = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
        description = "Path-specific permissions";
        example = {
          "/vms/100" = [ "VM.Console" "VM.PowerMgmt" ];
          "/storage/local" = [ "Datastore.Audit" ];
        };
      };
    };
  };
  
  # Group permission options
  groupPermOptions = {
    options = {
      permissions = mkOption {
        type = types.listOf permissionOptions;
        default = [];
        description = "Permissions for all group members";
      };
      
      roles = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles assigned to this group";
      };
      
      pools = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Resource pools this group can access";
      };
      
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Group description";
      };
    };
  };
  
  # Built-in roles
  builtinRoles = {
    NoAccess = {
      permissions = [];
      description = "No access";
      builtin = true;
    };
    
    Monitor = {
      permissions = [
        "VM.Monitor"
        "VM.Audit"
        "Datastore.Audit"
        "Sys.Audit"
        "Pool.Audit"
      ];
      description = "Read-only access";
      builtin = true;
    };
    
    VMUser = {
      permissions = [
        "VM.Console"
        "VM.PowerMgmt"
        "VM.Monitor"
        "VM.Audit"
        "VM.Backup"
      ];
      description = "Basic VM user";
      builtin = true;
    };
    
    VMPowerUser = {
      permissions = [
        "VM.Console"
        "VM.PowerMgmt"
        "VM.Monitor"
        "VM.Audit"
        "VM.Backup"
        "VM.Snapshot"
        "VM.Config.CDROM"
        "VM.Config.Network"
      ];
      description = "Advanced VM user";
      builtin = true;
    };
    
    VMAdmin = {
      permissions = [
        "VM.Allocate"
        "VM.Clone"
        "VM.Config.Disk"
        "VM.Config.CDROM"
        "VM.Config.CPU"
        "VM.Config.Memory"
        "VM.Config.Network"
        "VM.Config.HWType"
        "VM.Config.Options"
        "VM.Config.Cloudinit"
        "VM.Console"
        "VM.Backup"
        "VM.Snapshot"
        "VM.Snapshot.Rollback"
        "VM.PowerMgmt"
        "VM.Monitor"
        "VM.Migrate"
        "VM.Audit"
        "Datastore.AllocateSpace"
      ];
      description = "Full VM administration";
      builtin = true;
    };
    
    DatastoreUser = {
      permissions = [
        "Datastore.Audit"
        "Datastore.AllocateSpace"
      ];
      description = "Storage user";
      builtin = true;
    };
    
    DatastoreAdmin = {
      permissions = [
        "Datastore.Allocate"
        "Datastore.AllocateSpace"
        "Datastore.AllocateTemplate"
        "Datastore.Audit"
      ];
      description = "Storage administrator";
      builtin = true;
    };
    
    PoolUser = {
      permissions = [
        "Pool.Audit"
      ];
      description = "Pool user";
      builtin = true;
    };
    
    PoolAdmin = {
      permissions = [
        "Pool.Allocate"
        "Pool.Audit"
        "VM.Allocate"
        "VM.Clone"
        "Datastore.Allocate"
      ];
      description = "Pool administrator";
      builtin = true;
    };
    
    Administrator = {
      permissions = []; # All permissions implied
      description = "Full system administrator";
      builtin = true;
    };
  };
  
  # Generate permission check script
  generatePermissionCheck = ''
    #!/usr/bin/env bash
    # Permission checking utility
    
    set -euo pipefail
    
    check_permission() {
        local user="$1"
        local permission="$2"
        local path="''${3:-/}"
        
        # Check if user is administrator
        if [[ " ${concatStringsSep " " (attrNames (filterAttrs (n: v: elem "Administrator" v.roles) cfg.permissions.users))} " =~ " $user " ]]; then
            echo "ALLOW: Administrator role"
            return 0
        fi
        
        # Check direct user permissions
        ${concatStringsSep "\n" (mapAttrsToList (username: perms: ''
          if [[ "$user" == "${username}" ]]; then
              # Check direct permissions
              if [[ " ${concatStringsSep " " perms.permissions} " =~ " $permission " ]]; then
                  echo "ALLOW: Direct user permission"
                  return 0
              fi
              
              # Check role permissions
              ${concatStringsSep "\n" (map (role: ''
                if [[ " ${concatStringsSep " " (cfg.roles.${role}.permissions or [])} " =~ " $permission " ]]; then
                    echo "ALLOW: Role ${role}"
                    return 0
                fi
              '') perms.roles)}
              
              # Check path-specific permissions
              ${concatStringsSep "\n" (mapAttrsToList (path: pathPerms: ''
                if [[ "$path" == "${path}" ]] || [[ "$path" == "${path}/"* ]]; then
                    if [[ " ${concatStringsSep " " pathPerms} " =~ " $permission " ]]; then
                        echo "ALLOW: Path-specific permission for ${path}"
                        return 0
                    fi
                fi
              '') perms.paths)}
          fi
        '') cfg.permissions.users)}
        
        # Check group permissions
        local user_groups=$(id -Gn "$user" 2>/dev/null || echo "")
        ${concatStringsSep "\n" (mapAttrsToList (groupname: perms: ''
          if [[ " $user_groups " =~ " ${groupname} " ]]; then
              # Check group permissions
              if [[ " ${concatStringsSep " " perms.permissions} " =~ " $permission " ]]; then
                  echo "ALLOW: Group ${groupname} permission"
                  return 0
              fi
              
              # Check group role permissions
              ${concatStringsSep "\n" (map (role: ''
                if [[ " ${concatStringsSep " " (cfg.roles.${role}.permissions or [])} " =~ " $permission " ]]; then
                    echo "ALLOW: Group role ${role}"
                    return 0
                fi
              '') perms.roles)}
          fi
        '') cfg.permissions.groups)}
        
        echo "DENY: No permission"
        return 1
    }
    
    # Main
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <username> <permission> [path]"
        exit 1
    fi
    
    check_permission "$@"
  '';
in
{
  options.hypervisor.resources = {
    pools = mkOption {
      type = types.attrsOf (types.submodule poolOptions);
      default = {};
      description = "Resource pool definitions";
      example = literalExpression ''
        {
          development = {
            members = [ "vm-100" "vm-101" "vm-102" ];
            limits = {
              cpu = 16;
              memory = "64G";
              storage = "500G";
              vms = 10;
            };
            priority = 30;
            description = "Development environment VMs";
            tags = [ "dev" "testing" ];
          };
          
          production = {
            members = [ "vm-200" "vm-201" ];
            limits = {
              cpu = 32;
              memory = "128G";
              storage = "2T";
            };
            reserved = true;
            priority = 90;
            description = "Production VMs";
            tags = [ "prod" "critical" ];
          };
        }
      '';
    };
    
    roles = mkOption {
      type = types.attrsOf (types.submodule roleOptions);
      default = builtinRoles;
      description = "Role definitions";
    };
    
    permissions = {
      users = mkOption {
        type = types.attrsOf (types.submodule userPermOptions);
        default = {};
        description = "User permission assignments";
        example = literalExpression ''
          {
            developer = {
              pools = [ "development" ];
              roles = [ "VMPowerUser" ];
              permissions = [ "VM.Console" "VM.Snapshot" ];
              paths = {
                "/vms/100" = [ "VM.Config.Memory" "VM.Config.CPU" ];
              };
            };
            
            operator = {
              roles = [ "VMAdmin" "DatastoreUser" ];
              pools = [ "development" "staging" ];
            };
          }
        '';
      };
      
      groups = mkOption {
        type = types.attrsOf (types.submodule groupPermOptions);
        default = {};
        description = "Group permission assignments";
        example = literalExpression ''
          {
            admins = {
              roles = [ "Administrator" ];
              description = "System administrators";
            };
            
            developers = {
              roles = [ "VMUser" ];
              pools = [ "development" ];
              permissions = [ "VM.Console" ];
            };
          }
        '';
      };
    };
    
    # Resource quotas
    quotas = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable resource quota enforcement";
      };
      
      checkInterval = mkOption {
        type = types.int;
        default = 300;
        description = "Quota check interval in seconds";
      };
      
      enforcement = mkOption {
        type = types.enum [ "soft" "hard" ];
        default = "hard";
        description = "Quota enforcement mode";
      };
    };
  };
  
  config = {
    # Install permission check script
    environment.etc."hypervisor/scripts/check-permission.sh" = {
      mode = "0755";
      text = generatePermissionCheck;
    };
    
    # Resource pool management script
    environment.etc."hypervisor/scripts/pool-manager.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Resource pool management
        
        set -euo pipefail
        
        list_pools() {
            echo "Resource Pools:"
            echo "==============="
            ${concatStringsSep "\n" (mapAttrsToList (name: pool: ''
              echo
              echo "Pool: ${name}"
              echo "  Members: ${concatStringsSep ", " pool.members}"
              ${optionalString (pool.limits.cpu != null) ''echo "  CPU Limit: ${toString pool.limits.cpu} cores"''}
              ${optionalString (pool.limits.memory != null) ''echo "  Memory Limit: ${pool.limits.memory}"''}
              ${optionalString (pool.limits.storage != null) ''echo "  Storage Limit: ${pool.limits.storage}"''}
              ${optionalString (pool.limits.vms != null) ''echo "  VM Limit: ${toString pool.limits.vms}"''}
              echo "  Priority: ${toString pool.priority}"
              ${optionalString pool.reserved ''echo "  Reserved: Yes"''}
              ${optionalString (pool.description != null) ''echo "  Description: ${pool.description}"''}
              ${optionalString (pool.tags != []) ''echo "  Tags: ${concatStringsSep ", " pool.tags}"''}
            '') cfg.pools)}
        }
        
        check_pool_usage() {
            local pool_name="$1"
            
            case "$pool_name" in
              ${concatStringsSep "\n" (mapAttrsToList (name: pool: ''
                ${name})
                  echo "Pool: ${name}"
                  echo "Members: ${toString (length pool.members)}"
                  # Here we would calculate actual usage
                  echo "CPU Usage: calculating..."
                  echo "Memory Usage: calculating..."
                  echo "Storage Usage: calculating..."
                  ;;
              '') cfg.pools)}
              *)
                echo "Unknown pool: $pool_name"
                return 1
                ;;
            esac
        }
        
        case "''${1:-list}" in
            list)
                list_pools
                ;;
            usage)
                if [[ -n "''${2:-}" ]]; then
                    check_pool_usage "$2"
                else
                    for pool in ${concatStringsSep " " (attrNames cfg.pools)}; do
                        check_pool_usage "$pool"
                        echo
                    done
                fi
                ;;
            *)
                echo "Usage: $0 {list|usage [pool-name]}"
                exit 1
                ;;
        esac
      '';
    };
    
    # Permission management script
    environment.etc."hypervisor/scripts/permission-manager.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        # Permission management utility
        
        set -euo pipefail
        
        list_roles() {
            echo "Available Roles:"
            echo "================"
            ${concatStringsSep "\n" (mapAttrsToList (name: role: ''
              echo
              echo "Role: ${name}"
              ${optionalString (role.description != null) ''echo "  Description: ${role.description}"''}
              ${optionalString role.builtin ''echo "  Type: Built-in"''}
              echo "  Permissions:"
              ${concatStringsSep "\n" (map (perm: ''echo "    - ${perm}"'') role.permissions)}
            '') cfg.roles)}
        }
        
        list_users() {
            echo "User Permissions:"
            echo "================="
            ${concatStringsSep "\n" (mapAttrsToList (name: user: ''
              echo
              echo "User: ${name}"
              ${optionalString (user.roles != []) ''echo "  Roles: ${concatStringsSep ", " user.roles}"''}
              ${optionalString (user.pools != []) ''echo "  Pools: ${concatStringsSep ", " user.pools}"''}
              ${optionalString (user.permissions != []) ''
                echo "  Direct Permissions:"
                ${concatStringsSep "\n" (map (perm: ''echo "    - ${perm}"'') user.permissions)}
              ''}
              ${optionalString (user.paths != {}) ''
                echo "  Path Permissions:"
                ${concatStringsSep "\n" (mapAttrsToList (path: perms: 
                  ''echo "    ${path}: ${concatStringsSep ", " perms}"''
                ) user.paths)}
              ''}
            '') cfg.permissions.users)}
        }
        
        list_groups() {
            echo "Group Permissions:"
            echo "=================="
            ${concatStringsSep "\n" (mapAttrsToList (name: group: ''
              echo
              echo "Group: ${name}"
              ${optionalString (group.description != null) ''echo "  Description: ${group.description}"''}
              ${optionalString (group.roles != []) ''echo "  Roles: ${concatStringsSep ", " group.roles}"''}
              ${optionalString (group.pools != []) ''echo "  Pools: ${concatStringsSep ", " group.pools}"''}
              ${optionalString (group.permissions != []) ''
                echo "  Permissions:"
                ${concatStringsSep "\n" (map (perm: ''echo "    - ${perm}"'') group.permissions)}
              ''}
            '') cfg.permissions.groups)}
        }
        
        case "''${1:-help}" in
            roles)
                list_roles
                ;;
            users)
                list_users
                ;;
            groups)
                list_groups
                ;;
            check)
                if [[ $# -lt 3 ]]; then
                    echo "Usage: $0 check <user> <permission> [path]"
                    exit 1
                fi
                shift
                /etc/hypervisor/scripts/check-permission.sh "$@"
                ;;
            *)
                echo "Usage: $0 {roles|users|groups|check}"
                echo
                echo "Commands:"
                echo "  roles  - List all available roles"
                echo "  users  - List user permissions"
                echo "  groups - List group permissions"
                echo "  check  - Check if user has permission"
                exit 1
                ;;
        esac
      '';
    };
    
    # Quota enforcement service
    systemd.services.hypervisor-quota-enforcement = mkIf cfg.quotas.enable {
      description = "Hypervisor Resource Quota Enforcement";
      after = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "30s";
        ExecStart = pkgs.writeShellScript "quota-enforcement" ''
          #!/usr/bin/env bash
          
          while true; do
              # Check each pool's resource usage
              ${concatStringsSep "\n" (mapAttrsToList (name: pool: ''
                # Check pool ${name}
                members="${concatStringsSep " " pool.members}"
                total_cpu=0
                total_mem=0
                
                for vm in $members; do
                    # Get VM resource usage (placeholder)
                    # In real implementation, query libvirt
                    :
                done
                
                # Enforce limits if needed
                ${optionalString (pool.limits.cpu != null) ''
                  if [[ $total_cpu -gt ${toString pool.limits.cpu} ]]; then
                      echo "Pool ${name} exceeds CPU limit"
                      ${optionalString (cfg.quotas.enforcement == "hard") ''
                        # Take enforcement action
                        :
                      ''}
                  fi
                ''}
              '') cfg.pools)}
              
              sleep ${toString cfg.quotas.checkInterval}
          done
        '';
      };
    };
  };
}