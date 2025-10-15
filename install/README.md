# Portable Installation Scripts

**Purpose**: Cross-platform installation support for non-NixOS systems

## Files

### portable-install.sh
**Status**: ✅ Active (for non-NixOS platforms)

**Use Case**: Installing Hyper-NixOS components on existing systems
- Works on: Debian, Ubuntu, Fedora, Arch, and other Linux distributions
- Installs: Nix package manager + Hyper-NixOS configurations
- Platform detection and adaptation

**Difference from Main Installer**:
- `/install.sh` (root) - NixOS-native installation (primary method)
- `/install/portable-install.sh` - Multi-platform compatibility layer

## Usage

### For NixOS Systems (Recommended):
```bash
# Use the main installer
sudo ./install.sh
```

### For Non-NixOS Systems:
```bash
# Use the portable installer
sudo ./install/portable-install.sh
```

## Features

**Portable Installer Capabilities**:
- Automatic platform detection (OS, architecture, init system)
- Nix package manager installation if not present
- Flakes and experimental features configuration
- User/system mode installation
- Dry-run support for testing
- Verbose logging options

## Documentation

For installation details, see:
- `/docs/INSTALLATION_GUIDE.md` - Full installation documentation
- `/docs/deployment/DEPLOYMENT.md` - Production deployment guide

---

*Part of Hyper-NixOS v2.0+*  
*Supports: Linux distributions with systemd or other init systems*
