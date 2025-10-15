# Composition-Based VM Building Blocks
# Implements a modular VM construction system using composable components
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.hypervisor.composition;
  
  # Component definition - the building blocks
  componentDefinition = {
    options = {
      name = mkOption {
        type = types.str;
        description = "Component name";
      };
      
      version = mkOption {
        type = types.str;
        default = "1.0.0";
        description = "Component version";
      };
      
      type = mkOption {
        type = types.enum [ 
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
        description = mkOption {
          type = types.str;
          default = "";
          description = "Component description";
        };
        
        maintainer = mkOption {
          type = types.str;
          default = "";
          description = "Component maintainer";
        };
        
        tags = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Component tags";
        };
        
        compatibility = {
          architectures = mkOption {
            type = types.listOf types.str;
            default = [ "x86_64" ];
            description = "Compatible architectures";
          };
          
          requires = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Required components";
          };
          
          conflicts = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Conflicting components";
          };
          
          provides = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Capabilities provided";
          };
        };
      };
      
      # Component configuration
      configuration = {
        # Resource modifications
        resources = mkOption {
          type = types.submodule {
            options = {
              cpu = mkOption {
                type = types.nullOr (types.submodule {
                  options = {
                    add = mkOption { type = types.int; default = 0; };
                    multiply = mkOption { type = types.float; default = 1.0; };
                    minimum = mkOption { type = types.int; default = 0; };
                  };
                });
                default = null;
                description = "CPU resource modifications";
              };
              
              memory = mkOption {
                type = types.nullOr (types.submodule {
                  options = {
                    add = mkOption { type = types.str; default = "0"; };
                    multiply = mkOption { type = types.float; default = 1.0; };
                    minimum = mkOption { type = types.str; default = "0"; };
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
        environment = mkOption {
          type = types.attrsOf types.str;
          default = {};
          description = "Environment variables to set";
        };
        
        # Ports to expose
        ports = mkOption {
          type = types.listOf (types.submodule {
            options = {
              internal = mkOption {
                type = types.int;
                description = "Internal port";
              };
              
              external = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "External port (null for dynamic)";
              };
              
              protocol = mkOption {
                type = types.enum [ "tcp" "udp" "sctp" ];
                default = "tcp";
                description = "Protocol";
              };
            };
          });
          default = [];
          description = "Ports to expose";
        };
        
        # Volumes to mount
        volumes = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Volume name";
              };
              
              path = mkOption {
                type = types.str;
                description = "Mount path";
              };
              
              type = mkOption {
                type = types.enum [ "persistent" "ephemeral" "config" "secret" ];
                default = "persistent";
                description = "Volume type";
              };
              
              size = mkOption {
                type = types.nullOr types.str;
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
          preInstall = mkOption {
            type = types.lines;
            default = "";
            description = "Pre-installation hook";
          };
          
          postInstall = mkOption {
            type = types.lines;
            default = "";
            description = "Post-installation hook";
          };
          
          configure = mkOption {
            type = types.lines;
            default = "";
            description = "Configuration hook";
          };
          
          validate = mkOption {
            type = types.lines;
            default = "";
            description = "Validation hook";
          };
        };
        
        # Files to inject
        files = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              content = mkOption {
                type = types.str;
                description = "File content";
              };
              
              mode = mkOption {
                type = types.str;
                default = "0644";
                description = "File mode";
              };
              
              owner = mkOption {
                type = types.str;
                default = "root";
                description = "File owner";
              };
              
              group = mkOption {
                type = types.str;
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
          install = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Packages to install";
          };
          
          remove = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Packages to remove";
          };
          
          repositories = mkOption {
            type = types.listOf (types.submodule {
              options = {
                url = mkOption {
                  type = types.str;
                  description = "Repository URL";
                };
                
                key = mkOption {
                  type = types.nullOr types.str;
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
        inputs = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              type = mkOption {
                type = types.str;
                description = "Input type";
                example = "string";
              };
              
              required = mkOption {
                type = types.bool;
                default = false;
                description = "Whether input is required";
              };
              
              default = mkOption {
                type = types.nullOr types.anything;
                default = null;
                description = "Default value";
              };
              
              description = mkOption {
                type = types.str;
                default = "";
                description = "Input description";
              };
            };
          });
          default = {};
          description = "Component inputs";
        };
        
        outputs = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              type = mkOption {
                type = types.str;
                description = "Output type";
              };
              
              value = mkOption {
                type = types.str;
                description = "Output value expression";
              };
              
              description = mkOption {
                type = types.str;
                default = "";
                description = "Output description";
              };
            };
          });
          default = {};
          description = "Component outputs";
        };
        
        events = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Event name";
              };
              
              description = mkOption {
                type = types.str;
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
      name = mkOption {
        type = types.str;
        description = "Blueprint name";
      };
      
      description = mkOption {
        type = types.str;
        default = "";
        description = "Blueprint description";
      };
      
      # Component composition
      components = mkOption {
        type = types.listOf (types.submodule {
          options = {
            component = mkOption {
              type = types.str;
              description = "Component name";
            };
            
            alias = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Component alias";
            };
            
            inputs = mkOption {
              type = types.attrsOf types.anything;
              default = {};
              description = "Input values";
            };
            
            condition = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Condition for inclusion";
            };
          };
        });
        default = [];
        description = "Components to include";
      };
      
      # Blueprint parameters
      parameters = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            type = mkOption {
              type = types.str;
              default = "string";
              description = "Parameter type";
            };
            
            default = mkOption {
              type = types.nullOr types.anything;
              default = null;
              description = "Default value";
            };
            
            description = mkOption {
              type = types.str;
              default = "";
              description = "Parameter description";
            };
            
            validation = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Validation expression";
            };
          };
        });
        default = {};
        description = "Blueprint parameters";
      };
      
      # Connections between components
      connections = mkOption {
        type = types.listOf (types.submodule {
          options = {
            from = mkOption {
              type = types.str;
              description = "Source component.output";
            };
            
            to = mkOption {
              type = types.str;
              description = "Target component.input";
            };
            
            transform = mkOption {
              type = types.nullOr types.str;
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
        layers = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Layer name";
              };
              
              components = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Components in this layer";
              };
              
              order = mkOption {
                type = types.int;
                default = 0;
                description = "Layer order";
              };
            };
          });
          default = [];
          description = "Component layers";
        };
        
        constraints = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = "Layout constraints";
        };
      };
      
      # Validation rules
      validation = {
        rules = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Rule name";
              };
              
              expression = mkOption {
                type = types.str;
                description = "Validation expression";
              };
              
              message = mkOption {
                type = types.str;
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
      name = mkOption {
        type = types.str;
        description = "Instance name";
      };
      
      blueprint = mkOption {
        type = types.str;
        description = "Blueprint to instantiate";
      };
      
      parameters = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Parameter values";
      };
      
      overrides = {
        components = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              inputs = mkOption {
                type = types.attrsOf types.anything;
                default = {};
                description = "Input overrides";
              };
              
              configuration = mkOption {
                type = types.attrsOf types.anything;
                default = {};
                description = "Configuration overrides";
              };
            };
          });
          default = {};
          description = "Component overrides";
        };
        
        resources = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = "Resource overrides";
        };
      };
      
      placement = {
        node = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Target node";
        };
        
        tags = mkOption {
          type = types.listOf types.str;
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
    components = mkOption {
      type = types.attrsOf (types.submodule componentDefinition);
      default = {};
      description = "Available components";
    };
    
    # Blueprint library
    blueprints = mkOption {
      type = types.attrsOf (types.submodule blueprintDefinition);
      default = {};
      description = "Available blueprints";
    };
    
    # Instances
    instances = mkOption {
      type = types.attrsOf (types.submodule instanceDefinition);
      default = {};
      description = "Blueprint instances";
    };
    
    # Global settings
    settings = {
      componentPath = mkOption {
        type = types.listOf types.path;
        default = [ "/var/lib/hypervisor/components" ];
        description = "Component search paths";
      };
      
      validation = {
        strict = mkOption {
          type = types.bool;
          default = true;
          description = "Enable strict validation";
        };
        
        timeout = mkOption {
          type = types.int;
          default = 30;
          description = "Validation timeout in seconds";
        };
      };
      
      caching = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable composition caching";
        };
        
        ttl = mkOption {
          type = types.int;
          default = 3600;
          description = "Cache TTL in seconds";
        };
      };
    };
  };
  
  config = {
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
    environment.systemPackages = with pkgs; [
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