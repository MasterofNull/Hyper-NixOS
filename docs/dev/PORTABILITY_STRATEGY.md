# Portability Strategy for Hyper-NixOS

## Executive Summary

This document outlines the comprehensive portability strategy for Hyper-NixOS, ensuring the system can run on diverse hardware, cloud platforms, and architectures while maintaining performance and functionality.

## Portability Goals

1. **Multi-Architecture Support**: x86_64, ARM64, RISC-V
2. **Multi-Platform Support**: Bare metal, VMs, Cloud, Edge devices
3. **Multi-OS Compatibility**: NixOS primary, with paths to other Linux distributions
4. **Hardware Abstraction**: Vendor-agnostic implementations
5. **Cloud-Native Ready**: Kubernetes, Docker, Cloud providers

## Architecture Support

### 1. CPU Architecture Abstraction

```nix
# modules/core/architecture.nix
{ config, lib, pkgs, ... }:

let
  # Detect system architecture
  arch = pkgs.stdenv.hostPlatform.system;
  
  # Architecture-specific configurations
  archConfig = {
    x86_64-linux = {
      kernelModules = [ "kvm-intel" "kvm-amd" ];
      qemuPackage = pkgs.qemu_kvm;
      extraKernelParams = [ "intel_iommu=on" "amd_iommu=on" ];
      supportedFeatures = [ "nested-virt" "pcie-passthrough" "sgx" ];
    };
    
    aarch64-linux = {
      kernelModules = [ "kvm" ];
      qemuPackage = pkgs.qemu;
      extraKernelParams = [ "kvm-arm.mode=protected" ];
      supportedFeatures = [ "nested-virt" "gicv3" ];
    };
    
    riscv64-linux = {
      kernelModules = [ "kvm" ];
      qemuPackage = pkgs.qemu;
      extraKernelParams = [ ];
      supportedFeatures = [ "basic-virt" ];
    };
  };
  
  currentArch = archConfig.${arch} or {
    kernelModules = [];
    qemuPackage = pkgs.qemu;
    extraKernelParams = [];
    supportedFeatures = [];
  };
in
{
  options.hypervisor.portability = {
    enable = lib.mkEnableOption "Enable portability features";
    
    targetArchitectures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ arch ];
      description = "List of target architectures to support";
    };
    
    crossCompilation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cross-compilation support";
    };
  };
  
  config = lib.mkIf config.hypervisor.portability.enable {
    # Architecture-specific kernel modules
    boot.kernelModules = currentArch.kernelModules;
    boot.kernelParams = currentArch.extraKernelParams;
    
    # Architecture-specific QEMU
    virtualisation.libvirtd.package = pkgs.libvirt.override {
      qemu = currentArch.qemuPackage;
    };
    
    # Feature detection
    environment.etc."hypervisor/features.json".text = builtins.toJSON {
      architecture = arch;
      features = currentArch.supportedFeatures;
      emulation = config.hypervisor.portability.targetArchitectures;
    };
  };
}
```

### 2. Portable Binary Format

```rust
// tools/rust-lib/src/portable.rs
//! Portable binary utilities

use std::env;
use std::path::PathBuf;

/// Platform detection
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Platform {
    X86_64Linux,
    Aarch64Linux,
    Riscv64Linux,
    X86_64Darwin,
    Aarch64Darwin,
    Unknown,
}

impl Platform {
    pub fn current() -> Self {
        match (env::consts::ARCH, env::consts::OS) {
            ("x86_64", "linux") => Platform::X86_64Linux,
            ("aarch64", "linux") => Platform::Aarch64Linux,
            ("riscv64", "linux") => Platform::Riscv64Linux,
            ("x86_64", "macos") => Platform::X86_64Darwin,
            ("aarch64", "macos") => Platform::Aarch64Darwin,
            _ => Platform::Unknown,
        }
    }
    
    pub fn is_supported(&self) -> bool {
        !matches!(self, Platform::Unknown)
    }
    
    pub fn supports_kvm(&self) -> bool {
        matches!(self, 
            Platform::X86_64Linux | 
            Platform::Aarch64Linux | 
            Platform::Riscv64Linux
        )
    }
}

/// Portable path resolution
pub struct PortablePaths;

impl PortablePaths {
    pub fn config_dir() -> PathBuf {
        if let Ok(xdg_config) = env::var("XDG_CONFIG_HOME") {
            PathBuf::from(xdg_config).join("hypervisor")
        } else if let Ok(home) = env::var("HOME") {
            PathBuf::from(home).join(".config").join("hypervisor")
        } else {
            PathBuf::from("/etc/hypervisor")
        }
    }
    
    pub fn data_dir() -> PathBuf {
        if let Ok(xdg_data) = env::var("XDG_DATA_HOME") {
            PathBuf::from(xdg_data).join("hypervisor")
        } else if let Ok(home) = env::var("HOME") {
            PathBuf::from(home).join(".local").join("share").join("hypervisor")
        } else {
            PathBuf::from("/var/lib/hypervisor")
        }
    }
    
    pub fn runtime_dir() -> PathBuf {
        if let Ok(xdg_runtime) = env::var("XDG_RUNTIME_DIR") {
            PathBuf::from(xdg_runtime).join("hypervisor")
        } else {
            PathBuf::from("/run/hypervisor")
        }
    }
}

/// CPU feature detection
pub mod cpu {
    pub fn has_virtualization_support() -> bool {
        #[cfg(target_arch = "x86_64")]
        {
            use std::arch::x86_64::*;
            
            // Check for VMX (Intel) or SVM (AMD)
            unsafe {
                let result = __cpuid_count(1, 0);
                let vmx = (result.ecx >> 5) & 1;
                
                let result = __cpuid_count(0x80000001, 0);
                let svm = (result.ecx >> 2) & 1;
                
                vmx == 1 || svm == 1
            }
        }
        
        #[cfg(target_arch = "aarch64")]
        {
            // Check for virtualization extensions
            use std::fs;
            fs::read_to_string("/proc/cpuinfo")
                .map(|content| content.contains("virt"))
                .unwrap_or(false)
        }
        
        #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
        {
            false
        }
    }
}
```

## Container and Cloud Portability

### 1. Container Images

```dockerfile
# Dockerfile.portable
# Multi-stage, multi-arch Dockerfile

# Build stage
FROM --platform=$BUILDPLATFORM rust:1.75 AS rust-builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

WORKDIR /build
COPY tools/rust-lib .

# Cross-compilation setup
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") TARGET="x86_64-unknown-linux-musl" ;; \
    "linux/arm64") TARGET="aarch64-unknown-linux-musl" ;; \
    "linux/riscv64") TARGET="riscv64gc-unknown-linux-musl" ;; \
    *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
    rustup target add $TARGET && \
    cargo build --release --target $TARGET

# Go build stage
FROM --platform=$BUILDPLATFORM golang:1.21 AS go-builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM

WORKDIR /build
COPY api .

# Cross-compilation
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") GOARCH=amd64 ;; \
    "linux/arm64") GOARCH=arm64 ;; \
    "linux/riscv64") GOARCH=riscv64 ;; \
    esac && \
    CGO_ENABLED=0 GOOS=linux GOARCH=$GOARCH go build -o hypervisor-api

# Final stage - minimal image
FROM alpine:3.19
RUN apk add --no-cache libvirt-client qemu-system-x86_64 qemu-system-aarch64

COPY --from=rust-builder /build/target/*/release/hypervisor-* /usr/local/bin/
COPY --from=go-builder /build/hypervisor-api /usr/local/bin/

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/hypervisor-api"]
```

### 2. Kubernetes Deployment

```yaml
# kubernetes/deployment-portable.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: hypervisor-node-agent
  namespace: hypervisor-system
spec:
  selector:
    matchLabels:
      app: hypervisor-agent
  template:
    metadata:
      labels:
        app: hypervisor-agent
    spec:
      nodeSelector:
        # Deploy only on nodes with virtualization support
        feature.node.kubernetes.io/cpu-hardware_virtualization: "true"
      
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      
      hostNetwork: true
      hostPID: true
      
      containers:
      - name: agent
        image: hypervisor/agent:2.0.0
        imagePullPolicy: IfNotPresent
        
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: NODE_ARCH
          value: "$(NODE_ARCH)"
        
        # Architecture detection init container sets NODE_ARCH
        volumeMounts:
        - name: dev
          mountPath: /dev
        - name: sys
          mountPath: /sys
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        
        securityContext:
          privileged: true
          capabilities:
            add:
            - SYS_ADMIN
            - SYS_RESOURCE
            - NET_ADMIN
      
      initContainers:
      - name: arch-detect
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - |
          ARCH=$(uname -m)
          case $ARCH in
            x86_64) echo "amd64" > /shared/arch ;;
            aarch64) echo "arm64" > /shared/arch ;;
            riscv64) echo "riscv64" > /shared/arch ;;
            *) echo "unknown" > /shared/arch ;;
          esac
        volumeMounts:
        - name: shared
          mountPath: /shared
      
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: sys
        hostPath:
          path: /sys
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: shared
        emptyDir: {}
```

## Platform-Agnostic Storage

### 1. Storage Abstraction Layer

```go
// api/internal/storage/portable.go
package storage

import (
    "context"
    "fmt"
    "os"
    "runtime"
)

// StorageBackend interface for portable storage
type StorageBackend interface {
    Create(ctx context.Context, name string, size uint64) error
    Delete(ctx context.Context, name string) error
    Resize(ctx context.Context, name string, newSize uint64) error
    Clone(ctx context.Context, source, dest string) error
    Snapshot(ctx context.Context, name, snapshot string) error
}

// DetectStorageBackend returns appropriate backend for platform
func DetectStorageBackend() (StorageBackend, error) {
    switch runtime.GOOS {
    case "linux":
        return detectLinuxBackend()
    case "darwin":
        return &QemuImgBackend{}, nil
    case "windows":
        return &HyperVBackend{}, nil
    default:
        return nil, fmt.Errorf("unsupported platform: %s", runtime.GOOS)
    }
}

func detectLinuxBackend() (StorageBackend, error) {
    // Check for LVM
    if _, err := os.Stat("/sbin/lvm"); err == nil {
        return &LVMBackend{}, nil
    }
    
    // Check for ZFS
    if _, err := os.Stat("/sbin/zfs"); err == nil {
        return &ZFSBackend{}, nil
    }
    
    // Check for Btrfs
    if _, err := os.Stat("/sbin/btrfs"); err == nil {
        return &BtrfsBackend{}, nil
    }
    
    // Fallback to qemu-img
    return &QemuImgBackend{}, nil
}

// Portable disk formats
type DiskFormat string

const (
    DiskFormatQCOW2 DiskFormat = "qcow2"
    DiskFormatRAW   DiskFormat = "raw"
    DiskFormatVMDK  DiskFormat = "vmdk"
    DiskFormatVDI   DiskFormat = "vdi"
    DiskFormatVHDX  DiskFormat = "vhdx"
)

// GetSupportedFormats returns formats supported on current platform
func GetSupportedFormats() []DiskFormat {
    switch runtime.GOOS {
    case "linux":
        return []DiskFormat{
            DiskFormatQCOW2,
            DiskFormatRAW,
            DiskFormatVMDK,
            DiskFormatVDI,
        }
    case "darwin":
        return []DiskFormat{
            DiskFormatQCOW2,
            DiskFormatRAW,
            DiskFormatVMDK,
        }
    case "windows":
        return []DiskFormat{
            DiskFormatVHDX,
            DiskFormatVMDK,
        }
    default:
        return []DiskFormat{DiskFormatRAW}
    }
}
```

## Network Portability

### 1. Network Abstraction

```rust
// tools/rust-lib/src/network/portable.rs
use std::net::IpAddr;

/// Portable network configuration
#[derive(Debug, Clone)]
pub struct NetworkConfig {
    pub mode: NetworkMode,
    pub bridge: Option<String>,
    pub subnet: Option<String>,
}

#[derive(Debug, Clone, Copy)]
pub enum NetworkMode {
    NAT,
    Bridge,
    Host,
    None,
}

/// Platform-specific network setup
pub trait NetworkProvider {
    fn create_network(&self, config: &NetworkConfig) -> Result<Network, Error>;
    fn delete_network(&self, name: &str) -> Result<(), Error>;
    fn list_networks(&self) -> Result<Vec<Network>, Error>;
}

/// Get appropriate network provider for platform
pub fn get_network_provider() -> Box<dyn NetworkProvider> {
    #[cfg(target_os = "linux")]
    {
        if which::which("ip").is_ok() {
            Box::new(LinuxNetworkProvider::new())
        } else {
            Box::new(LegacyNetworkProvider::new())
        }
    }
    
    #[cfg(target_os = "macos")]
    {
        Box::new(MacOSNetworkProvider::new())
    }
    
    #[cfg(target_os = "freebsd")]
    {
        Box::new(FreeBSDNetworkProvider::new())
    }
    
    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "freebsd")))]
    {
        Box::new(NoOpNetworkProvider::new())
    }
}

/// Portable firewall rules
pub struct FirewallRule {
    pub direction: Direction,
    pub protocol: Protocol,
    pub port: u16,
    pub source: Option<IpAddr>,
}

/// Platform-agnostic firewall interface
pub trait FirewallProvider {
    fn add_rule(&self, rule: &FirewallRule) -> Result<(), Error>;
    fn remove_rule(&self, rule: &FirewallRule) -> Result<(), Error>;
    fn list_rules(&self) -> Result<Vec<FirewallRule>, Error>;
}

pub fn get_firewall_provider() -> Option<Box<dyn FirewallProvider>> {
    #[cfg(target_os = "linux")]
    {
        if which::which("nft").is_ok() {
            Some(Box::new(NftablesProvider::new()))
        } else if which::which("iptables").is_ok() {
            Some(Box::new(IptablesProvider::new()))
        } else {
            None
        }
    }
    
    #[cfg(target_os = "macos")]
    {
        Some(Box::new(PfProvider::new()))
    }
    
    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        None
    }
}
```

## Portable Shell Scripts

### 1. POSIX-Compliant Scripts

```bash
#!/bin/sh
# Portable shell script template
# POSIX-compliant for maximum portability

set -eu

# Portable way to get script directory
SCRIPT_DIR=$(CDPATH="" cd -- "$(dirname -- "$0")" && pwd -P)

# OS detection
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        FreeBSD*)   echo "freebsd" ;;
        OpenBSD*)   echo "openbsd" ;;
        NetBSD*)    echo "netbsd" ;;
        CYGWIN*)    echo "cygwin" ;;
        MINGW*)     echo "mingw" ;;
        *)          echo "unknown" ;;
    esac
}

# Architecture detection
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)    echo "x86_64" ;;
        i?86)            echo "x86" ;;
        aarch64|arm64)   echo "arm64" ;;
        armv7*)          echo "armv7" ;;
        riscv64)         echo "riscv64" ;;
        *)               echo "unknown" ;;
    esac
}

# Distribution detection (Linux only)
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID:-unknown}"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Portable command checking
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Portable temporary directory
make_temp_dir() {
    mktemp -d 2>/dev/null || mktemp -d -t 'hypervisor'
}

# Portable sudo/doas detection
get_sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""
    elif has_command sudo; then
        echo "sudo"
    elif has_command doas; then
        echo "doas"
    else
        echo "su -c"
    fi
}

# Main execution
main() {
    OS=$(detect_os)
    ARCH=$(detect_arch)
    
    echo "Detected OS: $OS"
    echo "Detected Architecture: $ARCH"
    
    if [ "$OS" = "linux" ]; then
        DISTRO=$(detect_distro)
        echo "Detected Distribution: $DISTRO"
    fi
    
    # Platform-specific logic
    case "$OS" in
        linux)
            # Linux-specific code
            ;;
        macos)
            # macOS-specific code
            ;;
        freebsd)
            # FreeBSD-specific code
            ;;
        *)
            echo "Unsupported OS: $OS" >&2
            exit 1
            ;;
    esac
}

main "$@"
```

## WebAssembly for Ultimate Portability

### 1. WASM Components

```rust
// tools/wasm-lib/src/lib.rs
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct PortableVMManager {
    // Internal state
}

#[wasm_bindgen]
impl PortableVMManager {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }
    
    #[wasm_bindgen]
    pub fn list_vms(&self) -> String {
        // Return JSON string of VMs
        serde_json::to_string(&self.get_vms()).unwrap()
    }
    
    #[wasm_bindgen]
    pub fn validate_config(&self, config: &str) -> Result<bool, JsValue> {
        // Validate VM configuration
        match serde_json::from_str::<VMConfig>(config) {
            Ok(cfg) => Ok(self.validate(&cfg)),
            Err(e) => Err(JsValue::from_str(&e.to_string())),
        }
    }
}

// Build with: wasm-pack build --target web
```

## Cloud Provider Abstraction

### 1. Multi-Cloud Support

```go
// api/internal/cloud/provider.go
package cloud

import (
    "context"
)

type CloudProvider interface {
    // Instance management
    CreateInstance(ctx context.Context, spec *InstanceSpec) (*Instance, error)
    DeleteInstance(ctx context.Context, id string) error
    ListInstances(ctx context.Context) ([]*Instance, error)
    
    // Storage
    CreateVolume(ctx context.Context, spec *VolumeSpec) (*Volume, error)
    AttachVolume(ctx context.Context, instanceID, volumeID string) error
    
    // Networking
    CreateNetwork(ctx context.Context, spec *NetworkSpec) (*Network, error)
    
    // Provider info
    GetCapabilities() Capabilities
    GetRegions() []string
}

type ProviderType string

const (
    ProviderAWS        ProviderType = "aws"
    ProviderGCP        ProviderType = "gcp"
    ProviderAzure      ProviderType = "azure"
    ProviderOpenStack  ProviderType = "openstack"
    ProviderVMware     ProviderType = "vmware"
    ProviderProxmox    ProviderType = "proxmox"
    ProviderLocal      ProviderType = "local"
)

func NewProvider(providerType ProviderType, config map[string]string) (CloudProvider, error) {
    switch providerType {
    case ProviderAWS:
        return NewAWSProvider(config)
    case ProviderGCP:
        return NewGCPProvider(config)
    case ProviderAzure:
        return NewAzureProvider(config)
    case ProviderOpenStack:
        return NewOpenStackProvider(config)
    case ProviderLocal:
        return NewLocalProvider(config)
    default:
        return nil, fmt.Errorf("unsupported provider: %s", providerType)
    }
}

// Portable instance specification
type InstanceSpec struct {
    Name         string
    InstanceType string  // Provider-specific mapping
    Image        string  // Provider-specific mapping
    Region       string
    Zone         string
    
    // Portable resource specification
    Resources struct {
        CPUs   int
        Memory int  // MB
        Disk   int  // GB
    }
    
    // Network configuration
    Network struct {
        VPC           string
        Subnet        string
        SecurityGroup string
        PublicIP      bool
    }
    
    // User data (cloud-init)
    UserData string
    
    // Tags/Labels
    Tags map[string]string
}
```

## Testing Portability

### 1. Multi-Platform CI/CD

```yaml
# .github/workflows/portable-ci.yml
name: Portable CI

on: [push, pull_request]

strategy:
  matrix:
    include:
      # Native builds
      - os: ubuntu-latest
        arch: amd64
        target: x86_64-unknown-linux-gnu
      - os: ubuntu-latest
        arch: arm64
        target: aarch64-unknown-linux-gnu
      - os: macos-latest
        arch: amd64
        target: x86_64-apple-darwin
      - os: macos-latest
        arch: arm64
        target: aarch64-apple-darwin
      
      # Cross-compilation
      - os: ubuntu-latest
        arch: riscv64
        target: riscv64gc-unknown-linux-gnu
      - os: ubuntu-latest
        arch: armv7
        target: armv7-unknown-linux-gnueabihf

jobs:
  build:
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: ${{ matrix.target }}
      
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Build Rust components
        run: |
          cd tools/rust-lib
          cargo build --release --target ${{ matrix.target }}
      
      - name: Build Go components
        env:
          GOOS: ${{ matrix.os == 'ubuntu-latest' && 'linux' || 'darwin' }}
          GOARCH: ${{ matrix.arch }}
        run: |
          cd api
          go build -o hypervisor-api
      
      - name: Run tests
        if: matrix.arch == 'amd64'  # Can't run cross-compiled tests
        run: |
          cargo test --all
          go test ./...
      
      - name: Build container
        if: matrix.os == 'ubuntu-latest'
        run: |
          docker buildx build \
            --platform linux/${{ matrix.arch }} \
            --tag hypervisor:${{ matrix.arch }} \
            .
```

## Portability Best Practices

### 1. Code Guidelines

```markdown
# Portability Guidelines

## Language-Specific

### Rust
- Use `cfg` attributes for platform-specific code
- Prefer `std::env` over hardcoded paths
- Use `target_os`, `target_arch` for conditional compilation
- Avoid platform-specific dependencies when possible

### Go
- Use build tags for platform-specific files
- Use `runtime.GOOS` and `runtime.GOARCH`
- Avoid CGO unless absolutely necessary
- Use interfaces for platform-specific implementations

### Shell Scripts
- Use POSIX sh instead of bash when possible
- Avoid GNU-specific extensions
- Test with shellcheck
- Use command -v instead of which

## Path Handling
- Use XDG Base Directory specification
- Never hardcode paths
- Use path.Join() in Go, PathBuf in Rust
- Handle both / and \ as separators

## Dependencies
- Minimize external dependencies
- Use static linking when possible
- Document all system requirements
- Provide fallbacks for optional features

## Testing
- Test on multiple platforms
- Use CI/CD matrix builds
- Test with minimal environments
- Document platform-specific limitations
```

## Conclusion

This portability strategy ensures Hyper-NixOS can run on:
- **Multiple architectures**: x86_64, ARM64, RISC-V
- **Multiple platforms**: Linux, macOS, BSD, Cloud
- **Multiple environments**: Bare metal, VMs, Containers, Kubernetes
- **Multiple distributions**: NixOS, Debian, RHEL, etc.

The key principles are:
1. **Abstraction layers** for platform-specific features
2. **Runtime detection** of capabilities
3. **Graceful degradation** when features unavailable
4. **Standard interfaces** (POSIX, OCI, etc.)
5. **Comprehensive testing** across platforms