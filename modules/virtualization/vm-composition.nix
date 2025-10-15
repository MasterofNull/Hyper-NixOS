# Composition-Based VM Building Blocks
# Implements a modular VM construction system using composable components
{ config, lib, pkgs, ... }:

# Removed: with lib; - Using explicit lib. prefix for clarity
let
  cfg = config.hypervisor.composition;
  
  # Component definition - the building blocks
  componentDefinition = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Component name";
      };
      
      version = lib.mkOption {
        type = lib.types.str;
        default = "1.0.0";
        description = "Component version";
      };
      
      type = lib.mkOption {
        type = lib.types.enum [ 
          "base"        # Base operating system
          "runtime"     # Language runtime (Node.js, Python, etc.)
          "framework"   # Application framework
          "service"     # Service component (database, cache, etc.)
          "security"    # Security hardening
          "monitoring"  # Monitoring and observability
          "network"     # Network configuration
          "storage"     # Storage configuration
        ];
        description = "Component type";
      };
      
      # Component properties
      properties = {
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Component description";
        };
        
        maintainer = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Component maintainer";
        };
        
        tags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Component tags";
        };
        
        compatibility = {
          architectures = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "x86_64" ];
            description = "Compatible architectures";
          };
          
          requires = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Required components";
          };
          
          conflicts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Conflicting components";
          };
          
          provides = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Capabilities provided";
          };
        };
      };
      
      # Component configuration
      configuration = {
        # Resource modifications
        resources = lib.mkOption {
          type = lib.types.submodule {
            options = {
              cpu = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    add = lib.mkOption { type = lib.types.int; default = 0; };
                    multiply = lib.mkOption { type = lib.types.float; default = 1.0; };
                    minimum = lib.mkOption { type = lib.types.int; default = 0; };
                  };
                });
                default = null;
                description = "CPU resource modifications";
              };
              
              memory = lib.mkOption {
                type = lib.types.nullOr (lib.types.submodule {
                  options = {
                    add = lib.mkOption { type = lib.types.str; default = "0"; };
                    multiply = lib.mkOption { type = lib.types.float; default = 1.0; };
                    minimum = lib.mkOption { type = lib.types.str; default = "0"; };
                  };
                });
                default = null;
                description = "Memory resource modifications";
              };
            };
          };
          default = {};
          description = "Resource modifications";
        };
        
        # Environment variables
        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Environment variables to set";
        };
        
        # Ports to expose
        ports = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              internal = lib.mkOption {
                type = lib.types.int;
                description = "Internal port";
              };
              
              external = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "External port (null for dynamic)";
              };
              
              protocol = lib.mkOption {
                type = lib.types.enum [ "tcp" "udp" "sctp" ];
                default = "tcp";
                description = "Protocol";
              };
            };
          });
          default = [];
          description = "Ports to expose";
        };
        
        # Volumes to mount
        volumes = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Volume name";
              };
              
              path = lib.mkOption {
                type = lib.types.str;
                description = "Mount path";
              };
              
              type = lib.mkOption {
                type = lib.types.enum [ "persistent" "ephemeral" "config" "secret" ];
                default = "persistent";
                description = "Volume type";
              };
              
              size = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Volume size";
              };
            };
          });
          default = [];
          description = "Volumes to mount";
        };
        
        # Startup hooks
        hooks = {
          preInstall = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Pre-installation hook";
          };
          
          postInstall = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Post-installation hook";
          };
          
          configure = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Configuration hook";
          };
          
          validate = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Validation hook";
          };
        };
        
        # Files to inject
        files = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              content = lib.mkOption {
                type = lib.types.str;
                description = "File content";
              };
              
              mode = lib.mkOption {
                type = lib.types.str;
                default = "0644";
                description = "File mode";
              };
              
              owner = lib.mkOption {
                type = lib.types.str;
                default = "root";
                description = "File owner";
              };
              
              group = lib.mkOption {
                type = lib.types.str;
                default = "root";
                description = "File group";
              };
            };
          });
          default = {};
          description = "Files to create";
        };
        
        # Package management
        packages = {
          install = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Packages to install";
          };
          
          remove = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Packages to remove";
          };
          
          repositories = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "Repository URL";
                };
                
                key = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Repository key";
                };
              };
            });
            default = [];
            description = "Package repositories to add";
          };
        };
      };
      
      # Component interface
      interface = {
        inputs = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.str;
                description = "Input type";
                example = "string";
              };
              
              required = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether input is required";
              };
              
              default = lib.mkOption {
                type = lib.types.nullOr lib.types.anything;
                default = null;
                description = "Default value";
              };
              
              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Input description";
              };
            };
          });
          default = {};
          description = "Component inputs";
        };
        
        outputs = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              type = lib.mkOption {
                type = lib.types.str;
                description = "Output type";
              };
              
              value = lib.mkOption {
                type = lib.types.str;
                description = "Output value expression";
              };
              
              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Output description";
              };
            };
          });
          default = {};
          description = "Component outputs";
        };
        
        events = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Event name";
              };
              
              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Event description";
              };
            };
          });
          default = [];
          description = "Events emitted by component";
        };
      };
    };
  };
  
  # Blueprint definition - compositions of components
  blueprintDefinition = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Blueprint name";
      };
      
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Blueprint description";
      };
      
      # Component composition
      components = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            component = lib.mkOption {
              type = lib.types.str;
              description = "Component name";
            };
            
            alias = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Component alias";
            };
            
            inputs = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = {};
              description = "Input values";
            };
            
            condition = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Condition for inclusion";
            };
          };
        });
        default = [];
        description = "Components to include";
      };
      
      # Blueprint parameters
      parameters = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            type = lib.mkOption {
              type = lib.types.str;
              default = "string";
              description = "Parameter type";
            };
            
            default = lib.mkOption {
              type = lib.types.nullOr lib.types.anything;
              default = null;
              description = "Default value";
            };
            
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Parameter description";
            };
            
            validation = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Validation expression";
            };
          };
        });
        default = {};
        description = "Blueprint parameters";
      };
      
      # Connections between components
      connections = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            from = lib.mkOption {
              type = lib.types.str;
              description = "Source component.output";
            };
            
            to = lib.mkOption {
              type = lib.types.str;
              description = "Target component.input";
            };
            
            transform = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Value transformation";
            };
          };
        });
        default = [];
        description = "Connections between components";
      };
      
      # Layout hints
      layout = {
        layers = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Layer name";
              };
              
              components = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
                description = "Components in this layer";
              };
              
              order = lib.mkOption {
                type = lib.types.int;
                default = 0;
                description = "Layer order";
              };
            };
          });
          default = [];
          description = "Component layers";
        };
        
        constraints = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
          description = "Layout constraints";
        };
      };
      
      # Validation rules
      validation = {
        rules = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Rule name";
              };
              
              expression = lib.mkOption {
                type = lib.types.str;
                description = "Validation expression";
              };
              
              message = lib.mkOption {
                type = lib.types.str;
                description = "Error message";
              };
            };
          });
          default = [];
          description = "Validation rules";
        };
      };
    };
  };
  
  # Instance definition - instantiated blueprints
  instanceDefinition = {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Instance name";
      };
      
      blueprint = lib.mkOption {
        type = lib.types.str;
        description = "Blueprint to instantiate";
      };
      
      parameters = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Parameter values";
      };
      
      overrides = {
        components = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              inputs = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {};
                description = "Input overrides";
              };
              
              configuration = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {};
                description = "Configuration overrides";
              };
            };
          });
          default = {};
          description = "Component overrides";
        };
        
        resources = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
          description = "Resource overrides";
        };
      };
      
      placement = {
        node = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Target node";
        };
        
        tags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Placement tags";
        };
      };
    };
  };
  
in
{
  options.hypervisor.composition = {
    # Component library
    components = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule componentDefinition);
      default = {};
      description = "Available components";
    };
    
    # Blueprint library
    blueprints = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule blueprintDefinition);
      default = {};
      description = "Available blueprints";
    };
    
    # Instances
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceDefinition);
      default = {};
      description = "Blueprint instances";
    };
    
    # Global settings
    settings = {
      componentPath = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ "/var/lib/hypervisor/components" ];
        description = "Component search paths";
      };
      
      validation = {
        strict = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable strict validation";
        };
        
        timeout = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Validation timeout in seconds";
        };
      };
      
      caching = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable composition caching";
        };
        
        ttl = lib.mkOption {
          type = lib.types.int;
          default = 3600;
          description = "Cache TTL in seconds";
        };
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Generate composed configurations
    system.activationScripts.generateCompositions = ''
      echo "Generating VM compositions..."
      mkdir -p /var/lib/hypervisor/compositions
      
      # Process each instance
      ${concatStringsSep "\n" (mapAttrsToList (name: instance: let
        blueprint = cfg.blueprints.${instance.blueprint} or null;
      in ''
        echo "Processing instance: ${name}"
        
        # Generate instance configuration
        cat > /var/lib/hypervisor/compositions/${name}.json << EOF
        {
          "name": "${name}",
          "blueprint": "${instance.blueprint}",
          "parameters": ${builtins.toJSON instance.parameters},
          "components": ${builtins.toJSON (blueprint.components or [])}
        }
        EOF
      '') cfg.instances)}
    '';
    
    # Component manager tool
    environment.systemPackages = [
      (writeScriptBin "hv-compose" ''
        #!${pkgs.bash}/bin/bash
        # VM Composition Manager
        
        case "$1" in
          components)
            echo "Available Components:"
            ${concatStringsSep "\n" (mapAttrsToList (name: comp: ''
              echo "  ${name} (${comp.type}):"
              echo "    Version: ${comp.version}"
              echo "    ${comp.properties.description}"
              ${optionalString (comp.properties.compatibility.requires != []) 
                "echo '    Requires: ${concatStringsSep ", " comp.properties.compatibility.requires}'"}
              ${optionalString (comp.properties.compatibility.provides != []) 
                "echo '    Provides: ${concatStringsSep ", " comp.properties.compatibility.provides}'"}
            '') cfg.components)}
            ;;
            
          blueprints)
            echo "Available Blueprints:"
            ${concatStringsSep "\n" (mapAttrsToList (name: bp: ''
              echo "  ${name}:"
              echo "    ${bp.description}"
              echo "    Components: ${toString (length bp.components)}"
              echo "    Parameters: ${concatStringsSep ", " (attrNames bp.parameters)}"
            '') cfg.blueprints)}
            ;;
            
          instances)
            echo "Active Instances:"
            ${concatStringsSep "\n" (mapAttrsToList (name: inst: ''
              echo "  ${name}:"
              echo "    Blueprint: ${inst.blueprint}"
              echo "    Parameters: ${builtins.toJSON inst.parameters}"
            '') cfg.instances)}
            ;;
            
          validate)
            if [ -z "$2" ]; then
              echo "Usage: hv-compose validate <blueprint>"
              exit 1
            fi
            echo "Validating blueprint: $2"
            # Validation logic here
            ;;
            
          instantiate)
            if [ -z "$3" ]; then
              echo "Usage: hv-compose instantiate <blueprint> <name>"
              exit 1
            fi
            echo "Creating instance $3 from blueprint $2..."
            ;;
            
          graph)
            if [ -z "$2" ]; then
              echo "Usage: hv-compose graph <blueprint>"
              exit 1
            fi
            echo "Component graph for $2:"
            # Generate visual graph
            ;;
            
          *)
            echo "Usage: hv-compose {components|blueprints|instances|validate|instantiate|graph}"
            exit 1
            ;;
        esac
      '')
    ];
    
    # Create component directories
    systemd.tmpfiles.rules = [
      "d /var/lib/hypervisor/components 0755 root root -"
      "d /var/lib/hypervisor/blueprints 0755 root root -"
      "d /var/lib/hypervisor/compositions 0755 root root -"
      "d /var/cache/hypervisor/compositions 0755 root root -"
    ];
  };
}