# Hypervisor Suite - Quick Install

1. Build the ISO
```
nix build .#iso
```

2. Boot it on your machine (USB or IPMI) and follow the on-screen menu.

3. Use ISO Manager to download and verify an OS installer.

4. Create VM (wizard), then Start VM.

## Notes
- Logging is in /var/log/hypervisor.
- Advanced features (VFIO, pinning, hugepages) are toggled per-VM JSON.
