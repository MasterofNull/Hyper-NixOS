# Getting Started with Hyper-NixOS
## For New Users

> 📖 **New to virtualization?** This guide is for you!  
> 🔧 **Already familiar?** See the [Quick Start](../QUICK_START.md) or [Installation Guide](../INSTALLATION_GUIDE.md)

## 👋 Welcome!

Hyper-NixOS is a next-generation virtualization platform that makes it easy to run virtual machines (VMs) on your hardware. This guide will help you get started.

## 📋 What You'll Need

### Hardware
- A computer with **Intel VT-x** or **AMD-V** (most modern CPUs have this)
- At least **8GB RAM** (more is better for running VMs)
- At least **100GB free disk space**
- Network connection

### Software
- **NixOS** operating system installed
  - Don't have NixOS? [Download here](https://nixos.org/download.html)
  - Already on Linux? You can install NixOS alongside

### Knowledge
- Basic command-line skills (copying and pasting commands is enough!)
- Willingness to learn (we'll guide you)

## 🚀 Installation (5 Minutes)

### Step 1: Choose Your Install Method

**Option A: Quick Install** (if you trust us)
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

**Option B: Inspect Code First** (recommended for learning)
```bash
# Download the code
git clone https://github.com/MasterofNull/Hyper-NixOS.git

# Go into the directory
cd Hyper-NixOS

# Look around if you want!
ls

# Run the installer
sudo ./install.sh
```

### Step 2: Watch It Work

The installer will:
1. Check your hardware
2. Set up the virtualization software
3. Configure your system
4. Prepare everything for first boot

You'll see progress messages - this is normal!

### Step 3: Reboot

When prompted, reboot your computer:
```bash
sudo reboot
```

## 🎯 First Boot (Setup Wizard)

After rebooting, Hyper-NixOS will automatically start a setup wizard that helps you:

1. **Choose Your Configuration Tier**
   - **Minimal**: For low-powered systems (2-4GB RAM)
   - **Standard**: For most users (8GB+ RAM)
   - **Enhanced**: For power users (16GB+ RAM)
   - **Professional**: For workstations (32GB+ RAM)
   - **Enterprise**: For servers (64GB+ RAM)

   Don't worry - the wizard will recommend the best tier for your hardware!

2. **Select Features**
   - Web dashboard
   - Monitoring tools
   - Backup automation
   - Security features

3. **Configure Your First VM** (optional)
   - You can create a VM right away
   - Or skip and do it later

## 📚 What's Next?

### Learn the Basics

1. **Understanding VMs**: See [VM Basics](VM_BASICS.md)
2. **Creating Your First VM**: See [Create VM Guide](CREATE_VM_GUIDE.md)
3. **Managing VMs**: See [VM Management](VM_MANAGEMENT_GUIDE.md)

### Explore Features

- **Web Dashboard**: Access at `http://your-server:8080`
- **Command Line**: Use `hv` commands
- **Monitoring**: View system status and VM performance

### Get Help

- **Documentation**: Browse [all guides](README-USER-GUIDES.md)
- **Common Issues**: Check [Troubleshooting](../TROUBLESHOOTING.md)
- **Community**: See [Community & Support](../COMMUNITY_AND_SUPPORT.md)

## 🎓 Learning Path

We recommend this learning sequence:

1. ✅ **Install Hyper-NixOS** (you're here!)
2. **Create a simple VM** → [Create VM Guide](CREATE_VM_GUIDE.md)
3. **Learn VM management** → [VM Management](VM_MANAGEMENT_GUIDE.md)
4. **Explore features** → [Feature Guide](../FEATURE_CATALOG.md)
5. **Set up backups** → [Backup Guide](BACKUP_GUIDE.md)
6. **Understand security** → [Security Guide](SECURITY-FEATURES-USER-GUIDE.md)

## ❓ Common Questions

**Q: Do I need to be a Linux expert?**  
A: No! If you can copy and paste commands, you can use Hyper-NixOS. We'll teach you as you go.

**Q: Can I break my system?**  
A: Hyper-NixOS runs on NixOS, which lets you roll back changes. It's very hard to permanently break!

**Q: How much does it cost?**  
A: Hyper-NixOS is completely free and open source.

**Q: Can I run Windows VMs?**  
A: Yes! You can run Windows, Linux, BSD, and many other operating systems as VMs.

**Q: What if I get stuck?**  
A: Check the [Troubleshooting Guide](../TROUBLESHOOTING.md) or ask in our [community](../COMMUNITY_AND_SUPPORT.md).

## 🎉 Welcome to Hyper-NixOS!

You're now ready to start your virtualization journey. Take it one step at a time, and don't hesitate to explore the documentation.

**Happy virtualizing!** 🚀

---

*For detailed technical information, see the [Admin Guide](../ADMIN_GUIDE.md)*  
*For advanced features, see the [Feature Catalog](../FEATURE_CATALOG.md)*
