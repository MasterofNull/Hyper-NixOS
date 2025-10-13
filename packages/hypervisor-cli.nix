# Hyper-NixOS CLI Tool Package
{ pkgs }:

pkgs.writeScriptBin "hv" ''
  #!${pkgs.bash}/bin/bash
  #
  # Hyper-NixOS Master CLI
  # Version: 1.0.0
  #
  # Main entry point for all Hyper-NixOS operations
  #
  
  set -euo pipefail
  
  # Script configuration
  readonly VERSION="1.0.0"
  readonly SCRIPT_DIR="/etc/hypervisor/scripts"
  readonly DOCS_DIR="/etc/hypervisor/docs"
  readonly CONFIG_FILE="/etc/hypervisor/config.json"
  
  # Colors
  readonly BOLD='\033[1m'
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[0;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m'
  
  # Show version
  show_version() {
    echo "Hyper-NixOS CLI v$VERSION"
  }
  
  # Show main help
  show_help() {
    cat <<EOF
  $(show_version)
  
  USAGE: hv <command> [options] [arguments]
  
  COMMANDS:
    ${BOLD}VM Management${NC}
      vm          Manage virtual machines
      template    Manage VM templates
      snapshot    Manage VM snapshots
      console     Connect to VM console
      
    ${BOLD}System Management${NC}
      setup       Run initial setup wizard
      system      System configuration (requires sudo)
      network     Network management
      storage     Storage management
      
    ${BOLD}Security${NC}
      security    Security status and configuration
      monitor     Real-time threat monitoring
      threats     Threat detection and response
      forensics   Forensic analysis tools
      
    ${BOLD}Operations${NC}
      backup      Backup management
      restore     Restore operations
      migrate     VM migration tools
      
    ${BOLD}Monitoring${NC}
      status      System status overview
      metrics     Performance metrics
      logs        Log management
      alerts      Alert management
      
    ${BOLD}Help & Info${NC}
      help        Show help for commands
      tutorial    Interactive tutorials
      examples    Show usage examples
      docs        Browse documentation
      version     Show version info
  
  GLOBAL OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -q, --quiet     Suppress non-error output
    --json          Output in JSON format
  
  EXAMPLES:
    hv vm create my-vm --template debian-11
    hv security status
    hv monitor
    hv backup create my-vm
    
  For detailed help on any command:
    hv help <command>
    hv <command> --help
  
  EOF
  }
  
  # Command dispatcher
  dispatch_command() {
    local cmd="$1"
    shift
    
    case "$cmd" in
      # VM Management
      vm)
        exec "$SCRIPT_DIR/vm_manager.sh" "$@"
        ;;
      template)
        exec "$SCRIPT_DIR/template_manager.sh" "$@"
        ;;
      snapshot)
        exec "$SCRIPT_DIR/snapshot_manager.sh" "$@"
        ;;
      console)
        if [[ -n "$1" ]]; then
          exec virsh console "$1"
        else
          echo "Usage: hv console <vm-name>"
          exit 1
        fi
        ;;
        
      # System Management
      setup)
        exec "$SCRIPT_DIR/setup-wizard.sh" "$@"
        ;;
      system)
        exec "$SCRIPT_DIR/system_config.sh" "$@"
        ;;
      network)
        exec "$SCRIPT_DIR/network_manager.sh" "$@"
        ;;
      storage)
        exec "$SCRIPT_DIR/storage_manager.sh" "$@"
        ;;
        
      # Security
      security)
        case "$1" in
          monitor|"")
            exec "$SCRIPT_DIR/security-visualizer.sh" "$@"
            ;;
          status)
            exec "$SCRIPT_DIR/security-visualizer.sh" --matrix
            ;;
          report)
            shift
            exec "$SCRIPT_DIR/threat-report.sh" "$@"
            ;;
          setup)
            exec sudo "$SCRIPT_DIR/security_setup.sh" "$@"
            ;;
          *)
            exec "$SCRIPT_DIR/security_manager.sh" "$@"
            ;;
        esac
        ;;
      monitor)
        exec "$SCRIPT_DIR/threat-monitor.sh" "$@"
        ;;
      threats)
        exec "$SCRIPT_DIR/threat_manager.sh" "$@"
        ;;
      forensics)
        exec "$SCRIPT_DIR/forensics_tools.sh" "$@"
        ;;
        
      # Operations
      backup)
        exec "$SCRIPT_DIR/backup_manager.sh" "$@"
        ;;
      restore)
        exec "$SCRIPT_DIR/restore_manager.sh" "$@"
        ;;
      migrate)
        exec "$SCRIPT_DIR/migration_tools.sh" "$@"
        ;;
        
      # Monitoring
      status)
        show_system_status
        ;;
      metrics)
        exec "$SCRIPT_DIR/metrics_viewer.sh" "$@"
        ;;
      logs)
        exec "$SCRIPT_DIR/log_viewer.sh" "$@"
        ;;
      alerts)
        exec "$SCRIPT_DIR/alert_manager.sh" "$@"
        ;;
        
      # Help & Info
      help)
        if [[ -n "$1" ]]; then
          show_command_help "$1"
        else
          show_help
        fi
        ;;
      tutorial)
        exec "$SCRIPT_DIR/hv-tutorial" "$@"
        ;;
      examples)
        show_examples "$@"
        ;;
      docs)
        browse_docs "$@"
        ;;
      version|--version|-V)
        show_version
        ;;
        
      # Default
      "")
        show_help
        ;;
      *)
        echo -e "${RED}Error: Unknown command '$cmd'${NC}"
        echo "Run 'hv help' for usage information"
        exit 1
        ;;
    esac
  }
  
  # Show system status
  show_system_status() {
    echo -e "${BOLD}Hyper-NixOS System Status${NC}"
    echo "========================="
    echo
    
    # Core services
    echo -e "${BOLD}Core Services:${NC}"
    for service in libvirtd hypervisor-threat-detector sshd; do
      if systemctl is-active "$service" &>/dev/null; then
        echo -e "  $service: ${GREEN}●${NC} active"
      else
        echo -e "  $service: ${RED}●${NC} inactive"
      fi
    done
    echo
    
    # VMs
    echo -e "${BOLD}Virtual Machines:${NC}"
    local vm_count=$(virsh list --all --name 2>/dev/null | grep -v '^$' | wc -l)
    local running_vms=$(virsh list --name 2>/dev/null | grep -v '^$' | wc -l)
    echo "  Total VMs: $vm_count"
    echo "  Running: $running_vms"
    echo
    
    # Security
    echo -e "${BOLD}Security Status:${NC}"
    if systemctl is-active hypervisor-threat-detector &>/dev/null; then
      echo -e "  Threat Detection: ${GREEN}Active${NC}"
    else
      echo -e "  Threat Detection: ${YELLOW}Inactive${NC}"
    fi
    
    # Get threat count from last hour
    local recent_threats=0
    if [[ -f /var/lib/hypervisor/threats/threat.db ]]; then
      recent_threats=$(sqlite3 /var/lib/hypervisor/threats/threat.db \
        "SELECT COUNT(*) FROM threats WHERE timestamp > $(date -d '1 hour ago' +%s)" 2>/dev/null || echo "0")
    fi
    echo "  Recent Threats (1h): $recent_threats"
    echo
    
    # Resources
    echo -e "${BOLD}System Resources:${NC}"
    echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
    echo "  Storage: $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}')"
  }
  
  # Show command help
  show_command_help() {
    local cmd="$1"
    
    case "$cmd" in
      vm)
        echo "VM Management Commands:"
        echo "  create      Create a new VM"
        echo "  start       Start a VM"
        echo "  stop        Stop a VM"
        echo "  delete      Delete a VM"
        echo "  list        List all VMs"
        echo "  info        Show VM information"
        ;;
      security)
        echo "Security Commands:"
        echo "  status      Show security status"
        echo "  monitor     Real-time monitoring"
        echo "  report      Generate security report"
        echo "  setup       Configure security (sudo)"
        ;;
      *)
        echo "No detailed help available for '$cmd'"
        echo "Try: hv $cmd --help"
        ;;
    esac
  }
  
  # Show examples
  show_examples() {
    local topic="$1"
    
    if [[ -z "$topic" ]]; then
      echo "Available example topics:"
      echo "  vm-management"
      echo "  security"
      echo "  networking"
      echo "  backup"
      echo
      echo "Usage: hv examples <topic>"
      return
    fi
    
    case "$topic" in
      vm-management)
        cat <<EOF
  VM Management Examples:
  
  # Create a new VM
  hv vm create webserver --template debian-11 --memory 4096 --vcpus 2
  
  # Start/stop VMs
  hv vm start webserver
  hv vm stop webserver
  
  # Clone a VM
  hv vm clone webserver webserver-backup
  
  # List VMs with details
  hv vm list --details
  
  # Connect to VM console
  hv console webserver
  EOF
        ;;
      security)
        cat <<EOF
  Security Examples:
  
  # Check security status
  hv security status
  
  # Monitor threats in real-time
  hv monitor
  
  # Generate security report
  hv security report --period week --format pdf
  
  # Respond to threat
  hv threats respond --isolate infected-vm
  
  # Create forensic snapshot
  hv forensics snapshot suspicious-vm
  EOF
        ;;
      *)
        echo "No examples available for '$topic'"
        ;;
    esac
  }
  
  # Browse documentation
  browse_docs() {
    local topic="$1"
    
    if [[ -z "$topic" ]]; then
      echo "Documentation available at: $DOCS_DIR"
      echo
      echo "Topics:"
      ls -1 "$DOCS_DIR" | grep -E '\.md$' | sed 's/\.md$//' | sed 's/^/  /'
      echo
      echo "Usage: hv docs <topic>"
      echo "   or: less $DOCS_DIR/README.md"
    else
      local doc_file="$DOCS_DIR/${topic}.md"
      if [[ -f "$doc_file" ]]; then
        ${PAGER:-less} "$doc_file"
      else
        echo "Documentation not found for '$topic'"
        echo "Try: hv docs"
      fi
    fi
  }
  
  # Main execution
  main() {
    # Handle global options
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help)
          show_help
          exit 0
          ;;
        -v|--verbose)
          export VERBOSE=true
          shift
          ;;
        -q|--quiet)
          export QUIET=true
          shift
          ;;
        --json)
          export OUTPUT_FORMAT=json
          shift
          ;;
        -V|--version)
          show_version
          exit 0
          ;;
        -*)
          echo -e "${RED}Error: Unknown option '$1'${NC}"
          show_help
          exit 1
          ;;
        *)
          # First non-option is the command
          break
          ;;
      esac
    done
    
    # Dispatch to command handler
    dispatch_command "$@"
  }
  
  # Run main function
  main "$@"
''