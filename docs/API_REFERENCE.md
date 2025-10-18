# Hyper-NixOS GraphQL API Reference

Event-driven API with real-time subscription support for managing compute units, storage tiers, clustering, security, and backups.

## Overview

The Hyper-NixOS API uses GraphQL to provide:
- **Queries**: Read data and system state
- **Mutations**: Modify system configuration
- **Subscriptions**: Real-time event streams

**API Endpoint**: `http://localhost:8080/graphql`
**WebSocket (Subscriptions)**: `ws://localhost:8080/graphql`

**Schema Location**: `/api/graphql/schema.graphql`

## Quick Start

### Example Query: List Compute Units

```graphql
query {
  computeUnits(limit: 10) {
    id
    uuid
    tags
    status {
      state
      health
    }
    resources {
      compute {
        units
        architecture
      }
      memory {
        size
      }
    }
  }
}
```

### Example Mutation: Create VM

```graphql
mutation {
  createComputeUnit(input: {
    labels: {name: "web-server", environment: "production"}
    tags: ["web", "nginx"]
    resources: {
      compute: {units: 2, architecture: X86_64}
      memory: {size: "4G"}
    }
    workload: {
      type: PERSISTENT
      sla: {availability: 99.9}
    }
  }) {
    id
    status {
      state
    }
  }
}
```

### Example Subscription: Monitor VM State

```graphql
subscription {
  computeUnitStateChanged {
    id
    status {
      state
      health
    }
  }
}
```

## Core Concepts

### 1. Compute Units

Tag-based compute abstractions (VMs, containers, etc.)

**Key Features**:
- Label-based selection (`labels: {env: "prod"}`)
- Multi-architecture support (x86_64, ARM64, RISC-V, WASM)
- Workload profiles (CPU/Memory/IO intensive)
- SLA specifications
- Placement affinity rules

**Common Operations**:
- `computeUnits(filter:...)` - List VMs
- `createComputeUnit(...)` - Create new VM
- `controlComputeUnit(id, action: START)` - Start/stop VM
- `computeUnitStateChanged` subscription - Monitor changes

### 2. Storage Tiers

Heat-map driven multi-tier storage

**Tiers**:
- **Tier 0**: Memory (RAM cache)
- **Tier 1**: NVMe Local (hot data)
- **Tier 2**: SSD Array (warm data)
- **Tier 3**: HDD Array (cold data)
- **Tier 4**: Object Storage (archive)
- **Tier 5**: Tape/Optical (deep archive)

**Common Operations**:
- `storageTiers` - List all tiers
- `heatMap(tier: 1)` - Get access heat map
- `moveData(source, tier)` - Move between tiers
- `storageTierUpdated` subscription - Monitor tier changes

### 3. Mesh Clustering

Distributed cluster management

**Node Roles**:
- **CONTROLLER**: Cluster management
- **WORKER**: Compute execution
- **STORAGE**: Storage provider
- **EDGE**: Edge computing
- **WITNESS**: Consensus participant

**Common Operations**:
- `meshNodes(roles: [WORKER])` - List nodes
- `joinCluster(...)` - Add node to cluster
- `consensusState` - Get consensus status
- `meshTopologyChanged` subscription - Topology events

### 4. Security (Capability-Based)

Fine-grained capability-based access control

**Capabilities**:
- Resource permissions (compute, storage, network, cluster)
- Temporal access (time windows, expiration)
- Delegation rights
- Conditional access

**Common Operations**:
- `capabilities` - List available capabilities
- `grantCapability(...)` - Grant access
- `checkAccess(principal, operation, resource)` - Verify permission
- `securityAlert(severity: ERROR)` subscription - Security events

### 5. Backup & Recovery

Advanced backup with deduplication

**Features**:
- Content-defined deduplication
- Incremental forever mode
- Progressive retention
- Immutable backups
- Geo-restrictions

**Common Operations**:
- `backupRepositories` - List repositories
- `startBackup(source)` - Initiate backup
- `restoreBackup(backupId, target)` - Restore data
- `backupProgress(source)` subscription - Monitor progress

## API Patterns

### Filtering and Pagination

```graphql
query {
  computeUnits(
    filter: {
      labels: {environment: "production"}
      state: RUNNING
      workloadType: PERSISTENT
    }
    limit: 20
    offset: 0
  ) {
    id
    tags
  }
}
```

### Subscription with Filters

```graphql
subscription {
  systemEvent(
    type: COMPUTE_STATE_CHANGED
    severity: ERROR
  ) {
    id
    timestamp
    message
    metadata
  }
}
```

### Job Monitoring

```graphql
mutation {
  startBackup(source: "db-server") {
    id
    type
    status
  }
}

subscription {
  jobProgress(jobId: "job-123") {
    job {
      status
      progress
    }
    details
  }
}
```

## Complete API Sections

### Queries

- **Compute**: `computeUnit`, `computeUnits`
- **Storage**: `storageTier`, `storageTiers`, `heatMap`
- **Mesh**: `meshNode`, `meshNodes`, `consensusState`
- **Security**: `capability`, `capabilities`, `principal`, `principals`, `checkAccess`
- **Backup**: `backupRepository`, `backupRepositories`, `backupSource`, `backupSources`, `backupHistory`
- **System**: `systemStatus`, `events`

### Mutations

- **Compute**: `createComputeUnit`, `updateComputeUnit`, `deleteComputeUnit`, `controlComputeUnit`
- **Storage**: `moveData`, `createStorageTier`, `updateStorageTier`
- **Mesh**: `joinCluster`, `leaveCluster`, `updateNodeRoles`
- **Security**: `createCapability`, `grantCapability`, `revokeCapability`, `createPrincipal`
- **Backup**: `createBackupRepository`, `createBackupSource`, `startBackup`, `restoreBackup`, `verifyBackup`

### Subscriptions

- **Compute**: `computeUnitUpdated`, `computeUnitStateChanged`
- **Storage**: `storageTierUpdated`, `dataMovement`
- **Mesh**: `meshTopologyChanged`, `consensusStateChanged`, `nodeStatusChanged`
- **Security**: `capabilityGranted`, `capabilityRevoked`, `securityAlert`
- **Backup**: `backupProgress`, `backupCompleted`
- **System**: `systemEvent`, `jobProgress`

## Architecture Support

```graphql
enum Architecture {
  X86_64      # Intel/AMD x86-64
  AARCH64     # ARM 64-bit (Raspberry Pi, etc.)
  RISCV64     # RISC-V 64-bit
  WASM        # WebAssembly
}
```

ARM support is fully integrated - see [ARM_SUPPORT.md](ARM_SUPPORT.md)

## Security Model

### Capability-Based Access

```graphql
type Capability {
  name: String!
  description: String!
  resources: ResourcePermissions!  # What you can access
  operations: [String!]!           # What you can do
  delegation: DelegationRights!    # Can you grant to others
  conditions: [CapabilityCondition!]!  # Time, location, etc.
}
```

### Temporal Access

```graphql
type TemporalAccess {
  validity: ValidityPeriod        # Start/end time
  schedule: AccessSchedule        # Time windows (e.g., business hours)
  usage: UsageLimits              # Max uses, rate limits
  emergency: EmergencyAccess!     # Break-glass procedures
}
```

### Example: Grant Time-Limited Access

```graphql
mutation {
  grantCapability(input: {
    principal: "user-123"
    capability: "vm-operator"
    temporal: {
      validity: {
        duration: "8h"  # 8 hour access
      }
      usage: {
        maxUses: 10     # Can use 10 times
      }
    }
    scope: {
      labels: {project: "web-tier"}  # Only web-tier VMs
    }
  }) {
    capability
    temporal {
      validity {
        end
      }
    }
  }
}
```

## Event System

### Event Types

```graphql
enum EventType {
  COMPUTE_CREATED
  COMPUTE_UPDATED
  COMPUTE_DELETED
  COMPUTE_STATE_CHANGED
  STORAGE_TIER_CHANGED
  NODE_JOINED
  NODE_LEFT
  CONSENSUS_LEADER_CHANGED
  CAPABILITY_GRANTED
  CAPABILITY_REVOKED
  BACKUP_STARTED
  BACKUP_COMPLETED
  BACKUP_FAILED
}
```

### Subscribe to All Events

```graphql
subscription {
  systemEvent {
    id
    timestamp
    type
    severity
    source
    message
    metadata
  }
}
```

## Client Libraries

### Using curl

```bash
curl -X POST http://localhost:8080/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ systemStatus { version health } }"}'
```

### Using GraphQL Playground

Navigate to: `http://localhost:8080/graphql`

### Using Apollo Client (JavaScript)

```javascript
import { ApolloClient, InMemoryCache, gql } from '@apollo/client';

const client = new ApolloClient({
  uri: 'http://localhost:8080/graphql',
  cache: new InMemoryCache()
});

const GET_VMS = gql`
  query {
    computeUnits {
      id
      tags
      status { state health }
    }
  }
`;

const { data } = await client.query({ query: GET_VMS });
```

## Error Handling

GraphQL errors are returned in standard format:

```json
{
  "errors": [
    {
      "message": "Compute unit not found",
      "locations": [{"line": 2, "column": 3}],
      "path": ["computeUnit"]
    }
  ],
  "data": null
}
```

## Rate Limiting

API includes built-in rate limiting:
- Default: 100 requests/minute per client
- Configurable per capability
- Break-glass access bypasses limits (with audit)

## Monitoring & Metrics

The API exports Prometheus metrics:
- `hypervisor_api_requests_total` - Request counter
- `hypervisor_api_request_duration_seconds` - Request latency
- `hypervisor_api_active_subscriptions` - Active WebSocket connections

## Further Reading

- **GraphQL Schema**: `/api/graphql/schema.graphql`
- **Architecture**: [PLATFORM-OVERVIEW.md](dev/PLATFORM-OVERVIEW.md)
- **Security Guide**: [SECURITY-FEATURES-USER-GUIDE.md](user-guides/SECURITY-FEATURES-USER-GUIDE.md)
- **ARM Support**: [ARM_SUPPORT.md](ARM_SUPPORT.md)

## Support

- **Issues**: GitHub Issues
- **API Questions**: GitHub Discussions
- **Schema Reference**: View in GraphQL Playground
