# VM Profile Templates

**Purpose**: Pre-configured VM templates for quick deployment and wizard field suggestions.

## 📋 Template Types

### 🤖 Intelligent Templates (Recommended)
Auto-detect hardware and optimize settings based on your system.

**Features**:
- `AUTO_DETECT` for CPUs, RAM, storage format, and network bridge
- Intelligent resource allocation based on workload type
- Automatic optimization for your hardware

**Templates**:
- `intelligent-linux-server.json` - Headless servers (web, database, services)
- `intelligent-linux-desktop.json` - GUI Linux distributions
- `intelligent-windows-desktop.json` - Windows desktop/workstation

### 📝 Example Templates
Simple templates for specific distributions with minimal configuration.

**Templates**:
- `example_vm_ubuntu.json` - Ubuntu basic setup
- `example_vm_nixos.json` - NixOS basic setup
- `example_vm_windows.json` - Windows basic setup
- `example_vm_aarch64.json` - ARM64 architecture example
- `example_vm_x86_cet_private.json` - x86 with CET security

### 🎯 Use Case Templates (New!)
Optimized templates for specific workloads and scenarios.

**Templates**:
- `usecase-development.json` - Development environment
- `usecase-database.json` - Database server
- `usecase-webserver.json` - Web application server
- `usecase-container-host.json` - Docker/container host
- `usecase-testing.json` - Testing/CI environment
- `usecase-gaming.json` - Gaming VM with GPU passthrough
- `usecase-minimal.json` - Minimal resource usage

## 🚀 Usage

### In Scripts
```bash
# Process intelligent template
source scripts/lib/intelligent_template_processor.sh
process_intelligent_template vm-profiles/intelligent-linux-server.json output.json

# List available templates
list_available_templates vm-profiles/
```

### In Wizards
Wizards automatically:
1. Load templates from this directory
2. Present options to users
3. Process AUTO_DETECT values
4. Generate final VM configuration

### Manual Use
```bash
# Copy and customize
cp vm-profiles/intelligent-linux-server.json my-vm-config.json

# Edit to override AUTO_DETECT values
nano my-vm-config.json

# Create VM from template
virsh define my-vm-config.json
```

## 📖 Template Fields Reference

### Required Fields
```json
{
  "name": "vm-name",              // VM identifier
  "os": "linux|windows|nixos",    // Operating system type
  "cpus": 2,                      // vCPU count (or "AUTO_DETECT")
  "memory_mb": 4096,              // RAM in MB (or "AUTO_DETECT")
  "disk_gb": 40                   // Disk size in GB
}
```

### Optional Fields
```json
{
  "description": "Human-readable description",
  "disk_format": "qcow2",         // qcow2, raw, or "AUTO_DETECT"
  
  "network": {
    "mode": "nat",                // nat, bridge, host, none
    "bridge": "virbr0"            // Bridge name (or "AUTO_DETECT")
  },
  
  "features": {
    "hugepages": false,           // Enable huge pages for performance
    "vhost_net": true,            // Kernel-based network acceleration
    "memballoon": true,           // Dynamic memory adjustment
    "autostart": false,           // Start VM on host boot
    "cpu_pinning": false          // Pin vCPUs to physical cores
  },
  
  "display": {
    "type": "spice",              // spice, vnc, none
    "heads": 1,                   // Number of monitors
    "headless": false             // Run without display
  },
  
  "limits": {
    "cpu_quota_percent": 200,     // CPU limit (200% = 2 cores)
    "memory_max_mb": 8192         // Maximum memory limit
  },
  
  "storage": {
    "pool": "default",            // Storage pool name
    "cache": "writethrough",      // none, writethrough, writeback
    "io": "native"                // native, threads
  }
}
```

### AUTO_DETECT Values
Replace these placeholders with actual values:
- `"cpus": "AUTO_DETECT"` → Automatically calculated based on host cores
- `"memory_mb": "AUTO_DETECT"` → Calculated based on workload and host RAM
- `"disk_format": "AUTO_DETECT"` → qcow2 for SSD, raw for HDD
- `"bridge": "AUTO_DETECT"` → Default bridge (virbr0, br0, etc.)

## 🎨 Creating Custom Templates

### Step 1: Choose Base Template
```bash
# Start with closest match
cp vm-profiles/intelligent-linux-server.json my-custom-template.json
```

### Step 2: Customize Settings
```json
{
  "name": "my-custom-vm",
  "description": "Custom VM for my specific needs",
  "os": "ubuntu",
  "cpus": "AUTO_DETECT",          // Keep auto-detection
  "memory_mb": 8192,              // Or specify exact value
  "disk_gb": 100,
  "features": {
    "hugepages": true,            // Enable for databases
    "cpu_pinning": true           // Enable for consistent performance
  }
}
```

### Step 3: Add to Repository
```bash
# Save to vm-profiles/
mv my-custom-template.json vm-profiles/custom-myapp.json

# Template is now available in wizards!
```

## 🔧 Wizard Integration

Templates automatically populate wizard fields:

**VM Creation Wizard**:
1. Shows list of templates by category
2. User selects template
3. Wizard pre-fills fields with template values
4. User can override any value
5. AUTO_DETECT values processed on save

**Quick Create**:
```bash
# Use template directly
hv vm-create --template intelligent-linux-server --name webserver01

# Override specific fields
hv vm-create --template intelligent-linux-server \
  --name db01 \
  --memory 16384 \
  --disk 200
```

## 📊 Resource Recommendations

### CPU Allocation
- **Development**: 25-50% of host cores (min 2)
- **Server**: 25-40% of host cores (min 4)
- **Desktop**: 50-75% of host cores (min 2)
- **Database**: 50-75% of host cores (min 4)
- **Gaming**: 75-90% of host cores (min 6)

### Memory Allocation
- **Light workload**: 2GB per vCPU
- **Moderate workload**: 4GB per vCPU
- **Heavy workload**: 8GB per vCPU
- **Database**: 8-16GB per vCPU
- **Container host**: 4-8GB per vCPU

### Storage Format
- **SSD/NVMe**: qcow2 (snapshots, thin provisioning)
- **HDD**: raw (better performance, no overhead)
- **Development**: qcow2 (snapshots useful)
- **Production**: raw (consistency, performance)

## 🎯 Best Practices

### Template Design
1. ✅ Use AUTO_DETECT for maximum compatibility
2. ✅ Include descriptive comments and documentation
3. ✅ Set reasonable defaults that work on most systems
4. ✅ Test template on different hardware
5. ✅ Keep templates focused on specific use cases

### Template Maintenance
1. Review templates quarterly for obsolete settings
2. Update based on user feedback
3. Add new templates for common requests
4. Remove unused templates (archive first)
5. Keep README current with examples

### Security Considerations
1. Default to NAT networking for security
2. Don't enable features unless needed (minimize attack surface)
3. Use reasonable resource limits
4. Document security implications of settings

## 📝 Template Naming Convention

```
[category]-[purpose]-[variant].json

Categories:
- intelligent-*  : Auto-detecting templates
- example_*      : Simple examples
- usecase-*      : Specific use cases
- custom-*       : User custom templates

Examples:
- intelligent-linux-server.json
- usecase-development.json
- custom-myapp-production.json
```

## 🔍 Troubleshooting

**Template not appearing in wizard:**
- Check JSON syntax: `jq . template.json`
- Ensure .json extension
- Verify file permissions (readable)

**AUTO_DETECT not working:**
- Check system_discovery.sh is available
- Run manually: `process_intelligent_template template.json`
- Check logs: `/var/log/hypervisor/template-processing.log`

**Template values incorrect:**
- Review `_detection_notes` in template
- Check hardware detection: `hv discover`
- Override with specific values if needed

## 📚 Additional Resources

- **Creating VMs**: `docs/user-guides/basic-vm-management.md`
- **Wizard Guide**: `docs/WIZARD_GUIDE.md`
- **Performance Tuning**: `docs/reference/PERFORMANCE_TUNING.md`
- **Intelligent Defaults**: Run `hv defaults-demo`

---

**Questions?** See `docs/TROUBLESHOOTING.md` or run `hv help templates`
