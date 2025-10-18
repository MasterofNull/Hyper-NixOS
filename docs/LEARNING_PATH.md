# Hyper-NixOS Learning Path

Transform from novice to expert through our structured, hands-on curriculum.

## Overview

This learning path guides you through progressive mastery of Hyper-NixOS with four comprehensive levels:

- **Level 1: Foundations** (2-4 hours) - Installation and first VM
- **Level 2: Daily Operations** (4-8 hours) - VM management and basic security
- **Level 3: Advanced Features** (8-16 hours) - Clustering, storage tiers, monitoring
- **Level 4: Expert Mastery** (16+ hours) - Architecture, optimization, production deployment

Each level builds on previous knowledge with hands-on tutorials and real-world scenarios.

---

## 🎯 How to Use This Guide

### Progress Tracking

Your progress is automatically tracked! Run:
```bash
hv-track-progress show          # See recent activity
hv-track-progress stats         # Full statistics
hv-track-progress achievements  # View achievements
```

### Achievements

Earn badges as you learn:
- 🏅 **Novice Navigator** - Complete 10 items
- 🌟 **Competent Curator** - Complete 25 items
- 🚀 **Advanced Architect** - Complete 50 items
- 💎 **Master Virtualist** - Complete 100 items

Plus category-specific achievements for networking, security, VMs, and more!

### Learning Schedule

**Intensive Track (1 week)**
- Day 1-2: Level 1
- Days 3-4: Level 2
- Days 5-6: Level 3
- Day 7: Level 4

**Casual Track (1 month)**
- Week 1: Level 1
- Week 2: Level 2
- Week 3: Level 3
- Week 4: Level 4

**Self-Paced**
- Complete each level's checkpoint before advancing
- No rush - understanding > speed

---

## Level 1: Foundations (Novice → Familiar)

**Goal**: Successfully install Hyper-NixOS and create your first VM

### 1.1 Installation (30-45 minutes)

**Read**:
- [QUICK_START.md](QUICK_START.md) - Fast track installation
- [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) - Detailed installation

**Practice**:
```bash
# Run the installer
sudo ./install.sh

# Complete first-boot wizard
# This runs automatically on first boot

# Verify installation
hv discover
```

**Checkpoint**: ✓ System boots and you can log in

**What You Learned**:
- NixOS declarative configuration
- Hyper-NixOS system tiers
- Hardware capability detection

**Transferable Skills**:
- Linux installation process (works similarly on Ubuntu, Debian, Fedora)
- System discovery techniques

---

### 1.2 Understanding the System (45 minutes)

**Read**:
- [PLATFORM-OVERVIEW.md](dev/PLATFORM-OVERVIEW.md) - Architecture overview
- [DESIGN-ETHOS.md](dev/DESIGN-ETHOS.md) - Design philosophy

**Explore**:
```bash
# Explore available commands
hv help

# View system capabilities
hv-detect-system text

# Check system status
systemctl status libvirtd
```

**Concept Quiz**:
1. What are the three pillars of Hyper-NixOS design?
2. What system tier was recommended for your hardware?
3. Name two advantages of NixOS over traditional distributions

**Checkpoint**: ✓ Can explain what Hyper-NixOS does differently

**What You Learned**:
- Three-pillar design (Intelligent Defaults, Privilege Separation, Education)
- System tier model (minimal/enhanced/complete)
- NixOS declarative benefits

---

### 1.3 Your First VM (1 hour)

**Tutorial**: Create and manage a VM

```bash
# Start VM creation wizard
hv vm-create

# Follow the prompts to create an Ubuntu VM
# Suggested config:
#   - Name: ubuntu-test
#   - OS: Ubuntu 22.04
#   - RAM: 2GB
#   - CPUs: 2
#   - Disk: 20GB

# Verify VM is running
virsh list

# Connect to VM console
virsh console ubuntu-test
# (Press Ctrl+] to exit console)

# Stop the VM
virsh shutdown ubuntu-test

# Start it again
virsh start ubuntu-test
```

**Practice Tasks**:
1. Create a VM
2. Start/stop the VM
3. Connect to VM console
4. Check VM status

**Checkpoint**: ✓ VM running and accessible

**What You Learned**:
- VM lifecycle management
- virsh command-line tool
- VM resource allocation
- Console access

**Transferable Skills**:
- `virsh` commands work on ANY KVM system (Ubuntu, RHEL, Debian, etc.)
- VM management concepts apply to VirtualBox, VMware, Proxmox

---

### 1.4 Basic Networking (45 minutes)

**Read**: [NETWORKING_FOUNDATION.md](dev/NETWORKING_FOUNDATION.md)

**Tutorial**: Configure VM networking

```bash
# Run network configuration wizard
hv network-configure

# Choose network mode:
#   - NAT (recommended for learning)
#   - Bridge (for production)

# Verify network configuration
ip link show
brctl show  # If bridge mode

# Test VM networking
virsh start ubuntu-test
virsh console ubuntu-test

# Inside VM:
ip addr          # Check IP address
ping 8.8.8.8     # Test internet
ping google.com  # Test DNS
```

**Practice Tasks**:
1. Configure NAT network
2. Verify VM gets IP address
3. Test internet connectivity from VM
4. (Advanced) Try bridge mode

**Checkpoint**: ✓ VM can ping external hosts

**What You Learned**:
- NAT vs Bridge networking
- Virtual network bridges
- DHCP for VMs
- Network troubleshooting basics

**Transferable Skills**:
- Linux bridge networking (works on all distributions)
- Network troubleshooting techniques
- Understanding NAT and routing

---

### Level 1 Completion

🎉 **Congratulations!** You've completed Level 1!

**Badge Earned**: 🏅 Novice Navigator

**Skills Acquired**:
- ✓ Install and configure Hyper-NixOS
- ✓ Create and manage VMs
- ✓ Configure basic networking
- ✓ Use virsh command-line tools
- ✓ Understand declarative configuration

**Next Steps**:
- Take a break if needed
- Review anything unclear
- When ready: **Level 2 - Daily Operations**

```bash
# View your progress
hv-track-progress stats
```

---

## Level 2: Daily Operations (Familiar → Competent)

**Goal**: Confidently manage multiple VMs with proper security

### 2.1 VM Management Mastery (2 hours)

**Read**: [USER_GUIDE.md](user-guides/USER_GUIDE.md) - VM Management section

**Tutorial**: Advanced VM operations

```bash
# Create multiple VMs for practice
hv vm-create --name debian-test --os debian --memory 1024
hv vm-create --name alpine-test --os alpine --memory 512

# List all VMs
virsh list --all

# Clone a VM
virt-clone --original ubuntu-test \
           --name ubuntu-clone \
           --auto-clone

# Create VM snapshot
virsh snapshot-create-as ubuntu-test \
      snapshot1 "Before testing"

# List snapshots
virsh snapshot-list ubuntu-test

# Revert to snapshot
virsh snapshot-revert ubuntu-test snapshot1

# Delete snapshot
virsh snapshot-delete ubuntu-test snapshot1
```

**Practice Tasks**:
1. Create 3 different VMs (Ubuntu, Debian, Alpine)
2. Clone one of your VMs
3. Create a snapshot before making changes
4. Make changes in VM, then revert snapshot
5. Manage all VMs (start, stop, restart)

**Checkpoint**: ✓ Manage 3+ VMs confidently

**What You Learned**:
- VM cloning for quick duplication
- Snapshots for safe testing
- Managing multiple VMs
- VM lifecycle automation

**Transferable Skills**:
- Snapshot concepts apply to VirtualBox, VMware, cloud VMs
- Cloning techniques for rapid provisioning

---

### 2.2 Storage Management (2 hours)

**Tutorial**: VM storage operations

```bash
# Run storage configuration wizard
hv storage-configure

# Create storage pool
virsh pool-define-as mypool dir --target /var/lib/libvirt/images/mypool
virsh pool-build mypool
virsh pool-start mypool
virsh pool-autostart mypool

# Create additional disk
virsh vol-create-as mypool data-disk 10G --format qcow2

# Attach disk to VM
virsh attach-disk ubuntu-test \
      /var/lib/libvirt/images/mypool/data-disk \
      vdb --persistent

# Inside VM, format and mount
lsblk                    # See new disk (vdb)
sudo mkfs.ext4 /dev/vdb
sudo mkdir /data
sudo mount /dev/vdb /data

# Resize VM disk (shutdown VM first)
virsh shutdown ubuntu-test
qemu-img resize /var/lib/libvirt/images/ubuntu-test.qcow2 +10G
virsh start ubuntu-test
# Inside VM, resize filesystem with growpart/resize2fs
```

**Practice Tasks**:
1. Create a storage pool
2. Add additional disk to VM
3. Format and mount disk in VM
4. Resize an existing VM disk

**Checkpoint**: ✓ Understand storage architecture and can manage disks

**What You Learned**:
- QCOW2 vs raw disk images
- Storage pools for organization
- Hot-attach/detach disks
- Disk resizing techniques

**Transferable Skills**:
- Storage concepts apply across virtualization platforms
- Disk management skills for Linux systems

---

### 2.3 Basic Security (2 hours)

**Read**: [SECURITY-FEATURES-USER-GUIDE.md](user-guides/SECURITY-FEATURES-USER-GUIDE.md)

**Tutorial**: Security hardening

```bash
# Run security configuration wizard
hv security-configure

# Choose security profile:
#   - Baseline (recommended for learning)
#   - Strict (production)
#   - Paranoid (maximum security)

# Configure firewall
sudo firewall-cmd --list-all      # View rules
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --reload

# Set up SSH key authentication
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to VMs
ssh-copy-id user@vm-ip

# Disable password auth (on VM)
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Enable audit logging
sudo systemctl enable auditd
sudo systemctl start auditd

# View audit logs
sudo ausearch -k security
```

**Practice Tasks**:
1. Configure firewall rules
2. Set up SSH key authentication
3. Enable audit logging
4. Review security logs
5. Test privilege separation (operator vs admin)

**Checkpoint**: ✓ Secure VM access configured

**What You Learned**:
- Firewall configuration
- SSH key-based authentication
- Audit logging
- Privilege separation model
- Security profiles

**Transferable Skills**:
- SSH security practices for any Linux system
- Firewall concepts (iptables, firewalld, ufw)
- Security hardening principles

---

### 2.4 Backup & Recovery (2 hours)

**Tutorial**: Backup strategy

```bash
# Run backup configuration wizard
hv backup-configure

# Manual VM backup
mkdir -p /backup/vms

# Backup VM (requires shutdown or live snapshot)
virsh shutdown ubuntu-test

# Backup VM disk
cp /var/lib/libvirt/images/ubuntu-test.qcow2 \
   /backup/vms/ubuntu-test-$(date +%Y%m%d).qcow2

# Backup VM config
virsh dumpxml ubuntu-test > \
      /backup/vms/ubuntu-test-$(date +%Y%m%d).xml

# Automate with script
cat > /usr/local/bin/backup-vm.sh <<'EOF'
#!/bin/bash
VM=$1
BACKUP_DIR=/backup/vms
DATE=$(date +%Y%m%d-%H%M%S)

virsh dumpxml $VM > $BACKUP_DIR/$VM-$DATE.xml
virsh snapshot-create-as $VM backup-$DATE
# Copy disk with rsync...
EOF

chmod +x /usr/local/bin/backup-vm.sh

# Restore VM from backup
virsh define /backup/vms/ubuntu-test-20241017.xml
cp /backup/vms/ubuntu-test-20241017.qcow2 \
   /var/lib/libvirt/images/ubuntu-test.qcow2
virsh start ubuntu-test
```

**Practice Tasks**:
1. Create manual backup of a VM
2. Schedule automated backups
3. Restore VM from backup
4. Test disaster recovery

**Checkpoint**: ✓ Reliable backup strategy in place

**What You Learned**:
- VM backup strategies
- Manual and automated backups
- Disaster recovery procedures
- Configuration backup importance

**Transferable Skills**:
- Backup strategies for any system
- Disaster recovery planning

---

### Level 2 Completion

🎉 **Congratulations!** You've completed Level 2!

**Badge Earned**: 🌟 Competent Curator

**Skills Acquired**:
- ✓ Advanced VM management (clone, snapshot)
- ✓ Storage pool and disk management
- ✓ Security hardening and firewall
- ✓ Backup and disaster recovery
- ✓ SSH key authentication
- ✓ Audit logging

**Next Steps**: **Level 3 - Advanced Features**

```bash
hv-track-progress stats  # Check your progress!
```

---

## Level 3: Advanced Features (Competent → Proficient)

**Goal**: Master advanced features like clustering, monitoring, and automation

### 3.1 Monitoring Setup (2 hours)

**Tutorial**: Implement comprehensive monitoring

```bash
# Run monitoring configuration wizard
hv monitoring-configure

# Install Prometheus + Grafana (if not automatic)
# Access Grafana: http://localhost:3000

# Configure metrics collection
# View VM metrics
# Set up alerts
```

**Topics**:
- Prometheus metrics
- Grafana dashboards
- Alert configuration
- Performance monitoring

**Checkpoint**: ✓ Monitoring dashboard operational

---

### 3.2 Network VLANs (2 hours)

**Tutorial**: Advanced networking with VLANs

**Checkpoint**: ✓ Multi-VLAN environment configured

---

### 3.3 GPU Passthrough (3 hours)

**Tutorial**: Pass GPU to VM for graphics

**Checkpoint**: ✓ GPU accessible in VM

---

### 3.4 Clustering Basics (3 hours)

**Tutorial**: Multi-node clustering

**Checkpoint**: ✓ Two-node cluster operational

---

### Level 3 Completion

**Badge Earned**: 🚀 Advanced Architect

---

## Level 4: Expert Mastery (Proficient → Expert)

**Goal**: Production deployment and system architecture

### 4.1 Production Hardening (4 hours)

**Topics**:
- SELinux/AppArmor
- Network segmentation
- Intrusion detection
- Compliance scanning

**Checkpoint**: ✓ Production-ready security

---

### 4.2 Automation & IaC (4 hours)

**Topics**:
- NixOS configuration as code
- Automated deployment
- GitOps workflow
- CI/CD for VMs

**Checkpoint**: ✓ Fully automated infrastructure

---

### 4.3 Performance Optimization (4 hours)

**Topics**:
- CPU pinning
- NUMA awareness
- Huge pages
- Storage optimization

**Checkpoint**: ✓ Optimized performance

---

### 4.4 HA & DR (4 hours)

**Topics**:
- High availability clustering
- Live migration
- Disaster recovery testing
- Business continuity

**Checkpoint**: ✓ HA cluster with DR

---

### Level 4 Completion

**Badge Earned**: 💎 Master Virtualist

**You are now**: Expert-level Hyper-NixOS administrator

---

## Appendix: Quick Reference

### Essential Commands

```bash
# Discovery
hv discover
hv-detect-system

# VM Management
hv vm-create
virsh list --all
virsh start/shutdown/reboot VM

# Configuration
hv network-configure
hv storage-configure
hv security-configure
hv backup-configure

# Monitoring
hv-track-progress show
hv-track-progress stats

# Help
hv help
man virsh
```

### Next Steps After Mastery

1. **Contribute**: Help improve Hyper-NixOS
2. **Teach**: Share knowledge with community
3. **Deploy**: Use in production environments
4. **Specialize**: Focus on specific areas (networking, security, storage)

---

## Resources

- **Documentation**: `/usr/share/doc/hypervisor/`
- **Community**: GitHub Discussions
- **Support**: Create GitHub issue
- **Learning**: This guide!

**Track your journey**: `hv-track-progress stats`

🚀 Happy Learning!
