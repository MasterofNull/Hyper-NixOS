{ config, lib, pkgs, ... }:

# Kernel Hardening Settings
# Kernel-specific security sysctls only (kernel.*, vm.*, fs.*)
# Network security sysctls have been moved to network-settings modules

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
  
  # Note: Network-related sysctls have been moved to network-settings/:
  # - Network performance (TCP buffers, connection tuning) → network-settings/performance.nix
  # - Network security (IP/ICMP/TCP security) → network-settings/security.nix
  # This maintains proper separation: kernel/* and vm/* and fs/* here, net.* in network-settings/
}
