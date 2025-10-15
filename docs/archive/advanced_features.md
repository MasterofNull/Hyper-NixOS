# Advanced Features

- VFIO Passthrough: Use VFIO configure in menu; IDs are suggested, snippet written to /var/lib/hypervisor/vfio-boot.local.nix.
- CPU Pinning & Hugepages: Add `cpu_pinning` array and `hugepages: true` in VM profile JSON.

### New in Linux 6.18 (optional toggles)

- CET on x86: add `cpu_features.shstk: true` and for Intel `cpu_features.ibt: true`.
- AMD AVIC / Secure AVIC: `cpu_features.avic: true` (Secure AVIC requires host support).
- AMD SEV/SEV-ES/SEV-SNP: `cpu_features.sev`, `cpu_features.sev_es`, `cpu_features.sev_snp` with optional `cpu_features.ciphertext_hiding`, `cpu_features.secure_tsc`.
- Private guest memory groundwork: `memory_options.guest_memfd: true`, `memory_options.private: true` (applies when supported by host).
- Architectures: set `arch` to `x86_64`, `aarch64`, `riscv64`, or `loongarch64` to pick the appropriate QEMU binary and machine type.
- Looking Glass: Set `looking_glass.enable: true` and size via `looking_glass.size_mb`.
- PCI Devices: Add `hostdevs` array of BDFs (e.g., `0000:01:00.0`).
- Networking: Use Bridge Helper to create `br0`, then set `network.bridge` in profiles.
