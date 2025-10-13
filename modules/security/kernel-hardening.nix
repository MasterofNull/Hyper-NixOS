{ config, lib, pkgs, ... }:

# Kernel Hardening Settings
# Consolidated kernel sysctl settings for security and performance
# Extracted from security-production.nix, security-strict.nix, and cache-optimization.nix

{
  boot.kernel.sysctl = {
    # ═══════════════════════════════════════════════════════════════
    # Kernel Security Hardening
    # ═══════════════════════════════════════════════════════════════
    
    # Prevent information leaks
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    
    # Disable unprivileged operations
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.unprivileged_bpf_disabled" = 1;
    
    # Restrict ptrace (prevent debugging of other processes)
    "kernel.yama.ptrace_scope" = 2;  # Strict ptrace
    
    # Disable kexec (prevent kernel replacement)
    "kernel.kexec_load_disabled" = 1;
    
    # Enable ASLR (Address Space Layout Randomization)
    "kernel.randomize_va_space" = 2;
    
    # Restrict kernel performance events
    "kernel.perf_event_paranoid" = lib.mkDefault 3;
    
    # Restrict userfaultfd (prevent certain exploits)
    "vm.unprivileged_userfaultfd" = lib.mkDefault 0;
    
    # ═══════════════════════════════════════════════════════════════
    # Network Security Hardening
    # ═══════════════════════════════════════════════════════════════
    
    # IP Forwarding (enabled for VM networking)
    # "net.ipv4.ip_forward" = 1;  # Managed by libvirt
    
    # Reverse path filtering (prevent IP spoofing)
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    
    # Disable source routing
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    
    # Disable ICMP redirects (prevent MITM)
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    
    # Enable SYN cookies (prevent SYN flood)
    "net.ipv4.tcp_syncookies" = 1;
    
    # Ignore broadcast pings
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    
    # ═══════════════════════════════════════════════════════════════
    # Filesystem Security
    # ═══════════════════════════════════════════════════════════════
    
    # Protect hard links and symlinks
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    
    # Disable core dumps for setuid programs
    "fs.suid_dumpable" = 0;
  };
  
  # Note: TCP performance optimization sysctls (buffer sizes, tcp_fastopen, etc.)
  # are now in modules/core/cache-optimization.nix where they semantically belong.
  # This module focuses solely on security hardening.
}
