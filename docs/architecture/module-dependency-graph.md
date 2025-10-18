# Module Dependency Graph

Visual representation of Hyper-NixOS module dependencies and relationships.

## Core System Architecture

```mermaid
graph TD
    A[configuration.nix] --> B[Core Modules]
    A --> C[Security Modules]
    A --> D[Virtualization Modules]
    A --> E[Feature Modules]
    A --> F[GUI Modules]
    A --> G[Enterprise Modules]

    B --> B1[options.nix]
    B --> B2[packages.nix]
    B --> B3[system-detection.nix]
    B --> B4[arm-detection.nix]
    B --> B5[first-boot.nix]

    C --> C1[password-protection.nix]
    C --> C2[privilege-separation.nix]
    C --> C3[threat-detection.nix]
    C --> C4[profiles.nix]
    C --> C5[firewall.nix]
    C --> C6[polkit-rules.nix]

    D --> D1[libvirt.nix]
    D --> D2[performance.nix]
    D --> D3[networking.nix]
    D --> D4[gpu-passthrough.nix]

    E --> E1[feature-manager.nix]
    E --> E2[feature-categories.nix]
    E --> E3[progress-tracking.nix]

    style A fill:#4a90e2,color:#fff
    style B fill:#7ed321,color:#fff
    style C fill:#f5a623,color:#fff
    style D fill:#bd10e0,color:#fff
    style E fill:#50e3c2,color:#fff
```

## Module Import Flow

```mermaid
flowchart LR
    START[System Boot] --> HW[Hardware Detection]
    HW --> SD[system-detection.nix]
    SD --> ARM{ARM Platform?}

    ARM -->|Yes| ARMD[arm-detection.nix]
    ARM -->|No| X86[x86 Configuration]

    ARMD --> OPT[Load Options]
    X86 --> OPT

    OPT --> TIER{System Tier}

    TIER -->|Minimal| MIN[Minimal Features]
    TIER -->|Enhanced| ENH[Enhanced Features]
    TIER -->|Complete| COMP[Complete Features]

    MIN --> SEC[Security Layer]
    ENH --> SEC
    COMP --> SEC

    SEC --> VIRT[Virtualization Layer]
    VIRT --> BOOT[Boot System]

    style START fill:#4a90e2,color:#fff
    style HW fill:#7ed321,color:#fff
    style SEC fill:#f5a623,color:#fff
    style VIRT fill:#bd10e0,color:#fff
    style BOOT fill:#50e3c2,color:#fff
```

## Feature Dependencies

```mermaid
graph LR
    FM[Feature Manager] --> VM[VM Management]
    FM --> NET[Networking]
    FM --> SEC[Security]
    FM --> MON[Monitoring]
    FM --> STOR[Storage]

    VM --> LIBV[libvirtd]
    VM --> QEMU[QEMU/KVM]

    NET --> BR[Bridges]
    NET --> VLAN[VLANs]
    NET --> FW[Firewall]

    SEC --> PS[Privilege Separation]
    SEC --> PP[Password Protection]
    SEC --> TD[Threat Detection]

    MON --> PROM[Prometheus]
    MON --> GRAF[Grafana]
    MON --> LOG[Logging]

    STOR --> POOL[Storage Pools]
    STOR --> TIER[Tiered Storage]

    style FM fill:#4a90e2,color:#fff
    style LIBV fill:#7ed321,color:#fff
    style PS fill:#f5a623,color:#fff
```

## Security Module Relationships

```mermaid
graph TD
    SP[Security Profiles] --> BASE[Baseline]
    SP --> STRICT[Strict]
    SP --> PARA[Paranoid]

    BASE --> FW1[Basic Firewall]
    BASE --> AUDIT1[Basic Audit]

    STRICT --> FW2[Advanced Firewall]
    STRICT --> AUDIT2[Full Audit]
    STRICT --> TD[Threat Detection]

    PARA --> FW3[Locked Firewall]
    PARA --> AUDIT3[Verbose Audit]
    PARA --> TD2[Active Response]
    PARA --> ISO[Network Isolation]

    ALL[All Profiles] --> PP[Password Protection]
    ALL --> PS[Privilege Separation]

    PP --> PWD[Password Manager]
    PS --> POL[Polkit Rules]
    PS --> GRP[User Groups]

    style SP fill:#f5a623,color:#fff
    style PP fill:#d0021b,color:#fff
    style PS fill:#d0021b,color:#fff
```

## Virtualization Stack

```mermaid
graph TB
    USER[User/CLI] --> HV[hv Command]
    HV --> WIZ[Wizards]
    HV --> VIRSH[virsh]

    WIZ --> LIBV[libvirtd]
    VIRSH --> LIBV

    LIBV --> QEMU[QEMU/KVM]
    LIBV --> NET[Network Config]
    LIBV --> STOR[Storage Config]

    QEMU --> VM1[VM 1]
    QEMU --> VM2[VM 2]
    QEMU --> VMN[VM N]

    NET --> BR[Bridge/NAT]
    STOR --> IMG[Disk Images]

    BR --> VNET[Virtual Network]
    IMG --> POOL[Storage Pools]

    style USER fill:#4a90e2,color:#fff
    style LIBV fill:#7ed321,color:#fff
    style QEMU fill:#bd10e0,color:#fff
```

## Configuration Flow

```mermaid
sequenceDiagram
    participant User
    participant Wizard
    participant State
    participant NixOS
    participant System

    User->>Wizard: Run hv command
    Wizard->>State: Initialize wizard state
    Wizard->>User: Show educational content
    User->>Wizard: Make selections
    Wizard->>State: Track changes
    Wizard->>NixOS: Update configuration.nix
    Wizard->>State: Commit state
    User->>System: nixos-rebuild switch
    System->>NixOS: Apply configuration
    System->>User: System updated

    alt Error Occurs
        Wizard->>State: Detect failure
        State->>System: Rollback changes
        State->>User: Show error + rollback
    end
```

## Educational Flow

```mermaid
graph LR
    START[User Starts] --> DISC[hv discover]
    DISC --> TIER[Select Tier]
    TIER --> BOOT[First Boot Wizard]

    BOOT --> VM[Create First VM]
    VM --> PROG1[Progress Tracked]

    PROG1 --> NET[Network Config]
    NET --> PROG2[Progress Tracked]

    PROG2 --> SEC[Security Config]
    SEC --> PROG3[Progress Tracked]

    PROG3 --> ACH{Achievement?}

    ACH -->|10 items| BADGE1[Novice Navigator 🏅]
    ACH -->|25 items| BADGE2[Competent Curator 🌟]
    ACH -->|50 items| BADGE3[Advanced Architect 🚀]

    BADGE3 --> ADV[Advanced Features]

    style START fill:#4a90e2,color:#fff
    style PROG1 fill:#50e3c2,color:#fff
    style PROG2 fill:#50e3c2,color:#fff
    style PROG3 fill:#50e3c2,color:#fff
    style BADGE3 fill:#7ed321,color:#fff
```

## Data Flow

```mermaid
graph LR
    VM[Virtual Machines] --> METRICS[Metrics Collection]
    VM --> LOGS[Log Collection]

    METRICS --> PROM[Prometheus]
    LOGS --> SYSLOG[Syslog]

    PROM --> GRAF[Grafana]
    PROM --> ALERT[Alertmanager]

    SYSLOG --> LOGROT[Log Rotation]
    SYSLOG --> AUDIT[Audit System]

    GRAF --> USER[User Dashboard]
    ALERT --> USER

    AUDIT --> SEC[Security Analysis]
    SEC --> THREAT[Threat Detection]

    THREAT -->|Anomaly| ALERT

    style VM fill:#bd10e0,color:#fff
    style PROM fill:#e6522c,color:#fff
    style GRAF fill:#f46800,color:#fff
    style THREAT fill:#d0021b,color:#fff
```

## Deployment Architecture (Enterprise)

```mermaid
graph TB
    LB[Load Balancer] --> NODE1[Node 1]
    LB --> NODE2[Node 2]
    LB --> NODE3[Node 3]

    NODE1 --> CEPH1[Ceph Storage]
    NODE2 --> CEPH1
    NODE3 --> CEPH1

    NODE1 --> NET1[Network Mesh]
    NODE2 --> NET1
    NODE3 --> NET1

    CEPH1 --> TIER1[Hot Tier SSD]
    CEPH1 --> TIER2[Warm Tier HDD]
    CEPH1 --> TIER3[Cold Tier Archive]

    MGT[Management] --> NODE1
    MGT --> NODE2
    MGT --> NODE3

    MON[Monitoring] --> MGT

    style LB fill:#4a90e2,color:#fff
    style CEPH1 fill:#50e3c2,color:#fff
    style MGT fill:#f5a623,color:#fff
```

## Notes

### Critical Paths

1. **Boot Flow**: hardware-configuration.nix → system-detection.nix → options.nix → feature-manager.nix
2. **Security**: password-protection.nix MUST load before any user configuration
3. **Virtualization**: libvirt.nix → performance.nix → networking.nix

### Circular Dependencies to Avoid

- ❌ Do NOT access `config.*` in module `let` bindings before `options` definition
- ❌ Do NOT create mutual imports between security modules
- ✅ Use `mkIf` for conditional configuration
- ✅ Define options before accessing config

### Best Practices

1. **Module Organization**: Group related functionality
2. **Dependency Order**: Core → Security → Features → Services
3. **Conditional Loading**: Use `mkIf` with clear conditions
4. **Documentation**: Comment complex dependencies

## See Also

- [PLATFORM-OVERVIEW.md](../dev/PLATFORM-OVERVIEW.md)
- [DESIGN-ETHOS.md](../dev/DESIGN-ETHOS.md)
- Individual module documentation in `/modules/*/README.md`
