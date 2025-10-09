# Advanced Features

- VFIO Passthrough: Use VFIO configure in menu; IDs are suggested, snippet written to /var/lib/hypervisor/vfio-boot.local.nix.
- CPU Pinning & Hugepages: Add `cpu_pinning` array and `hugepages: true` in VM profile JSON.
- Looking Glass: Set `looking_glass.enable: true` and size via `looking_glass.size_mb`.
- PCI Devices: Add `hostdevs` array of BDFs (e.g., `0000:01:00.0`).
- Networking: Use Bridge Helper to create `br0`, then set `network.bridge` in profiles.
