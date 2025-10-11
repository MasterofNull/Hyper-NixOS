# VM Recipe Cookbook

This cookbook provides ready-to-use VM configurations for common use cases. Copy and customize these profiles for your needs.

---

## 🎮 Windows 11 Gaming VM with GPU Passthrough

Perfect for gaming, CAD, or any GPU-intensive Windows applications.

### Profile: `/var/lib/hypervisor/vm_profiles/windows11-gaming.json`

```json
{
  "name": "windows11-gaming",
  "cpus": 8,
  "memory_mb": 16384,
  "disk_gb": 250,
  "iso_path": "/var/lib/hypervisor/isos/Win11_23H2_EnglishInternational_x64.iso",
  "network": {
    "type": "bridge",
    "bridge": "br0",
    "model": "e1000e"
  },
  "cpu_model": "host-passthrough",
  "cpu_pinning": [
    {"vcpu": 0, "hostcpu": 2},
    {"vcpu": 1, "hostcpu": 3},
    {"vcpu": 2, "hostcpu": 4},
    {"vcpu": 3, "hostcpu": 5},
    {"vcpu": 4, "hostcpu": 6},
    {"vcpu": 5, "hostcpu": 7},
    {"vcpu": 6, "hostcpu": 8},
    {"vcpu": 7, "hostcpu": 9}
  ],
  "hugepages": true,
  "hostdevs": [
    {
      "type": "pci",
      "domain": "0x0000",
      "bus": "0x01",
      "slot": "0x00",
      "function": "0x0"
    },
    {
      "type": "pci",
      "domain": "0x0000",
      "bus": "0x01",
      "slot": "0x00",
      "function": "0x1"
    }
  ],
  "looking_glass": {
    "enabled": true,
    "size_mb": 64
  },
  "usb_controller": true,
  "tpm": true,
  "boot_order": ["hd", "cdrom"],
  "features": {
    "hyperv": true
  }
}
```

### Setup Instructions

1. **Enable IOMMU in BIOS**
   - Intel: Enable VT-d
   - AMD: Enable AMD-Vi

2. **Configure VFIO**
   ```bash
   # Run VFIO workflow from menu
   # Or manually bind GPU
   ```

3. **Install Windows**
   - Boot from ISO
   - Skip product key
   - Choose Windows 11 Pro
   - Create local account

4. **Post-Install**
   - Install virtio drivers
   - Install GPU drivers
   - Install Looking Glass host
   - Enable Remote Desktop

### Performance Tips
- Isolate CPU cores from host
- Use MSI interrupts
- Disable Windows animations
- Set power plan to High Performance

---

## 🖥️ Ubuntu Server with Cloud-Init

Ideal for development servers, web hosting, or containerized workloads.

### Profile: `/var/lib/hypervisor/vm_profiles/ubuntu-server.json`

```json
{
  "name": "ubuntu-server",
  "cpus": 4,
  "memory_mb": 4096,
  "disk_gb": 50,
  "disk_image_path": "/var/lib/hypervisor/images/ubuntu-22.04-server-cloudimg-amd64.img",
  "cloud_init": {
    "seed_iso_path": "/var/lib/hypervisor/seeds/ubuntu-server-seed.iso"
  },
  "network": {
    "type": "default",
    "model": "virtio"
  },
  "cpu_model": "host-model",
  "serial_console": true,
  "autostart": true,
  "boot_order": ["hd"]
}
```

### Cloud-Init User Data: `/tmp/user-data`

```yaml
#cloud-config
hostname: ubuntu-server
manage_etc_hosts: true

users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa YOUR_SSH_PUBLIC_KEY_HERE

packages:
  - docker.io
  - docker-compose
  - nginx
  - certbot
  - python3-certbot-nginx
  - htop
  - ncdu
  - net-tools

runcmd:
  - systemctl enable docker
  - usermod -aG docker admin
  - ufw allow OpenSSH
  - ufw allow 'Nginx Full'
  - ufw --force enable

final_message: "Ubuntu server ready after $UPTIME seconds"
```

### Setup Instructions

1. **Download Cloud Image**
   ```bash
   # From menu: Cloud image manager
   # Download Ubuntu 22.04 Server
   ```

2. **Create Cloud-Init Seed**
   ```bash
   # Create user-data and meta-data
   /etc/hypervisor/scripts/cloud_init_seed.sh \
     /tmp/user-data \
     /tmp/meta-data \
     /var/lib/hypervisor/seeds/ubuntu-server-seed.iso
   ```

3. **Start VM**
   - VM will auto-configure on first boot
   - SSH will be available in ~60 seconds

---

## 🔒 Secure Isolated Test Environment

For malware analysis, penetration testing, or running untrusted code.

### Profile: `/var/lib/hypervisor/vm_profiles/secure-sandbox.json`

```json
{
  "name": "secure-sandbox",
  "cpus": 2,
  "memory_mb": 2048,
  "disk_gb": 20,
  "iso_path": "/var/lib/hypervisor/isos/kali-linux-2023.3-installer-amd64.iso",
  "network": {
    "type": "isolated",
    "zone": "untrusted"
  },
  "graphics": {
    "type": "spice",
    "listen": "none"
  },
  "features": {
    "acpi": false,
    "apic": false
  },
  "memory_backend": {
    "locked": true,
    "nosharepages": true
  },
  "cpu_features": {
    "disable": ["svm", "vmx"]
  },
  "sandbox": {
    "seccomp": true
  }
}
```

### Network Zone Configuration

```bash
# Create isolated network zone
/etc/hypervisor/scripts/zone_manager.sh create untrusted \
  --no-internet \
  --no-host-access \
  --inter-vm-only
```

### Security Notes
- No internet access by default
- No shared clipboard/folders
- Nested virtualization disabled
- Memory locked and not shared
- Strict AppArmor profile

---

## 🧪 Multi-VM Development Lab

Complete development environment with database, cache, and application servers.

### Database Server: `dev-postgres.json`

```json
{
  "name": "dev-postgres",
  "cpus": 2,
  "memory_mb": 4096,
  "disk_gb": 100,
  "disk_image_path": "/var/lib/hypervisor/images/debian-12-generic-amd64.qcow2",
  "network": {
    "type": "bridge",
    "bridge": "br-dev",
    "model": "virtio",
    "mac": "52:54:00:12:34:01"
  },
  "autostart": true,
  "autostart_priority": 10,
  "boot_order": ["hd"]
}
```

### Redis Cache: `dev-redis.json`

```json
{
  "name": "dev-redis",
  "cpus": 1,
  "memory_mb": 1024,
  "disk_gb": 10,
  "disk_image_path": "/var/lib/hypervisor/images/alpine-virt-3.18.qcow2",
  "network": {
    "type": "bridge",
    "bridge": "br-dev",
    "model": "virtio",
    "mac": "52:54:00:12:34:02"
  },
  "autostart": true,
  "autostart_priority": 20,
  "memory_backend": {
    "hugepages": true
  }
}
```

### App Server: `dev-app.json`

```json
{
  "name": "dev-app",
  "cpus": 4,
  "memory_mb": 8192,
  "disk_gb": 50,
  "disk_image_path": "/var/lib/hypervisor/images/ubuntu-22.04-server-cloudimg-amd64.img",
  "cloud_init": {
    "seed_iso_path": "/var/lib/hypervisor/seeds/dev-app-seed.iso"
  },
  "network": {
    "type": "bridge",
    "bridge": "br-dev",
    "model": "virtio",
    "mac": "52:54:00:12:34:03"
  },
  "autostart": true,
  "autostart_priority": 30,
  "extra_disks": [
    {
      "path": "/var/lib/hypervisor/disks/dev-app-data.qcow2",
      "size_gb": 100,
      "bus": "virtio"
    }
  ]
}
```

### Setup Script

```bash
#!/bin/bash
# setup-dev-lab.sh

# Create development bridge
sudo /etc/hypervisor/scripts/bridge_helper.sh create br-dev 192.168.100.1/24

# Create VMs
for profile in dev-postgres dev-redis dev-app; do
  /etc/hypervisor/scripts/json_to_libvirt_xml_and_define.sh \
    "/var/lib/hypervisor/vm_profiles/${profile}.json"
done

# Start in order (respects autostart_priority)
virsh start dev-postgres
sleep 10
virsh start dev-redis
sleep 5
virsh start dev-app
```

---

## 🏠 Home Assistant OS

Smart home automation platform.

### Profile: `/var/lib/hypervisor/vm_profiles/homeassistant.json`

```json
{
  "name": "homeassistant",
  "cpus": 2,
  "memory_mb": 4096,
  "disk_image_path": "/var/lib/hypervisor/images/haos_ova-10.5.qcow2",
  "network": {
    "type": "bridge",
    "bridge": "br0",
    "model": "virtio"
  },
  "usb_passthrough": [
    {
      "vendor": "0x0658",
      "product": "0x0200"
    }
  ],
  "autostart": true,
  "boot_order": ["hd"],
  "uefi": true
}
```

### Setup Notes
- Download HAOS image from official site
- USB passthrough for Zigbee/Z-Wave dongles
- Bridge network for device discovery
- Access at http://homeassistant.local:8123

---

## 📊 Monitoring Stack (Prometheus + Grafana)

### Profile: `/var/lib/hypervisor/vm_profiles/monitoring.json`

```json
{
  "name": "monitoring",
  "cpus": 2,
  "memory_mb": 4096,
  "disk_gb": 100,
  "disk_image_path": "/var/lib/hypervisor/images/debian-12-generic-amd64.qcow2",
  "cloud_init": {
    "seed_iso_path": "/var/lib/hypervisor/seeds/monitoring-seed.iso"
  },
  "network": {
    "type": "default",
    "model": "virtio"
  },
  "autostart": true,
  "extra_disks": [
    {
      "path": "/var/lib/hypervisor/disks/monitoring-data.qcow2",
      "size_gb": 500,
      "bus": "virtio"
    }
  ]
}
```

### Docker Compose Setup

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=90d'

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  node_exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus_data:
  grafana_data:
```

---

## 💾 NAS/File Server

Simple file server with Samba shares.

### Profile: `/var/lib/hypervisor/vm_profiles/nas.json`

```json
{
  "name": "nas",
  "cpus": 2,
  "memory_mb": 2048,
  "disk_gb": 50,
  "disk_image_path": "/var/lib/hypervisor/images/truenas-scale.qcow2",
  "network": {
    "type": "bridge",
    "bridge": "br0",
    "model": "virtio"
  },
  "autostart": true,
  "boot_order": ["hd"],
  "extra_disks": [
    {
      "path": "/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K0CPJ3K3",
      "bus": "virtio",
      "raw": true
    },
    {
      "path": "/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K0CPJ3K4",
      "bus": "virtio",
      "raw": true
    }
  ]
}
```

---

## 🌐 Router/Firewall (pfSense)

Virtual router with multiple network interfaces.

### Profile: `/var/lib/hypervisor/vm_profiles/pfsense.json`

```json
{
  "name": "pfsense",
  "cpus": 2,
  "memory_mb": 2048,
  "disk_gb": 20,
  "iso_path": "/var/lib/hypervisor/isos/pfSense-CE-2.7.0-amd64.iso",
  "networks": [
    {
      "type": "bridge",
      "bridge": "br-wan",
      "model": "virtio",
      "mac": "52:54:00:WA:N0:01"
    },
    {
      "type": "bridge",
      "bridge": "br-lan",
      "model": "virtio",
      "mac": "52:54:00:LA:N0:01"
    }
  ],
  "autostart": true,
  "autostart_priority": 1,
  "boot_order": ["hd", "cdrom"],
  "serial_console": true
}
```

---

## Tips for Creating Your Own Recipes

1. **Start with Templates**
   - Use existing recipes as starting points
   - Modify CPU, memory, and disk to suit needs

2. **Performance Optimization**
   - Use virtio drivers when possible
   - Enable hugepages for memory-intensive VMs
   - Pin CPUs for consistent performance

3. **Security Considerations**
   - Use network zones to isolate VMs
   - Enable TPM for Windows 11
   - Lock memory for sensitive workloads

4. **Automation**
   - Use cloud-init for Linux VMs
   - Create seed ISOs with configuration
   - Set autostart priorities for dependencies

5. **Resource Planning**
   - Don't overcommit CPU cores
   - Leave headroom for memory
   - Monitor disk I/O patterns

Remember: These are starting points. Customize based on your hardware and requirements!