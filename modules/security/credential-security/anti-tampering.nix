# Anti-Tampering and Integrity Verification Module
# Detects and prevents credential tampering attempts

{ config, lib, pkgs, ... }:

let
  cfg = config.hypervisor.security.antiTampering;
  
  # Comprehensive anti-tampering checker
  antiTamperChecker = pkgs.writeScriptBin "anti-tamper-check" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    readonly TAMPER_LOG="/var/log/hypervisor/tamper-detection.log"
    readonly BASELINE_DIR="/var/lib/hypervisor/integrity"
    readonly LOCKDOWN_FLAG="/var/lib/hypervisor/.security-lockdown"
    
    # Initialize scoring
    TAMPER_SCORE=0
    FINDINGS=()
    
    # Logging function
    log_finding() {
        local severity="$1"
        local message="$2"
        local score="$3"
        
        FINDINGS+=("[$severity] $message")
        TAMPER_SCORE=$((TAMPER_SCORE + score))
        
        echo "[$(date -Iseconds)] [$severity] $message" >> "$TAMPER_LOG"
    }
    
    # Check 1: Debugger Detection
    check_debuggers() {
        echo "Checking for debuggers..."
        
        # Check if we're being traced
        if grep -q "TracerPid:[[:space:]]*[1-9]" /proc/self/status; then
            log_finding "CRITICAL" "Process is being debugged/traced" 50
        fi
        
        # Check for common debugging tools
        if pgrep -x "gdb|strace|ltrace|lldb" >/dev/null 2>&1; then
            log_finding "WARNING" "Debugging tools detected running" 20
        fi
        
        # Check for kernel debugging
        if [[ -e /sys/kernel/debug ]] && mountpoint -q /sys/kernel/debug; then
            log_finding "WARNING" "Kernel debugging interface mounted" 15
        fi
    }
    
    # Check 2: Kernel Module Integrity
    check_kernel_modules() {
        echo "Checking kernel modules..."
        
        # Check for suspicious modules
        local suspicious_modules=(
            "rootkit" "keylogger" "sniffer" "backdoor"
            "hide" "stealth" "hook" "intercept"
        )
        
        for module in $(lsmod | awk 'NR>1 {print $1}'); do
            for suspect in "''${suspicious_modules[@]}"; do
                if [[ "$module" == *"$suspect"* ]]; then
                    log_finding "CRITICAL" "Suspicious kernel module: $module" 40
                fi
            done
        done
        
        # Check for unsigned modules (if secure boot enabled)
        if [[ -d /sys/firmware/efi ]] && mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            local unsigned_modules=$(modinfo -F signer $(lsmod | awk 'NR>1 {print $1}') 2>/dev/null | grep -c "^$" || true)
            if [[ $unsigned_modules -gt 0 ]]; then
                log_finding "WARNING" "Unsigned kernel modules detected: $unsigned_modules" 25
            fi
        fi
    }
    
    # Check 3: Environment Tampering
    check_environment() {
        echo "Checking environment..."
        
        # Check for LD_PRELOAD
        if [[ -n "''${LD_PRELOAD:-}" ]]; then
            log_finding "CRITICAL" "LD_PRELOAD is set: $LD_PRELOAD" 35
        fi
        
        # Check for modified PATH
        if [[ "$PATH" == *"/tmp"* ]] || [[ "$PATH" == *"/var/tmp"* ]]; then
            log_finding "WARNING" "Suspicious PATH contains temp directories" 15
        fi
        
        # Check for LD_LIBRARY_PATH
        if [[ -n "''${LD_LIBRARY_PATH:-}" ]]; then
            log_finding "WARNING" "LD_LIBRARY_PATH is set: $LD_LIBRARY_PATH" 20
        fi
    }
    
    # Check 4: File Integrity
    check_file_integrity() {
        echo "Checking file integrity..."
        
        # Critical files to check
        local critical_files=(
            "/etc/passwd"
            "/etc/shadow"
            "/etc/group"
            "/etc/sudoers"
            "/etc/nixos/configuration.nix"
            "/etc/ssh/sshd_config"
        )
        
        # Create baseline if it doesn't exist
        if [[ ! -d "$BASELINE_DIR" ]]; then
            mkdir -p "$BASELINE_DIR"
            chmod 700 "$BASELINE_DIR"
            
            echo "Creating integrity baseline..."
            for file in "''${critical_files[@]}"; do
                if [[ -f "$file" ]]; then
                    sha256sum "$file" > "$BASELINE_DIR/$(basename "$file").sha256"
                fi
            done
            return 0
        fi
        
        # Check against baseline
        for file in "''${critical_files[@]}"; do
            local baseline_file="$BASELINE_DIR/$(basename "$file").sha256"
            if [[ -f "$baseline_file" ]] && [[ -f "$file" ]]; then
                if ! sha256sum -c "$baseline_file" >/dev/null 2>&1; then
                    log_finding "CRITICAL" "File integrity violation: $file" 30
                fi
            fi
        done
        
        # Check for SUID/SGID changes
        local suid_files=$(find /usr/bin /usr/sbin -perm -4000 -o -perm -2000 2>/dev/null | wc -l)
        local baseline_suid_file="$BASELINE_DIR/suid_count"
        
        if [[ -f "$baseline_suid_file" ]]; then
            local baseline_count=$(cat "$baseline_suid_file")
            if [[ $suid_files -ne $baseline_count ]]; then
                log_finding "WARNING" "SUID/SGID file count changed: $baseline_count -> $suid_files" 20
            fi
        else
            echo "$suid_files" > "$baseline_suid_file"
        fi
    }
    
    # Check 5: Process Anomalies
    check_processes() {
        echo "Checking processes..."
        
        # Check for hidden processes
        local ps_count=$(ps aux | wc -l)
        local proc_count=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
        
        if [[ $((proc_count - ps_count)) -gt 5 ]]; then
            log_finding "WARNING" "Possible hidden processes detected" 25
        fi
        
        # Check for suspicious process names
        local suspicious_names=(
            "ncat" "nc" "netcat" "cryptominer" "xmrig"
            "masscan" "nmap" "exploit" "payload"
        )
        
        for name in "''${suspicious_names[@]}"; do
            if pgrep -f "$name" >/dev/null 2>&1; then
                log_finding "WARNING" "Suspicious process found: $name" 15
            fi
        done
        
        # Check for processes running from temp
        if ps aux | grep -E "/tmp/|/var/tmp/|/dev/shm/" | grep -v grep >/dev/null; then
            log_finding "WARNING" "Processes running from temporary directories" 20
        fi
    }
    
    # Check 6: Network Anomalies
    check_network() {
        echo "Checking network..."
        
        # Check for promiscuous mode
        if ip link show | grep -i promisc >/dev/null 2>&1; then
            log_finding "WARNING" "Network interface in promiscuous mode" 25
        fi
        
        # Check for unusual listeners
        local listeners=$(ss -tlnp 2>/dev/null | grep -c LISTEN || true)
        local baseline_listeners_file="$BASELINE_DIR/listener_count"
        
        if [[ -f "$baseline_listeners_file" ]]; then
            local baseline_listeners=$(cat "$baseline_listeners_file")
            if [[ $listeners -gt $((baseline_listeners + 3)) ]]; then
                log_finding "WARNING" "Unusual number of listening ports: $listeners" 15
            fi
        else
            echo "$listeners" > "$baseline_listeners_file"
        fi
        
        # Check for reverse shells
        if ss -tnp 2>/dev/null | grep -E ":(4444|4445|1337|31337|6666|6667)" >/dev/null; then
            log_finding "CRITICAL" "Suspicious port activity detected" 30
        fi
    }
    
    # Check 7: Boot Security
    check_boot_security() {
        echo "Checking boot security..."
        
        # Check Secure Boot status
        if [[ -d /sys/firmware/efi/efivars ]]; then
            if ! mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
                log_finding "INFO" "Secure Boot is not enabled" 5
            fi
        fi
        
        # Check kernel command line for suspicious parameters
        if grep -E "init=/bin/bash|single|emergency|selinux=0|apparmor=0" /proc/cmdline >/dev/null 2>&1; then
            log_finding "WARNING" "Suspicious kernel parameters detected" 20
        fi
        
        # Check initramfs integrity
        if command -v rpm >/dev/null 2>&1; then
            if ! rpm -V kernel >/dev/null 2>&1; then
                log_finding "WARNING" "Kernel package verification failed" 15
            fi
        fi
    }
    
    # Check 8: Time-based Anomalies
    check_time_anomalies() {
        echo "Checking time anomalies..."
        
        # Check if system time was changed recently
        local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
        local boot_time=$(($(date +%s) - uptime_seconds))
        local bios_time=$(hwclock -r 2>/dev/null | date +%s -f - 2>/dev/null || date +%s)
        
        if [[ $((bios_time - boot_time)) -gt 300 ]] || [[ $((boot_time - bios_time)) -gt 300 ]]; then
            log_finding "WARNING" "System/hardware time mismatch detected" 15
        fi
        
        # Check for recent time jumps
        if journalctl -u systemd-timesyncd --since "1 hour ago" 2>/dev/null | grep -q "System clock wrong"; then
            log_finding "WARNING" "Recent system time adjustment detected" 10
        fi
    }
    
    # Main execution
    main() {
        echo "Starting anti-tampering checks..."
        mkdir -p "$(dirname "$TAMPER_LOG")"
        
        # Run all checks
        check_debuggers
        check_kernel_modules
        check_environment
        check_file_integrity
        check_processes
        check_network
        check_boot_security
        check_time_anomalies
        
        # Evaluate results
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo "Anti-Tampering Check Results"
        echo "═══════════════════════════════════════════════════════════════"
        echo "Tamper Score: $TAMPER_SCORE"
        echo
        
        if [[ ''${#FINDINGS[@]} -gt 0 ]]; then
            echo "Findings:"
            printf '%s\n' "''${FINDINGS[@]}"
            echo
        fi
        
        # Determine action based on score
        if [[ $TAMPER_SCORE -eq 0 ]]; then
            echo "Status: SECURE - No tampering detected"
            exit 0
        elif [[ $TAMPER_SCORE -lt ${toString cfg.warningThreshold} ]]; then
            echo "Status: NOTICE - Minor anomalies detected"
            exit 0
        elif [[ $TAMPER_SCORE -lt ${toString cfg.criticalThreshold} ]]; then
            echo "Status: WARNING - Suspicious activity detected"
            exit 1
        else
            echo "Status: CRITICAL - High probability of tampering!"
            
            if [[ "${toString cfg.enableLockdown}" == "true" ]]; then
                echo "INITIATING SECURITY LOCKDOWN!"
                touch "$LOCKDOWN_FLAG"
                
                # Additional lockdown actions
                if command -v iptables >/dev/null 2>&1; then
                    # Block all incoming connections except SSH (for recovery)
                    iptables -P INPUT DROP
                    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                fi
                
                # Disable first boot if it hasn't completed
                touch /var/lib/hypervisor/.first-boot-complete
                
                # Alert administrator
                logger -p security.crit "SECURITY: Anti-tampering lockdown activated (score: $TAMPER_SCORE)"
            fi
            
            exit 2
        fi
    }
    
    # Handle command line options
    case "''${1:-check}" in
        check)
            main
            ;;
        baseline)
            echo "Creating security baseline..."
            rm -rf "$BASELINE_DIR"
            TAMPER_SCORE=0
            check_file_integrity
            check_network
            echo "Baseline created successfully"
            ;;
        reset)
            echo "Resetting lockdown status..."
            rm -f "$LOCKDOWN_FLAG"
            if command -v iptables >/dev/null 2>&1; then
                iptables -P INPUT ACCEPT
                iptables -F INPUT
            fi
            echo "Lockdown reset"
            ;;
        *)
            echo "Usage: $0 [check|baseline|reset]"
            exit 1
            ;;
    esac
  '';
  
in
{
  options.hypervisor.security.antiTampering = {
    enable = lib.mkEnableOption "Anti-tampering detection";
    
    warningThreshold = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Score threshold for warning alerts";
    };
    
    criticalThreshold = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Score threshold for critical alerts";
    };
    
    enableLockdown = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic lockdown on critical tampering";
    };
    
    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often to run anti-tampering checks";
    };
    
    alertCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command to run on tampering detection";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Install anti-tampering tools
    environment.systemPackages = [
      antiTamperChecker
      pkgs.chkrootkit
      pkgs.rkhunter
    ];
    
    # Systemd service for periodic checks
    systemd.services.anti-tamper-check = {
      description = "Anti-tampering security check";
      after = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${antiTamperChecker}/bin/anti-tamper-check check";
        ExecStartPost = lib.optional (cfg.alertCommand != null) cfg.alertCommand;
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
    
    systemd.timers.anti-tamper-check = {
      description = "Anti-tampering check timer";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.checkInterval;
        RandomizedDelaySec = "30s";
      };
    };
    
    # Create baseline on first boot
    systemd.services.anti-tamper-baseline = {
      description = "Create anti-tampering baseline";
      wantedBy = [ "multi-user.target" ];
      after = [ "first-boot-complete.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${antiTamperChecker}/bin/anti-tamper-check baseline";
      };
      
      unitConfig = {
        ConditionPathExists = "!/var/lib/hypervisor/integrity";
      };
    };
    
    # Audit rules for monitoring - only if audit is available
    security.audit = lib.mkIf (config.security ? audit) {
      enable = true;
      rules = [
        # Monitor authentication files
        "-w /etc/passwd -p wa -k auth_files"
        "-w /etc/shadow -p wa -k auth_files"
        "-w /etc/group -p wa -k auth_files"
        "-w /etc/sudoers -p wa -k auth_files"
        
        # Monitor module loading
        "-w /sbin/insmod -p x -k modules"
        "-w /sbin/rmmod -p x -k modules"
        "-w /sbin/modprobe -p x -k modules"
        
        # Monitor privileged commands
        "-a always,exit -F arch=b64 -S execve -F uid=0 -k root_commands"
      ];
    };
  };
}