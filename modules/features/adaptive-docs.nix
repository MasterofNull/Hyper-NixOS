# Adaptive Documentation System
# Provides configurable verbosity levels and context-aware help

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.documentation;
  
  # Documentation profiles
  docProfiles = {
    beginner = {
      verbosity = "high";
      examples = "comprehensive";
      hints = "always";
      tutorials = true;
      assumptions = "none";
      style = "conversational";
    };
    
    intermediate = {
      verbosity = "medium";
      examples = "relevant";
      hints = "on-error";
      tutorials = false;
      assumptions = "basic-knowledge";
      style = "professional";
    };
    
    expert = {
      verbosity = "low";
      examples = "minimal";
      hints = "never";
      tutorials = false;
      assumptions = "full-knowledge";
      style = "technical";
    };
    
    custom = {
      # User-defined settings
    };
  };
  
  # Generate documentation with appropriate verbosity
  generateDoc = verbosity: topic: content:
    if verbosity == "high" then ''
      # ${topic}
      
      ## Overview
      ${content.overview}
      
      ## Detailed Explanation
      ${content.detailed}
      
      ## Step-by-Step Guide
      ${content.steps}
      
      ## Examples
      ${content.examples}
      
      ## Common Issues
      ${content.troubleshooting}
      
      ## Tips & Best Practices
      ${content.tips}
      
      ## Related Topics
      ${content.related}
    ''
    else if verbosity == "medium" then ''
      # ${topic}
      
      ${content.overview}
      
      ## Usage
      ${content.usage}
      
      ## Examples
      ${content.examples}
      
      ## Troubleshooting
      ${content.troubleshooting}
    ''
    else ''
      # ${topic}
      ${content.overview}
      ${content.usage}
    '';
  
  # Context-aware help system
  helpSystem = pkgs.writeScriptBin "hv-help" ''
    #!${pkgs.bash}/bin/bash
    
    # Load user's documentation preferences
    source /etc/hypervisor/doc-preferences.conf
    
    TOPIC="$1"
    CONTEXT="$2"
    
    # Determine verbosity based on user experience
    if [[ -f ~/.hypervisor/experience-level ]]; then
      EXPERIENCE=$(cat ~/.hypervisor/experience-level)
    else
      EXPERIENCE="beginner"
    fi
    
    case "$TOPIC" in
      vm-start)
        if [[ "$VERBOSITY" == "high" ]]; then
          cat <<'EOF'
    ═══════════════════════════════════════════════════════════════
                         Starting a Virtual Machine
    ═══════════════════════════════════════════════════════════════
    
    WHAT THIS DOES:
    The vm-start command powers on a virtual machine, making it 
    available for use. Think of it like pressing the power button
    on a physical computer.
    
    BASIC USAGE:
      vm-start <vm-name>
    
    STEP-BY-STEP:
    1. First, check if your VM exists:
       $ virsh list --all
       
    2. If you see your VM in the list, start it:
       $ vm-start my-vm
       
    3. Verify it's running:
       $ virsh list
    
    EXAMPLES:
      # Start a VM named 'webserver'
      $ vm-start webserver
      
      # Start a VM and immediately connect to console
      $ vm-start webserver --console
      
      # Start multiple VMs
      $ for vm in web db cache; do vm-start $vm; done
    
    COMMON ISSUES:
    
    1. "Permission denied"
       → You need to be in the libvirtd group
       → Fix: sudo usermod -aG libvirtd $USER (then logout/login)
    
    2. "VM is already running"
       → The VM is already started
       → Check with: virsh list
    
    3. "Failed to start VM"
       → Check VM configuration: virsh dumpxml <vm-name>
       → Check logs: journalctl -u libvirtd
    
    TIPS:
    • Use tab completion: vm-start <TAB> shows available VMs
    • Create aliases for frequently used VMs
    • Use 'virsh autostart <vm>' to start VMs at boot
    
    NEXT STEPS:
    • Connect to VM: virsh console <vm-name>
    • View VM screen: virt-viewer <vm-name>
    • Check VM info: virsh dominfo <vm-name>
    
    Need more help? Try:
    • hv-help vm-management
    • hv-help troubleshooting
    • Run the interactive tutorial: hv-tutorial vm-basics
    EOF
        elif [[ "$VERBOSITY" == "medium" ]]; then
          cat <<'EOF'
    VM Start - Start a virtual machine
    
    Usage: vm-start <vm-name> [options]
    
    Options:
      --console    Connect to console after starting
      --wait       Wait for VM to fully boot
    
    Examples:
      vm-start webserver
      vm-start database --wait
    
    Troubleshooting:
      - Permission denied: Add user to libvirtd group
      - VM already running: Check with 'virsh list'
      - Start failed: Check 'virsh dominfo <vm>' and logs
    EOF
        else
          echo "Usage: vm-start <vm-name> [--console] [--wait]"
        fi
        ;;
        
      quick-start)
        if [[ "$EXPERIENCE" == "beginner" ]]; then
          "${pkgs.bash}/bin/bash" "${helpSystem}/bin/hv-interactive-tutorial" quick-start
        else
          cat /etc/hypervisor/docs/quick-start-guide.md
        fi
        ;;
        
      *)
        echo "Available help topics:"
        echo "  vm-start, vm-stop, vm-create, vm-management"
        echo "  networking, storage, security, troubleshooting"
        echo "  quick-start, tutorials, best-practices"
        ;;
    esac
  '';
  
  # Interactive tutorial system
  interactiveTutorial = pkgs.writeScriptBin "hv-interactive-tutorial" ''
    #!${pkgs.bash}/bin/bash
    
    source ${pkgs.dialog}/bin/dialog
    
    TUTORIAL="$1"
    
    case "$TUTORIAL" in
      quick-start)
        dialog --title "Welcome to Hyper-NixOS!" \
               --msgbox "This tutorial will guide you through basic VM operations.\n\nPress OK to continue." 10 50
        
        dialog --title "Step 1: Check Your Groups" \
               --msgbox "First, let's make sure you have the right permissions.\n\nRun: groups\n\nYou should see 'libvirtd' in the list." 10 50
        
        # Continue with interactive steps...
        ;;
    esac
  '';

in {
  options.hypervisor.documentation = {
    enable = mkEnableOption "adaptive documentation system";
    
    profile = mkOption {
      type = types.enum [ "beginner" "intermediate" "expert" "custom" ];
      default = "intermediate";
      description = "Documentation profile to use";
    };
    
    verbosity = mkOption {
      type = types.enum [ "minimal" "low" "medium" "high" ];
      default = "medium";
      description = "Documentation verbosity level";
    };
    
    showExamples = mkOption {
      type = types.enum [ "always" "relevant" "minimal" "never" ];
      default = "relevant";
      description = "When to show examples in documentation";
    };
    
    enableHints = mkOption {
      type = types.bool;
      default = true;
      description = "Show helpful hints and tips";
    };
    
    enableTutorials = mkOption {
      type = types.bool;
      default = true;
      description = "Enable interactive tutorials";
    };
    
    contextAware = mkOption {
      type = types.bool;
      default = true;
      description = "Adjust help based on user's experience";
    };
    
    quickActions = mkOption {
      type = types.bool;
      default = true;
      description = "Show quick action buttons in terminal";
    };
  };
  
  config = mkIf cfg.enable {
    # Install documentation preferences
    environment.etc."hypervisor/doc-preferences.conf".text = ''
      # Documentation preferences
      VERBOSITY="${cfg.verbosity}"
      SHOW_EXAMPLES="${cfg.showExamples}"
      ENABLE_HINTS="${toString cfg.enableHints}"
      ENABLE_TUTORIALS="${toString cfg.enableTutorials}"
      CONTEXT_AWARE="${toString cfg.contextAware}"
    '';
    
    # Install help system
    environment.systemPackages = [
      helpSystem
      interactiveTutorial
      
      # Quick reference card generator
      (pkgs.writeScriptBin "hv-cheatsheet" ''
        #!${pkgs.bash}/bin/bash
        
        if [[ "${cfg.verbosity}" == "minimal" ]]; then
          cat /etc/hypervisor/docs/cheatsheet-minimal.txt
        else
          cat /etc/hypervisor/docs/cheatsheet-full.txt
        fi
      '')
      
      # Context-sensitive prompt
      (pkgs.writeScriptBin "hv-prompt" ''
        #!${pkgs.bash}/bin/bash
        
        # Show context-sensitive hints in prompt
        if [[ "${cfg.enableHints}" == "true" ]]; then
          LAST_CMD=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
          
          case "$LAST_CMD" in
            *"vm-start"*)
              echo "💡 Hint: Use 'virsh console <vm>' to connect"
              ;;
            *"permission denied"*)
              echo "💡 Hint: Check groups with 'groups'. Need libvirtd?"
              ;;
          esac
        fi
      '')
    ];
    
    # Generate documentation in multiple formats
    system.activationScripts.generateDocs = ''
      mkdir -p /etc/hypervisor/docs/{beginner,intermediate,expert}
      
      # Generate docs for each verbosity level
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (level: settings: ''
        cat > /etc/hypervisor/docs/${level}/vm-quick-start.md <<'EOF'
        ${if settings.verbosity == "high" then ''
          # Virtual Machine Quick Start Guide
          
          Welcome to Hyper-NixOS! This guide will help you get started with
          virtual machines. Don't worry if you're new to virtualization -
          we'll explain everything step by step.
          
          ## What are Virtual Machines?
          
          Virtual machines (VMs) are like computers running inside your
          computer. Each VM is isolated and secure, perfect for:
          - Testing software safely
          - Running different operating systems
          - Isolating applications
          - Learning and experimentation
          
          ## Before You Begin
          
          Let's make sure everything is set up correctly:
          
          1. **Check your user groups**
             Open a terminal and type:
             ```bash
             groups
             ```
             
             You should see 'libvirtd' in the list. If not, see the
             troubleshooting section below.
          
          2. **Verify the system is ready**
             ```bash
             systemctl status libvirtd
             ```
             
             Should show "active (running)"
          
          ## Your First VM
          
          Let's create and start your first VM:
          
          ### Step 1: List available templates
          ```bash
          hv template list
          ```
          
          You'll see templates like:
          - debian-11 (Recommended for beginners)
          - ubuntu-22.04
          - fedora-38
          
          ### Step 2: Create a VM from template
          ```bash
          hv vm create my-first-vm --template debian-11
          ```
          
          This creates a new VM named "my-first-vm" using Debian 11.
          
          ### Step 3: Start your VM
          ```bash
          vm-start my-first-vm
          ```
          
          ### Step 4: Connect to your VM
          ```bash
          virsh console my-first-vm
          ```
          
          Press Enter to see the login prompt.
          Default credentials are usually:
          - Username: user
          - Password: password
          
          To exit the console, press: Ctrl+]
          
          ## Common Tasks
          
          ### List all VMs
          ```bash
          virsh list --all
          ```
          
          ### Stop a VM
          ```bash
          vm-stop my-first-vm
          ```
          
          ### Delete a VM
          ```bash
          virsh destroy my-first-vm  # Force stop
          virsh undefine my-first-vm # Remove
          ```
          
          ## Troubleshooting
          
          ### "Permission denied" errors
          You're not in the libvirtd group. Fix:
          ```bash
          sudo usermod -aG libvirtd $USER
          ```
          Then logout and login again.
          
          ### Can't connect to VM console
          The VM might not be fully booted. Wait 30 seconds and try again.
          
          ### VM won't start
          Check for errors:
          ```bash
          journalctl -xe | grep libvirt
          ```
          
          ## Tips for Success
          
          1. **Start simple**: Use templates for your first VMs
          2. **Take snapshots**: Before making changes
          3. **Read error messages**: They usually tell you what's wrong
          4. **Ask for help**: The community is friendly!
          
          ## Next Steps
          
          Ready for more? Try these tutorials:
          - `hv-tutorial networking` - Connect VMs to networks
          - `hv-tutorial storage` - Add disks to VMs  
          - `hv-tutorial snapshots` - Backup and restore VMs
          
          ## Getting Help
          
          - Quick help: `hv-help <topic>`
          - Interactive tutorial: `hv-tutorial`
          - Full documentation: `hv-docs`
          - Community forum: https://hyper-nixos.org/forum
        '' else if settings.verbosity == "medium" then ''
          # VM Quick Start
          
          ## Prerequisites
          - User must be in 'libvirtd' group
          - libvirtd service must be running
          
          ## Basic Operations
          
          ```bash
          # List VMs
          virsh list --all
          
          # Create VM from template
          hv vm create <name> --template <template>
          
          # Start/Stop VM
          vm-start <name>
          vm-stop <name>
          
          # Connect to console
          virsh console <name>  # Exit with Ctrl+]
          
          # Delete VM
          virsh destroy <name>
          virsh undefine <name>
          ```
          
          ## Troubleshooting
          - Permission denied: Add user to libvirtd group
          - VM won't start: Check logs with journalctl
          - Console blank: VM still booting, wait and retry
        '' else ''
          # VM Quick Start
          
          ```bash
          virsh list --all
          hv vm create <name> --template <template>
          vm-start <name>
          virsh console <name>
          ```
        ''}
        EOF
      '') docProfiles)}
    '';
    
    # Shell integration for adaptive help
    programs.bash.interactiveShellInit = mkIf cfg.contextAware ''
      # Track user experience
      if [[ ! -f ~/.hypervisor/experience-level ]]; then
        mkdir -p ~/.hypervisor
        echo "beginner" > ~/.hypervisor/experience-level
      fi
      
      # Command counter for experience tracking
      hv_command_counter() {
        local count=$(cat ~/.hypervisor/command-count 2>/dev/null || echo 0)
        echo $((count + 1)) > ~/.hypervisor/command-count
        
        # Upgrade experience level based on usage
        if [[ $count -gt 100 && $(cat ~/.hypervisor/experience-level) == "beginner" ]]; then
          echo "intermediate" > ~/.hypervisor/experience-level
          echo "🎉 Congratulations! You've been promoted to intermediate level."
          echo "   Documentation will now be more concise. Change with: hv-config docs --level"
        fi
      }
      
      # Hook into command execution
      trap hv_command_counter DEBUG
      
      # Context-sensitive hints
      ${optionalString cfg.enableHints ''
        PROMPT_COMMAND="hv-prompt; $PROMPT_COMMAND"
      ''}
    '';
  };
}