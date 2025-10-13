# Sysctl Organization Rules

## Purpose

This document defines the **strict organization rules** for kernel sysctl settings across Hyper-NixOS modules to prevent duplicate definitions and maintain proper separation of concerns.

## Organization Rules

### Security: Kernel Hardening
**File:** `modules/security/kernel-hardening.nix`

**Contains:**
- `kernel.*` - All kernel security settings
  - `kernel.dmesg_restrict`
  - `kernel.kptr_restrict`
  - `kernel.unprivileged_userns_clone`
  - `kernel.unprivileged_bpf_disabled`
  - `kernel.yama.ptrace_scope`
  - `kernel.kexec_load_disabled`
  - `kernel.randomize_va_space`
  - `kernel.perf_event_paranoid`

- `vm.*` - Virtual memory security settings
  - `vm.unprivileged_userfaultfd`

- `fs.*` - Filesystem security settings
  - `fs.protected_hardlinks`
  - `fs.protected_symlinks`
  - `fs.protected_fifos`
  - `fs.protected_regular`
  - `fs.suid_dumpable`

**Rationale:** Kernel-level security settings belong in the security module hierarchy.

---

### Network: Performance Tuning
**File:** `modules/network-settings/performance.nix`

**Contains:**
- `net.core.*` - Network buffer and queue sizes
  - `net.core.rmem_max`
  - `net.core.wmem_max`
  - `net.core.somaxconn`
  - `net.core.netdev_max_backlog`

- `net.ipv4.tcp_*` - TCP performance tuning (except security settings)
  - `net.ipv4.tcp_rmem`
  - `net.ipv4.tcp_wmem`
  - `net.ipv4.tcp_fastopen`

**Rationale:** Network performance optimization belongs in the network-settings module hierarchy.

---

### Network: Security Hardening
**File:** `modules/network-settings/security.nix`

**Contains:**
- `net.ipv4.conf.*` - IP configuration security
  - `net.ipv4.conf.all.rp_filter`
  - `net.ipv4.conf.default.rp_filter`
  - `net.ipv4.conf.all.accept_source_route`
  - `net.ipv4.conf.default.accept_source_route`
  - `net.ipv4.conf.all.send_redirects`
  - `net.ipv4.conf.default.send_redirects`
  - `net.ipv4.conf.all.accept_redirects`
  - `net.ipv4.conf.default.accept_redirects`

- `net.ipv4.icmp_*` - ICMP security
  - `net.ipv4.icmp_echo_ignore_broadcasts`

- `net.ipv4.tcp_syncookies` - TCP security (SYN flood protection)

**Rationale:** Network security settings belong in the network-settings module hierarchy, separate from performance tuning.

---

### Virtualization: Performance (Exception)
**File:** `modules/virtualization/performance.nix`

**Contains:**
- `vm.nr_hugepages` - Hugepage allocation (conditional, opt-in)

**Rationale:** This is a virtualization-specific performance setting that's conditionally enabled, not a security setting.

---

### Security: Strict Overrides
**File:** `modules/security/strict.nix`

**Contains:**
- Uses `lib.mkForce` to override settings from other modules for strict security profile
- This is **intentional** and allowed

**Rationale:** Security profiles need to override defaults for stricter settings.

---

## Validation

### Automated Validation Script

Run the validation script to check for duplicates and organizational violations:

```bash
./scripts/validate-sysctl-organization.sh
```

This script is automatically run during CI validation.

### Manual Verification

To manually check for duplicates:

```bash
# Find all sysctl definitions
grep -rE '^\s*"[a-z][a-z0-9._]*"\s*=' modules/ --include="*.nix" | grep -v strict.nix | sort

# Group by sysctl name to find duplicates
grep -rE '^\s*"[a-z][a-z0-9._]*"\s*=' modules/ --include="*.nix" | \
  grep -oP '"\K[a-z][a-z0-9._]*(?="\s*=)' | sort | uniq -c | grep -v "^\s*1 "
```

---

## Adding New Sysctls

### Decision Tree

When adding a new sysctl setting, follow this decision tree:

```
1. Is it a kernel.*, vm.* (except hugepages), or fs.* setting?
   → YES: Add to modules/security/kernel-hardening.nix
   → NO: Continue to 2

2. Is it a net.core.* or net.ipv4.tcp_* PERFORMANCE setting?
   → YES: Add to modules/network-settings/performance.nix
   → NO: Continue to 3

3. Is it a net.ipv4.conf.*, net.ipv4.icmp_*, or tcp_syncookies SECURITY setting?
   → YES: Add to modules/network-settings/security.nix
   → NO: Continue to 4

4. Is it a virtualization-specific conditional setting?
   → YES: Add to modules/virtualization/performance.nix
   → NO: Create a new appropriately-named module
```

### Best Practices

1. **Always use `lib.mkDefault`** for sysctl values to allow overriding
   ```nix
   "kernel.setting" = lib.mkDefault 1;
   ```

2. **Run validation before committing**
   ```bash
   ./scripts/validate-sysctl-organization.sh
   ```

3. **Document the purpose** with comments explaining WHY the setting exists

4. **Group related settings** under clear section headers

---

## Common Mistakes to Avoid

### ❌ DON'T: Add network sysctls to kernel-hardening.nix
```nix
# modules/security/kernel-hardening.nix
boot.kernel.sysctl = {
  "net.core.rmem_max" = 134217728;  # WRONG!
};
```

### ✅ DO: Add network sysctls to network-settings/
```nix
# modules/network-settings/performance.nix
boot.kernel.sysctl = {
  "net.core.rmem_max" = lib.mkDefault 134217728;  # CORRECT!
};
```

### ❌ DON'T: Duplicate sysctls across modules
```nix
# modules/security/kernel-hardening.nix
"kernel.kptr_restrict" = 2;

# modules/core/cache-optimization.nix
"kernel.kptr_restrict" = 2;  # DUPLICATE!
```

### ✅ DO: Define each sysctl once, in the correct location
```nix
# modules/security/kernel-hardening.nix (ONLY)
"kernel.kptr_restrict" = 2;
```

---

## Emergency Override

If you need to override a sysctl for testing or a specific configuration, use:

1. **Per-host override:** Create `/var/lib/hypervisor/configuration/sysctl-local.nix`
2. **Use `lib.mkForce`** to explicitly override:
   ```nix
   boot.kernel.sysctl = {
     "kernel.setting" = lib.mkForce 999;
   };
   ```

---

## References

- [NixOS Manual - Sysctl](https://nixos.org/manual/nixos/stable/#sec-module-system)
- [Linux Kernel Sysctl Documentation](https://www.kernel.org/doc/Documentation/sysctl/)
- [Hyper-NixOS Organization Guide](ORGANIZATION.md)

---

**Last Updated:** 2025-10-13  
**Validator:** `scripts/validate-sysctl-organization.sh`  
**CI Check:** Enabled in `tests/ci_validation.sh`
