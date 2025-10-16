# Capability-Based Security Model with Temporal Access
# Implements fine-grained capabilities with time-bound permissions
{ config, lib, pkgs, ... }:

# Removed: with lib; - Using explicit lib. prefix for clarity
let
  cfg = config.hypervisor.security.capabilities;
  
  # Capability definition
  capabilityDefinition = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Capability name";
      };
      
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Capability description";
      };
      
      # Resource-based permissions
      resources = {
        compute = lib.mkOption {
          type = lib.types.submodule {
            options = {
              create = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can create compute units";
              };
              
              modify = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can modify compute units";
              };
              
              delete = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can delete compute units";
              };
              
              control = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can control (start/stop) compute units";
              };
              
              console = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can access compute unit console";
              };
              
              limits = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    maxUnits = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                      description = "Maximum compute units";
                    };
                    
                    maxResources = lib.mkOption {
                      type = lib.types.nullOr lib.types.int;
                      default = null;
                      description = "Maximum resource units";
                    };
                  };
                });
                default = null;
                description = "Resource limits";
              };
            };
          };
          default = {};
          description = "Compute resource permissions";
        };
        
        storage = lib.mkOption {
          type = lib.types.submodule {
            options = {
              read = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can read storage";
              };
              
              write = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can write to storage";
              };
              
              allocate = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can allocate new storage";
              };
              
              snapshot = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can create snapshots";
              };
              
              tiers = lib.mkOption {
                type = lib.types.listOf lib.types.int;
                default = [];
                description = "Allowed storage tiers";
              };
              
              quota = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Storage quota";
                example = "100Gi";
              };
            };
          };
          default = {};
          description = "Storage permissions";
        };
        
        network = lib.mkOption {
          type = lib.types.submodule {
            options = {
              configure = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can configure network";
              };
              
              attach = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can attach to networks";
              };
              
              create = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can create networks";
              };
              
              capabilities = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Allowed network capabilities";
                example = [ "public-internet" "internal-only" ];
              };
            };
          };
          default = {};
          description = "Network permissions";
        };
        
        cluster = lib.mkOption {
          type = lib.types.submodule {
            options = {
              join = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can join nodes to cluster";
              };
              
              configure = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can configure cluster";
              };
              
              schedule = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Can influence scheduling";
              };
            };
          };
          default = {};
          description = "Cluster permissions";
        };
      };
      
      # Operations allowed
      operations = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Allowed operations";
        example = [ "backup" "restore" "migrate" "monitor" ];
      };
      
      # Delegation rights
      delegation = {
        allowed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Can delegate this capability";
        };
        
        maxDepth = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Maximum delegation depth";
        };
        
        restrictions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Restrictions when delegating";
        };
      };
      
      # Conditions
      conditions = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            type = lib.mkOption {
              type = lib.types.enum [ "label" "time" "location" "rate" "context" ];
              description = "Condition type";
            };
            
            config = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              description = "Condition configuration";
            };
          };
        });
        default = [];
        description = "Conditions for capability validity";
      };
    };
  };
  
  # Temporal access definition
  temporalAccessDefinition = {
    options = {
      # Time-based access
      validity = {
        start = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Access start time (RFC3339)";
          example = "2023-01-01T00:00:00Z";
        };
        
        end = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Access end time (RFC3339)";
          example = "2023-12-31T23:59:59Z";
        };
        
        duration = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Access duration from grant time";
          example = "24h";
        };
      };
      
      # Recurring access windows
      schedule = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            timezone = lib.mkOption {
              type = lib.types.str;
              default = "UTC";
              description = "Schedule timezone";
            };
            
            windows = lib.mkOption {
              type = lib.types.listOf (lib.types.submodule {
                options = {
                  days = lib.mkOption {
                    type = lib.types.listOf (lib.types.enum [
                      "monday" "tuesday" "wednesday" "thursday"
                      "friday" "saturday" "sunday"
                    ]);
                    description = "Days of week";
                  };
                  
                  startTime = lib.mkOption {
                    type = lib.types.str;
                    description = "Start time (HH:MM)";
                    example = "09:00";
                  };
                  
                  endTime = lib.mkOption {
                    type = lib.types.str;
                    description = "End time (HH:MM)";
                    example = "17:00";
                  };
                };
              });
              default = [];
              description = "Access windows";
            };
          };
        });
        default = null;
        description = "Recurring access schedule";
      };
      
      # Usage limits
      usage = {
        maxUses = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Maximum number of uses";
        };
        
        rateLimit = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              requests = lib.mkOption {
                type = lib.types.int;
                description = "Number of requests";
              };
              
              window = lib.mkOption {
                type = lib.types.str;
                description = "Time window";
                example = "1h";
              };
            };
          });
          default = null;
          description = "Rate limiting";
        };
      };
      
      # Emergency access
      emergency = {
        breakGlass = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow emergency access override";
        };
        
        auditRequired = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Require audit for emergency access";
        };
        
        notificationList = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Notify on emergency access";
        };
      };
    };
  };
  
  # Principal (user/service/group)
  principalDefinition = {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "user" "service" "group" "token" ];
        description = "Principal type";
      };
      
      identity = {
        id = lib.mkOption {
          type = lib.types.str;
          description = "Principal identifier";
        };
        
        attributes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Principal attributes";
          example = { department = "engineering"; clearance = "secret"; };
        };
        
        authentication = {
          methods = lib.mkOption {
            type = lib.types.listOf (lib.types.enum [
              "password" "publickey" "certificate" "oidc" "saml" "webauthn"
            ]);
            default = [ "password" ];
            description = "Allowed authentication methods";
          };
          
          mfa = lib.mkOption {
            type = lib.types.submodule {
              options = {
                required = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Require MFA";
                };
                
                methods = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "totp" ];
                  description = "Allowed MFA methods";
                };
              };
            };
            default = {};
            description = "MFA requirements";
          };
        };
      };
      
      # Capability grants
      grants = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            capability = lib.mkOption {
              type = lib.types.str;
              description = "Capability name";
            };
            
            temporal = lib.mkOption {
              type = lib.types.submodule temporalAccessDefinition;
              default = {};
              description = "Temporal access constraints";
            };
            
            scope = lib.mkOption {
              type = lib.types.nullOr (lib.types.submodule {
                options = {
                  labels = lib.mkOption {
                    type = lib.types.attrsOf lib.types.str;
                    default = {};
                    description = "Label selector for scope";
                  };
                  
                  resources = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [];
                    description = "Specific resource IDs";
                  };
                };
              });
              default = null;
              description = "Grant scope";
            };
            
            delegatedFrom = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Principal who delegated this grant";
            };
          };
        });
        default = [];
        description = "Capability grants";
      };
      
      # Audit settings
      audit = {
        logLevel = lib.mkOption {
          type = lib.types.enum [ "none" "basic" "detailed" "full" ];
          default = "basic";
          description = "Audit log level";
        };
        
        alerts = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              event = lib.mkOption {
                type = lib.types.str;
                description = "Event to alert on";
              };
              
              notify = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Notification targets";
              };
            };
          });
          default = [];
          description = "Audit alerts";
        };
      };
    };
  };
  
  # Zero-trust policies
  zeroTrustPolicy = {
    continuous = {
      verification = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable continuous verification";
      };
      
      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "Verification interval";
      };
      
      factors = lib.mkOption {
        type = lib.types.listOf (lib.types.enum [
          "device-trust" "location" "behavior" "risk-score"
        ]);
        default = [ "device-trust" ];
        description = "Factors to verify";
      };
    };
    
    contextual = {
      ipRestrictions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Allowed IP ranges";
      };
      
      devicePolicy = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            managed = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Require managed device";
            };
            
            compliance = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Required compliance policies";
            };
          };
        });
        default = null;
        description = "Device requirements";
      };
    };
  };
  
in
{
  options.hypervisor.security.capabilities = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable capability-based security";
    };
    
    # Capability definitions
    capabilities = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule capabilityDefinition);
      default = {};
      description = "Available capabilities";
      example = literalExample ''
        {
          vm-operator = {
            resources.compute = {
              create = true;
              control = true;
              limits.maxUnits = 10;
            };
            operations = [ "backup" "monitor" ];
          };
        }
      '';
    };
    
    # Principal definitions
    principals = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule principalDefinition);
      default = {};
      description = "Principal definitions with grants";
    };
    
    # Zero-trust policies
    zeroTrust = lib.mkOption {
      type = lib.types.submodule zeroTrustPolicy;
      default = {};
      description = "Zero-trust security policies";
    };
    
    # Default policies
    defaults = {
      sessionTimeout = lib.mkOption {
        type = lib.types.str;
        default = "8h";
        description = "Default session timeout";
      };
      
      requireMFA = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require MFA by default";
      };
      
      auditLevel = lib.mkOption {
        type = lib.types.enum [ "none" "basic" "detailed" "full" ];
        default = "basic";
        description = "Default audit level";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Capability enforcement service
    systemd.services.capability-enforcer = {
      description = "Capability-Based Security Enforcer";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "notify";
        # Add timeout in case systemd-notify fails
        TimeoutStartSec = "30s";
        ExecStart = "${pkgs.writeShellScript "capability-enforcer" ''
          #!/usr/bin/env bash
          
          echo "Starting capability enforcer..."
          echo "Zero-trust mode: ${toString cfg.zeroTrust.continuous.verification}"
          
          # Signal ready
          systemd-notify --ready
          
          # Main enforcement loop
          while true; do
            # Check temporal access validity
            date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            
            # In real implementation:
            # - Validate active sessions
            # - Check temporal constraints
            # - Enforce rate limits
            # - Update capability cache
            
            sleep ${cfg.zeroTrust.continuous.interval}
          done
        ''}";
        
        Restart = "always";
        RestartSec = 5;
      };
    };
    
    # Capability management CLI
    environment.systemPackages = [
      (writeScriptBin "hv-cap" ''
        #!${pkgs.bash}/bin/bash
        # Capability management tool
        
        case "$1" in
          list)
            echo "Available Capabilities:"
            ${concatStringsSep "\n" (mapAttrsToList (name: cap: ''
              echo "  ${name}: ${cap.description}"
            '') cfg.capabilities)}
            ;;
            
          show)
            if [ -z "$2" ]; then
              echo "Usage: hv-cap show <capability>"
              exit 1
            fi
            echo "Capability: $2"
            # Show capability details
            ;;
            
          grant)
            if [ -z "$3" ]; then
              echo "Usage: hv-cap grant <principal> <capability>"
              exit 1
            fi
            echo "Granting $3 to $2..."
            ;;
            
          revoke)
            if [ -z "$3" ]; then
              echo "Usage: hv-cap revoke <principal> <capability>"
              exit 1
            fi
            echo "Revoking $3 from $2..."
            ;;
            
          check)
            if [ -z "$3" ]; then
              echo "Usage: hv-cap check <principal> <operation>"
              exit 1
            fi
            echo "Checking if $2 can perform $3..."
            ;;
            
          audit)
            echo "Recent capability usage:"
            tail -20 /var/log/hypervisor/capabilities.log 2>/dev/null || echo "No audit logs"
            ;;
            
          *)
            echo "Usage: hv-cap {list|show|grant|revoke|check|audit}"
            exit 1
            ;;
        esac
      '')
    ];
    
    # PAM configuration for capability-aware authentication
    security.pam.services.hypervisor-cap = {
      text = ''
        auth     required pam_env.so
        auth     sufficient pam_unix.so nullok
        auth     required pam_deny.so
        
        account  required pam_unix.so
        
        session  required pam_unix.so
        session  required pam_env.so
      '';
    };
    
    # Audit log configuration
    systemd.tmpfiles.rules = [
      "d /var/log/hypervisor 0750 root adm -"
      "f /var/log/hypervisor/capabilities.log 0640 root adm -"
      "d /var/lib/hypervisor/capabilities 0700 root root -"
      "d /var/lib/hypervisor/sessions 0700 root root -"
    ];
    
    # Generate capability database
    system.activationScripts.generateCapabilityDb = ''
      echo "Generating capability database..."
      mkdir -p /var/lib/hypervisor/capabilities
      
      cat > /var/lib/hypervisor/capabilities/capabilities.json << EOF
      ${builtins.toJSON cfg.capabilities}
      EOF
      
      cat > /var/lib/hypervisor/capabilities/principals.json << EOF
      ${builtins.toJSON cfg.principals}
      EOF
    '';
  };
}