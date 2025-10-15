# Educational Content System
# Provides comprehensive learning materials with adaptive verbosity

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf mkDefault mkForce mkMerge types;
  cfg = config.hypervisor.education;
  
  # Educational content generator
  generateEducationalContent = level: pkgs.stdenv.mkDerivation {
    name = "hypervisor-educational-content-${level}";
    
    buildCommand = ''
      mkdir -p $out/share/hypervisor/education/${level}
      
      # Quick Start Guides
      cat > $out/share/hypervisor/education/${level}/quick-start.md <<'EOF'
      ${if level == "beginner" then ''
        # 🚀 Quick Start Guide for Beginners
        
        Welcome to Hyper-NixOS! This guide will help you get started with
        virtual machines step by step. No prior experience needed!
        
        ## 🤔 What is Hyper-NixOS?
        
        Hyper-NixOS is a system for running virtual machines (VMs). Think of
        VMs as computers inside your computer. Each VM is completely isolated,
        making them perfect for:
        
        - 🧪 Testing software safely
        - 🌍 Running different operating systems
        - 🔒 Isolating applications
        - 📚 Learning and experimentation
        
        ## 📋 Before You Start
        
        Let's make sure you're ready:
        
        ### Check Your Access
        ```bash
        # Type this command and press Enter:
        groups
        ```
        
        You should see `libvirtd` in the list. If not, don't worry! Here's how to fix it:
        
        ```bash
        # Ask your administrator to run:
        sudo usermod -aG libvirtd $USER
        ```
        
        Then logout and login again.
        
        ### Verify Everything Works
        ```bash
        # Check if virtualization is working:
        virsh list --all
        ```
        
        If you see a table (even if empty), you're ready to go!
        
        ## 🎯 Your First Virtual Machine
        
        Let's create your first VM! We'll use a template to make it easy.
        
        ### Step 1: See Available Templates
        ```bash
        hv template list
        ```
        
        You'll see options like:
        - `debian-11` - Great for beginners! Stable and user-friendly
        - `ubuntu-22.04` - Popular choice with lots of documentation
        - `fedora-38` - Latest features for adventurous users
        
        ### Step 2: Create Your VM
        ```bash
        # Let's create a Debian VM named "my-first-vm"
        hv vm create my-first-vm --template debian-11
        ```
        
        What's happening:
        - 📦 Downloading the operating system
        - 💾 Creating a virtual hard drive
        - 🔧 Setting up virtual hardware
        - ✅ Registering your VM with the system
        
        ### Step 3: Start Your VM
        ```bash
        vm-start my-first-vm
        ```
        
        Your VM is now running! It's like pressing the power button.
        
        ### Step 4: Connect to Your VM
        ```bash
        # Connect to the VM's console:
        virsh console my-first-vm
        ```
        
        - Press Enter to see the login screen
        - Default login: `user` / `password`
        - To exit console: Press `Ctrl+]`
        
        ## 🎮 Basic VM Control
        
        Here are the essential commands you'll use:
        
        ### View Your VMs
        ```bash
        virsh list --all        # See all VMs
        virsh list             # See running VMs only
        ```
        
        ### Control VM State
        ```bash
        vm-start my-first-vm   # Turn on
        vm-stop my-first-vm    # Graceful shutdown
        virsh destroy my-first-vm  # Force stop (like pulling power)
        ```
        
        ### Get VM Information
        ```bash
        virsh dominfo my-first-vm   # Basic info
        virsh domstats my-first-vm  # Detailed statistics
        ```
        
        ## 💡 Pro Tips for Beginners
        
        ### 1. Use Tab Completion
        Type part of a command and press Tab:
        ```bash
        vm-start my-<TAB>  # Completes to my-first-vm
        ```
        
        ### 2. Take Snapshots Before Changes
        ```bash
        # Save VM state before experimenting:
        virsh snapshot-create-as my-first-vm "before-changes"
        
        # Restore if something goes wrong:
        virsh snapshot-revert my-first-vm "before-changes"
        ```
        
        ### 3. Use Help Commands
        ```bash
        hv-help vm-start      # Detailed help for any command
        hv-tutorial           # Interactive tutorials
        hv-cheatsheet        # Quick reference
        ```
        
        ## 🚨 Common Issues & Solutions
        
        ### "Permission denied"
        **Problem**: You're not in the libvirtd group
        **Solution**: 
        ```bash
        # Check your groups:
        groups
        
        # If libvirtd is missing, ask admin to add you:
        sudo usermod -aG libvirtd $USER
        # Then logout and login
        ```
        
        ### "Failed to start domain"
        **Problem**: VM configuration issue or resource conflict
        **Solution**:
        ```bash
        # Check for errors:
        virsh dominfo my-first-vm
        journalctl -xe | grep libvirt
        
        # Common fixes:
        # - Check disk space: df -h
        # - Check memory: free -h
        ```
        
        ### Console Shows Nothing
        **Problem**: VM is still booting
        **Solution**: Wait 30 seconds and try again, or:
        ```bash
        # Check if VM is actually running:
        virsh list
        
        # View graphical console instead:
        virt-viewer my-first-vm
        ```
        
        ## 📚 Learning Path
        
        Now that you have a running VM, here's what to learn next:
        
        1. **Networking** (Next week)
           - Connect VMs to the internet
           - Create private networks
           - Access VMs remotely
           
        2. **Storage** (Week 3)
           - Add extra disks
           - Expand storage
           - Share files with host
           
        3. **Snapshots & Backups** (Week 4)
           - Save and restore VM states
           - Create backups
           - Clone VMs
        
        ## 🎓 Interactive Tutorials
        
        Ready for hands-on learning? Try these:
        ```bash
        hv-tutorial basics      # VM basics (30 min)
        hv-tutorial networking  # Network setup (45 min)
        hv-tutorial security    # Security basics (30 min)
        ```
        
        ## 🆘 Getting Help
        
        Remember, everyone starts as a beginner! Here's how to get help:
        
        1. **Built-in Help**: `hv-help <topic>`
        2. **Community Forum**: https://hyper-nixos.org/forum
        3. **Live Chat**: https://hyper-nixos.org/chat
        4. **Video Tutorials**: https://hyper-nixos.org/videos
        
        ## 🎉 Congratulations!
        
        You've created and managed your first VM! You're now ready to:
        - Experiment safely in isolated environments
        - Learn new operating systems
        - Test software without risk
        - Build your own services
        
        Keep this guide handy and don't be afraid to experiment. VMs are
        meant to be created, broken, and recreated. Have fun learning!
      '' else if level == "intermediate" then ''
        # Quick Start Guide
        
        ## Prerequisites
        - User in libvirtd group
        - Basic VM knowledge assumed
        
        ## Common Operations
        
        ### VM Management
        ```bash
        virsh list --all                    # List all VMs
        hv vm create <name> --template <t>  # Create from template
        vm-start <name>                     # Start VM
        vm-stop <name>                      # Stop VM
        virsh console <name>                # Connect to console
        ```
        
        ### Networking
        ```bash
        virsh net-list --all               # List networks
        virsh attach-interface <vm> bridge br0  # Attach to bridge
        ```
        
        ### Storage
        ```bash
        virsh pool-list --all              # List storage pools
        qemu-img create -f qcow2 disk.img 20G  # Create disk
        virsh attach-disk <vm> disk.img vdb    # Attach disk
        ```
        
        ### Snapshots
        ```bash
        virsh snapshot-create-as <vm> <name>   # Create snapshot
        virsh snapshot-list <vm>               # List snapshots
        virsh snapshot-revert <vm> <name>      # Revert
        ```
        
        ## Advanced Features
        
        - CPU pinning: `virsh vcpupin`
        - Memory ballooning: `virsh dommemstat`
        - Live migration: `virsh migrate`
        
        ## Troubleshooting
        
        Check logs: `journalctl -u libvirtd -f`
        VM logs: `/var/log/libvirt/qemu/<vm>.log`
      '' else ''
        # Quick Start
        
        ```bash
        # VM Operations
        virsh list --all
        virsh start <vm>
        virsh console <vm>
        
        # Snapshots
        virsh snapshot-create-as <vm> <name>
        virsh snapshot-revert <vm> <name>
        
        # Networking
        virsh attach-interface <vm> bridge br0 --model virtio
        
        # Performance
        virsh vcpupin <vm> <vcpu> <pcpu>
        virsh numatune <vm> --mode strict --nodeset 0
        ```
      ''}
      EOF
      
      # Security Best Practices
      cat > $out/share/hypervisor/education/${level}/security-guide.md <<'EOF'
      ${if level == "beginner" then ''
        # 🔒 Security Guide for Beginners
        
        Security doesn't have to be complicated! This guide will help you
        keep your VMs and data safe.
        
        ## 🛡️ Why Security Matters
        
        Virtual machines are isolated, but not invincible. Good security:
        - Protects your data
        - Prevents unauthorized access
        - Keeps your VMs running smoothly
        - Builds good habits for the future
        
        ## 🔑 Essential Security Practices
        
        ### 1. Use Strong Passwords
        
        **Bad passwords**: password, 123456, admin
        **Good passwords**: Tr0ub4dor&3, correct-horse-battery-staple
        
        Change default passwords immediately:
        ```bash
        # Inside your VM:
        passwd  # Changes current user password
        ```
        
        ### 2. Keep VMs Updated
        
        Just like your phone needs updates, so do VMs:
        ```bash
        # Debian/Ubuntu VMs:
        sudo apt update && sudo apt upgrade
        
        # Fedora VMs:
        sudo dnf update
        ```
        
        ### 3. Limit Network Access
        
        Not all VMs need internet access:
        ```bash
        # Create isolated network for testing:
        hv network create isolated --no-internet
        ```
        
        ### 4. Take Snapshots Before Changes
        
        Always have a backup plan:
        ```bash
        # Before installing software:
        virsh snapshot-create-as my-vm "pre-install"
        
        # If something goes wrong:
        virsh snapshot-revert my-vm "pre-install"
        ```
        
        ## 🚨 Warning Signs
        
        Watch out for:
        - Unexpected high CPU/memory usage
        - Unknown processes running
        - Changed files you didn't modify
        - Network connections you didn't make
        
        Check VM health:
        ```bash
        # See resource usage:
        virsh domstats my-vm
        
        # Check who's logged in:
        virsh console my-vm
        $ who  # Inside VM
        ```
        
        ## 🎯 Security Checklist
        
        For each new VM:
        - [ ] Change default passwords
        - [ ] Update all software
        - [ ] Configure firewall if needed
        - [ ] Take initial snapshot
        - [ ] Document what it's for
        
        ## 💡 Golden Rules
        
        1. **Isolate experiments**: Use separate VMs for testing
        2. **Regular backups**: Snapshot important VMs weekly
        3. **Minimal access**: Only expose what's needed
        4. **Stay informed**: Check for security updates
        
        Remember: Security is a journey, not a destination. Start with
        these basics and build from there!
      '' else if level == "intermediate" then ''
        # Security Best Practices
        
        ## VM Isolation
        
        - Use separate networks for different VM categories
        - Enable SELinux/AppArmor in VMs
        - Regularly audit VM permissions
        
        ## Network Security
        
        ```bash
        # Create isolated network
        virsh net-define isolated-net.xml
        virsh net-start isolated
        
        # Firewall rules per VM
        iptables -A FORWARD -s <vm-ip> -j DROP
        ```
        
        ## Access Control
        
        - Use SSH keys instead of passwords
        - Implement fail2ban for brute force protection
        - Regular security updates
        
        ## Monitoring
        
        ```bash
        # Audit VM operations
        aureport -x --summary
        
        # Monitor resource usage
        virt-top
        ```
      '' else ''
        # Security
        
        - Network isolation: libvirt networks, OVS
        - sVirt/SELinux mandatory access control
        - QEMU seccomp sandboxing
        - TPM/vTPM for measured boot
        - Memory encryption (SEV/TDX where available)
      ''}
      EOF
      
      # Troubleshooting Guide
      cat > $out/share/hypervisor/education/${level}/troubleshooting.md <<'EOF'
      ${if level == "beginner" then ''
        # 🔧 Troubleshooting Guide
        
        Don't panic! Most VM issues have simple solutions.
        
        ## 🏥 First Aid Kit
        
        When something goes wrong, try these in order:
        
        1. **Read the error message** - It often tells you exactly what's wrong
        2. **Check the basics** - Is the VM running? Enough disk space?
        3. **Look at logs** - Recent events often reveal the issue
        4. **Restart the VM** - Sometimes a fresh start helps
        5. **Ask for help** - Include error messages and what you tried
        
        ## 🚑 Common Problems & Solutions
        
        ### "Cannot access storage file"
        
        **Symptom**: VM won't start, mentions storage
        **Cause**: Disk image missing or permissions wrong
        
        **Fix**:
        ```bash
        # Check if disk exists:
        ls -la /var/lib/libvirt/images/
        
        # Fix permissions:
        sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/*.qcow2
        ```
        
        ### "Network 'default' is not active"
        
        **Symptom**: VM can't get network
        **Cause**: Default network not started
        
        **Fix**:
        ```bash
        # Start default network:
        virsh net-start default
        
        # Make it auto-start:
        virsh net-autostart default
        ```
        
        ### VM Runs Slowly
        
        **Symptom**: VM is sluggish, takes forever to respond
        **Causes**: Not enough resources or host is busy
        
        **Fix**:
        ```bash
        # Check host resources:
        free -h  # Memory
        htop     # CPU usage
        
        # Give VM more memory:
        virsh shutdown my-vm
        virsh setmaxmem my-vm 2G --config
        virsh setmem my-vm 2G --config
        virsh start my-vm
        ```
        
        ### Can't Connect to Console
        
        **Symptom**: `virsh console` shows nothing
        **Cause**: VM not configured for serial console
        
        **Fix**:
        ```bash
        # Try graphical console instead:
        virt-viewer my-vm
        
        # Or access via network:
        ssh user@vm-ip-address
        ```
        
        ## 🔍 Diagnostic Commands
        
        Keep these handy:
        
        ```bash
        # Is VM running?
        virsh list --all
        
        # VM details:
        virsh dominfo my-vm
        
        # Recent errors:
        journalctl -xe | grep -i error
        
        # Disk space:
        df -h
        
        # Memory:
        free -h
        
        # VM logs:
        sudo tail -f /var/log/libvirt/qemu/my-vm.log
        ```
        
        ## 📊 Understanding Error Messages
        
        ### Permission Errors
        - "Permission denied" → User not in right group
        - "Operation not permitted" → Need sudo or different user
        - "Access denied" → SELinux/AppArmor blocking
        
        ### Resource Errors  
        - "No space left" → Disk full
        - "Cannot allocate memory" → Not enough RAM
        - "Resource busy" → Something else using it
        
        ### Network Errors
        - "No route to host" → Network misconfigured
        - "Connection refused" → Service not running
        - "Network unreachable" → Bridge/interface down
        
        ## 🆘 Getting Help Effectively
        
        When asking for help, include:
        
        1. **What you're trying to do**
           "I want to start my VM named webserver"
           
        2. **Exact error message**
           Copy and paste, don't summarize
           
        3. **What you've tried**
           "I checked disk space and restarted libvirtd"
           
        4. **System info**
           ```bash
           uname -a
           virsh version
           ```
        
        ## 💪 Building Confidence
        
        Remember:
        - VMs are meant to be experimented with
        - Snapshots are your safety net
        - Every expert was once a beginner
        - The community is here to help
        
        You've got this! 🚀
      '' else if level == "intermediate" then ''
        # Troubleshooting Guide
        
        ## Diagnostic Process
        
        1. Check VM state: `virsh domstate <vm>`
        2. Review logs: `/var/log/libvirt/qemu/<vm>.log`
        3. System logs: `journalctl -u libvirtd`
        4. Resource availability: `virsh nodememstats`, `virsh pool-info`
        
        ## Common Issues
        
        ### Performance Problems
        ```bash
        # CPU bottlenecks
        virsh vcpuinfo <vm>
        virsh cpu-stats <vm>
        
        # Memory issues
        virsh dommemstat <vm>
        virsh memtune <vm>
        
        # I/O bottlenecks
        virsh blkstat <vm>
        iotop -P
        ```
        
        ### Network Issues
        ```bash
        # Check bridges
        brctl show
        ip link show
        
        # Verify iptables
        iptables -L -n -v
        
        # Test connectivity
        virsh domifaddr <vm>
        ```
        
        ### Storage Problems
        ```bash
        # Check pool status
        virsh pool-info default
        virsh vol-list default
        
        # Verify permissions
        ls -la /var/lib/libvirt/images/
        ```
      '' else ''
        # Troubleshooting
        
        ## Debug Commands
        ```bash
        virsh -d 5 start <vm>  # Debug libvirt
        LIBVIRT_DEBUG=1 virsh start <vm>
        strace -f virsh start <vm>
        ```
        
        ## Performance Analysis
        ```bash
        perf kvm stat
        trace-cmd record -e kvm
        ```
        
        ## Core Dumps
        ```bash
        virsh dump <vm> core.dump --memory-only
        crash vmlinux core.dump
        ```
      ''}
      EOF
    '';
  };
  
  # Interactive tutorial system
  interactiveTutorials = pkgs.writeScriptBin "hv-tutorial" ''
    #!${pkgs.bash}/bin/bash
    
    TUTORIAL="''${1:-list}"
    LEVEL="${cfg.defaultLevel}"
    
    case "$TUTORIAL" in
      list)
        echo "Available tutorials:"
        echo "  basics       - VM fundamentals (30 min)"
        echo "  networking   - Network configuration (45 min)"
        echo "  storage      - Storage management (30 min)"
        echo "  security     - Security hardening (45 min)"
        echo "  performance  - Performance tuning (60 min)"
        echo
        echo "Run: hv-tutorial <name>"
        ;;
        
      basics)
        ${pkgs.dialog}/bin/dialog --title "VM Basics Tutorial" \
          --msgbox "Welcome to the VM Basics tutorial!\n\nWe'll cover:\n- Creating VMs\n- Starting/stopping\n- Console access\n- Basic management\n\nPress OK to begin." 12 50
        
        # Continue with interactive steps...
        ;;
    esac
  '';

in {
  options.hypervisor.education = {
    enable = mkEnableOption "educational content system";
    
    defaultLevel = mkOption {
      type = types.enum [ "beginner" "intermediate" "expert" ];
      default = "intermediate";
      description = "Default documentation level";
    };
    
    enableInteractiveTutorials = mkOption {
      type = types.bool;
      default = true;
      description = "Enable interactive tutorial system";
    };
    
    enableVideoLinks = mkOption {
      type = types.bool;
      default = true;
      description = "Include links to video tutorials";
    };
    
    enableProgressTracking = mkOption {
      type = types.bool;
      default = true;
      description = "Track user progress through tutorials";
    };
    
    customContent = mkOption {
      type = types.attrsOf types.lines;
      default = {};
      description = "Additional custom educational content";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install educational content
    environment.systemPackages = [
      (generateEducationalContent "beginner")
      (generateEducationalContent "intermediate")
      (generateEducationalContent "expert")
      interactiveTutorials
      
      # Quick reference card
      (pkgs.writeScriptBin "hv-quickref" ''
        #!${pkgs.bash}/bin/bash
        
        LEVEL="''${1:-${cfg.defaultLevel}}"
        
        case "$LEVEL" in
          beginner)
            ${pkgs.bat}/bin/bat --style=plain <<'EOF'
        ╔═══════════════════════════════════════════════════╗
        ║           Hyper-NixOS Quick Reference             ║
        ╠═══════════════════════════════════════════════════╣
        ║                                                   ║
        ║  Essential Commands:                              ║
        ║  ─────────────────                                ║
        ║  virsh list --all         List all VMs            ║
        ║  vm-start <name>          Start a VM              ║
        ║  vm-stop <name>           Stop a VM               ║
        ║  virsh console <name>     Connect to VM           ║
        ║                          (Exit with Ctrl+])       ║
        ║                                                   ║
        ║  Getting Help:                                    ║
        ║  ────────────                                     ║
        ║  hv-help <command>        Command help            ║
        ║  hv-tutorial              Interactive guides      ║
        ║  hv-cheatsheet           Full command list        ║
        ║                                                   ║
        ║  Tips:                                            ║
        ║  ────                                             ║
        ║  • Use Tab for command completion                 ║
        ║  • Take snapshots before changes                  ║
        ║  • Check logs if something fails                  ║
        ║                                                   ║
        ╚═══════════════════════════════════════════════════╝
        EOF
            ;;
          *)
            cat /usr/share/hypervisor/education/$LEVEL/quickref.txt
            ;;
        esac
      '')
      
      # Progress tracker
      (mkIf cfg.enableProgressTracking (pkgs.writeScriptBin "hv-progress" ''
        #!${pkgs.bash}/bin/bash
        
        PROGRESS_FILE="$HOME/.hypervisor/progress.json"
        mkdir -p "$(dirname "$PROGRESS_FILE")"
        
        case "''${1:-show}" in
          show)
            if [[ -f "$PROGRESS_FILE" ]]; then
              ${pkgs.jq}/bin/jq . "$PROGRESS_FILE"
            else
              echo "No progress tracked yet. Start a tutorial!"
            fi
            ;;
          update)
            # Update progress...
            ;;
        esac
      ''))
    ];
    
    # Bash completion for educational commands
    environment.etc."bash_completion.d/hv-education" = {
      text = ''
        _hv_tutorial() {
          local cur="''${COMP_WORDS[COMP_CWORD]}"
          local tutorials="basics networking storage security performance"
          COMPREPLY=( $(compgen -W "$tutorials" -- "$cur") )
        }
        complete -F _hv_tutorial hv-tutorial
        
        _hv_help() {
          local cur="''${COMP_WORDS[COMP_CWORD]}"
          local topics="vm-start vm-stop vm-create networking storage security troubleshooting"
          COMPREPLY=( $(compgen -W "$topics" -- "$cur") )
        }
        complete -F _hv_help hv-help
      '';
    };
  };
}