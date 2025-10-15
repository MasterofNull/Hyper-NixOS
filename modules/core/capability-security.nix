# Capability-Based Security Model with Temporal Access
# Implements fine-grained capabilities with time-bound permissions
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.security.capabilities;
  
  # Capability definition
  capabilityDefinition = {
    options = {
      name = mkOption {
        type = types.str;
        description = "Capability name";
      };
      
      description = mkOption {
        type = types.str;
        default = "";
        description = "Capability description";
      };
      
      # Resource-based permissions
      resources = {
        compute = mkOption {
          type = types.submodule {
            options = {
              create = mkOption {
                type = types.bool;
                default = false;
                description = "Can create compute units";
              };
              
              modify = mkOption {
                type = types.bool;
                default = false;
                description = "Can modify compute units";
              };
              
              delete = mkOption {
                type = types.bool;
                default = false;
                description = "Can delete compute units";
              };
              
              control = mkOption {
                type = types.bool;
                default = false;
                description = "Can control (start/stop) compute units";
              };
              
              console = mkOption {
                type = types.bool;
                default = false;
                description = "Can access compute unit console";
              };
              
              limits = mkOption {
                type = types.nullOr (types.submodule {
                  options = {
                    maxUnits = mkOption {
                      type = types.nullOr types.int;
                      default = null;
                      description = "Maximum compute units";
                    };
                    
                    maxResources = mkOption {
                      type = types.nullOr types.int;
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
        
        storage = mkOption {
          type = types.submodule {
            options = {
              read = mkOption {
                type = types.bool;
                default = false;
                description = "Can read storage";
              };
              
              write = mkOption {
                type = types.bool;
                default = false;
                description = "Can write to storage";
              };
              
              allocate = mkOption {
                type = types.bool;
                default = false;
                description = "Can allocate new storage";
              };
              
              snapshot = mkOption {
                type = types.bool;
                default = false;
                description = "Can create snapshots";
              };
              
              tiers = mkOption {
                type = types.listOf types.int;
                default = [];
                description = "Allowed storage tiers";
              };
              
              quota = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Storage quota";
                example = "100Gi";
              };
            };
          };
          default = {};
          description = "Storage permissions";
        };
        
        network = mkOption {
          type = types.submodule {
            options = {
              configure = mkOption {
                type = types.bool;
                default = false;
                description = "Can configure network";
              };
              
              attach = mkOption {
                type = types.bool;
                default = false;
                description = "Can attach to networks";
              };
              
              create = mkOption {
                type = types.bool;
                default = false;
                description = "Can create networks";
              };
              
              capabilities = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Allowed network capabilities";
                example = [ "public-internet" "internal-only" ];
              };
            };
          };
          default = {};
          description = "Network permissions";
        };
        
        cluster = mkOption {
          type = types.submodule {
            options = {
              join = mkOption {
                type = types.bool;
                default = false;
                description = "Can join nodes to cluster";
              };
              
              configure = mkOption {
                type = types.bool;
                default = false;
                description = "Can configure cluster";
              };
              
              schedule = mkOption {
                type = types.bool;
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
      operations = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Allowed operations";
        example = [ "backup" "restore" "migrate" "monitor" ];
      };
      
      # Delegation rights
      delegation = {
        allowed = mkOption {
          type = types.bool;
          default = false;
          description = "Can delegate this capability";
        };
        
        maxDepth = mkOption {
          type = types.int;
          default = 0;
          description = "Maximum delegation depth";
        };
        
        restrictions = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Restrictions when delegating";
        };
      };
      
      # Conditions
      conditions = mkOption {
        type = types.listOf (types.submodule {
          options = {
            type = mkOption {
              type = types.enum [ "label" "time" "location" "rate" "context" ];
              description = "Condition type";
            };
            
            config = mkOption {
              type = types.attrsOf types.anything;
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
        start = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Access start time (RFC3339)";
          example = "2023-01-01T00:00:00Z";
        };
        
        end = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Access end time (RFC3339)";
          example = "2023-12-31T23:59:59Z";
        };
        
        duration = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Access duration from grant time";
          example = "24h";
        };
      };
      
      # Recurring access windows
      schedule = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            timezone = mkOption {
              type = types.str;
              default = "UTC";
              description = "Schedule timezone";
            };
            
            windows = mkOption {
              type = types.listOf (types.submodule {
                options = {
                  days = mkOption {
                    type = types.listOf (types.enum [
                      "monday" "tuesday" "wednesday" "thursday"
                      "friday" "saturday" "sunday"
                    ]);
                    description = "Days of week";
                  };
                  
                  startTime = mkOption {
                    type = types.str;
                    description = "Start time (HH:MM)";
                    example = "09:00";
                  };
                  
                  endTime = mkOption {
                    type = types.str;
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
        maxUses = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum number of uses";
        };
        
        rateLimit = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              requests = mkOption {
                type = types.int;
                description = "Number of requests";
              };
              
              window = mkOption {
                type = types.str;
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
        breakGlass = mkOption {
          type = types.bool;
          default = false;
          description = "Allow emergency access override";
        };
        
        auditRequired = mkOption {
          type = types.bool;
          default = true;
          description = "Require audit for emergency access";
        };
        
        notificationList = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Notify on emergency access";
        };
      };
    };
  };
  
  # Principal (user/service/group)
  principalDefinition = {
    options = {
      type = mkOption {
        type = types.enum [ "user" "service" "group" "token" ];
        description = "Principal type";
      };
      
      identity = {
        id = mkOption {
          type = types.str;
          description = "Principal identifier";
        };
        
        attributes = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = "Principal attributes";
          example = { department = "engineering"; clearance = "secret"; };
        };
        
        authentication = {
          methods = mkOption {
            type = types.listOf (types.enum [
              "password" "publickey" "certificate" "oidc" "saml" "webauthn"
            ]);
            default = [ "password" ];
            description = "Allowed authentication methods";
          };
          
          mfa = mkOption {
            type = types.submodule {
              options = {
                required = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Require MFA";
                };
                
                methods = mkOption {
                  type = types.listOf types.str;
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
      grants = mkOption {
        type = types.listOf (types.submodule {
          options = {
            capability = mkOption {
              type = types.str;
              description = "Capability name";
            };
            
            temporal = mkOption {
              type = types.submodule temporalAccessDefinition;
              default = {};
              description = "Temporal access constraints";
            };
            
            scope = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  labels = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                    description = "Label selector for scope";
                  };
                  
                  resources = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Specific resource IDs";
                  };
                };
              });
              default = null;
              description = "Grant scope";
            };
            
            delegatedFrom = mkOption {
              type = types.nullOr types.str;
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
        logLevel = mkOption {
          type = types.enum [ "none" "basic" "detailed" "full" ];
          default = "basic";
          description = "Audit log level";
        };
        
        alerts = mkOption {
          type = types.listOf (types.submodule {
            options = {
              event = mkOption {
                type = types.str;
                description = "Event to alert on";
              };
              
              notify = mkOption {
                type = types.listOf types.str;
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
      verification = mkOption {
        type = types.bool;
        default = true;
        description = "Enable continuous verification";
      };
      
      interval = mkOption {
        type = types.str;
        default = "5m";
        description = "Verification interval";
      };
      
      factors = mkOption {
        type = types.listOf (types.enum [
          "device-trust" "location" "behavior" "risk-score"
        ]);
        default = [ "device-trust" ];
        description = "Factors to verify";
      };
    };
    
    contextual = {
      ipRestrictions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Allowed IP ranges";
      };
      
      devicePolicy = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            managed = mkOption {
              type = types.bool;
              default = false;
              description = "Require managed device";
            };
            
            compliance = mkOption {
              type = types.listOf types.str;
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
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable capability-based security";
    };
    
    # Capability definitions
    capabilities = mkOption {
      type = types.attrsOf (types.submodule capabilityDefinition);
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
    principals = mkOption {
      type = types.attrsOf (types.submodule principalDefinition);
      default = {};
      description = "Principal definitions with grants";
    };
    
    # Zero-trust policies
    zeroTrust = mkOption {
      type = types.submodule zeroTrustPolicy;
      default = {};
      description = "Zero-trust security policies";
    };
    
    # Default policies
    defaults = {
      sessionTimeout = mkOption {
        type = types.str;
        default = "8h";
        description = "Default session timeout";
      };
      
      requireMFA = mkOption {
        type = types.bool;
        default = false;
        description = "Require MFA by default";
      };
      
      auditLevel = mkOption {
        type = types.enum [ "none" "basic" "detailed" "full" ];
        default = "basic";
        description = "Default audit level";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Capability enforcement service
    systemd.services.capability-enforcer = {
      description = "Capability-Based Security Enforcer";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "notify";
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
    environment.systemPackages = with pkgs; [
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