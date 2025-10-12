# Hyper-NixOS (Hypervisor Suite)

A NixOS-based, security and performance focused hypervisor with a boot-time VM menu, ISO download + verification, libvirt management, and optional VFIO passthrough.

---

## 🚀 Installation (Choose ONE method)

### Method 1: One-Liner Install (Recommended - Works anywhere)

**Perfect for:** Fresh installs, automated deployments, USB boots

This single command downloads the repo, installs the system, and reboots:
```bash
bash -lc 'set -euo pipefail; command -v git >/dev/null || nix --extra-experimental-features "nix-command flakes" profile install nixpkgs#git; tmp="$(mktemp -d)"; git clone https://github.com/MasterofNull/Hyper-NixOS "$tmp/hyper"; cd "$tmp/hyper"; sudo env NIX_CONFIG="experimental-features = nix-command flakes" bash ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$tmp/hyper" --reboot'
```

**What it does:**
- ✅ Installs git if needed
- ✅ Clones the repository  
- ✅ Runs bootstrap installer
- ✅ Migrates your existing users/settings
- ✅ Switches to new system
- ✅ Reboots automatically

**That's it!** After reboot, you'll see the hypervisor menu. Skip to [After Installation](#after-installation).

---

### Method 2: Manual Install (If you already have the repo)

**Perfect for:** Development, testing, customization

#### Step 1: Enable flakes (Skip if already enabled)

Check if you need this:
```bash
nixos-rebuild --help 2>&1 | grep -q -- --flake && echo "Flakes already enabled ✓" || echo "Need to enable flakes"
```

If needed, enable flakes:
```bash
sudo bash -lc 'set -euo pipefail; if ! nixos-rebuild --help 2>&1 | grep -q -- --flake; then tmp=/tmp/enable-flakes.nix; printf "%s\n" "{ config, pkgs, lib, ... }:" "{" "  imports = [ /etc/nixos/configuration.nix ];" "  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];" "  nix.package = pkgs.nixVersions.stable;" "}" > "$tmp"; nixos-rebuild switch -I nixos-config="$tmp"; fi'
```

#### Step 2: Run bootstrap

**Option A - Guided install with prompts:**
```bash
cd /path/to/Hyper-NixOS
sudo nix run .#bootstrap
```

**Option B - Unattended install:**
```bash
cd /path/to/Hyper-NixOS
sudo ./scripts/bootstrap_nixos.sh --hostname "$(hostname -s)" --action switch --source "$(pwd)" --reboot
```

**What bootstrap does:**
- ✅ Detects your username automatically (no hardcoding!)
- ✅ Copies configuration to `/etc/hypervisor/src`
- ✅ Creates `/etc/hypervisor/flake.nix` 
- ✅ Generates `users-local.nix` with your user added to the wheel group
- ✅ Generates `system-local.nix` with your timezone/locale
- ✅ Runs `nixos-rebuild switch` to activate the new system
- ✅ After switch, you have permanent sudo access (via wheel group)
- ✅ Optionally reboots

**Note:** You need to be able to run `sudo` initially to start the bootstrap. If you're on a fresh NixOS install, the installer typically gives the initial user sudo access. The bootstrap will then ensure you keep sudo access permanently through the wheel group configuration.

---

### Method 3: Build Bootable ISO

**Perfect for:** Creating installation media, bare metal deployments

```bash
cd /path/to/Hyper-NixOS
nix build .#iso
# ISO will be in ./result/iso/
```

Boot from the ISO. On first boot, a setup wizard helps you configure networking and create your first VM.

---

## After Installation

### First Boot Experience

After reboot, you'll be **automatically logged in** to the console and the **first-boot setup wizard** will run:

1. **Welcome Screen** - Overview of the wizard
2. **Network Setup** - Create network bridge (optional)
3. **ISO Download** - Download and verify OS installer from 14 presets (optional)
4. **VM Creation** - Create your first VM profile (optional)
5. **Summary** - Shows what was configured

**No login required!** The system automatically logs you in and starts the wizard.

**The wizard shows clear progress and feedback at each step!**

After the wizard completes (or on subsequent boots), you'll see the **hypervisor console menu** with:
- 🖥️ **Start VMs** - Launch your virtual machines
- 📦 **Download ISOs** - Get OS installation images  
- ⚙️ **Create VMs** - Set up new virtual machines
- 🔧 **System Tools** - Diagnostics, updates, backups
- 🪟 **GNOME Desktop** - Graphical environment (if enabled)

### Login Requirements

**Console Mode (Default):**
- ✅ **No login required** - Automatic login to your user account
- ✅ Wizard and menu start immediately on tty1
- ✅ Seamless experience from boot to menu

**GUI Mode (If enabled):**
- ✅ **No login required** - Automatic login to GNOME desktop
- ✅ Dashboard launches automatically
- ✅ Use if you prefer graphical management

### Customizing Boot Behavior

Want to change what loads at boot? Create `/var/lib/hypervisor/configuration/gui-local.nix`:

```nix
{ config, lib, ... }:
{
  # Enable GNOME at boot instead of console menu
  hypervisor.gui.enableAtBoot = true;
  hypervisor.menu.enableAtBoot = false;
  
  # Disable first-boot wizard (after it runs once)
  hypervisor.firstBootWizard.enableAtBoot = false;
}
```

Then rebuild: `sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"`

**Note:** Autologin is enabled by default for both console and GUI modes to provide a seamless appliance experience. You can disable it if you need manual login for security reasons.

**Next steps:** See [Quick Start Guide](docs/QUICKSTART_EXPANDED.md) to create your first VM.

---

## Quick Reference

### Update the system
```bash
sudo bash /etc/hypervisor/scripts/update_hypervisor.sh
```

### Rebuild after config changes
```bash
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

### Re-run the first-boot wizard
```bash
# Remove the marker file
sudo rm /var/lib/hypervisor/.first_boot_done
# Then reboot, or run manually:
sudo bash /etc/hypervisor/scripts/setup_wizard.sh
```

### View wizard logs
```bash
cat /var/lib/hypervisor/logs/first_boot.log
```

### Rebuild helper (alternative)
```bash
nix run .#rebuild-helper -- --flake /etc/hypervisor --host $(hostname -s) {build|test|switch}
```


## System features
- Boot-time TUI menu (multi-tier): VM list, GNOME fallback, and More Options
- Autostart last VM with configurable timeout (`/etc/hypervisor/config.json`)
- ISO manager with checksum/signature verification
- VM creation wizard and per-VM JSON profiles
- Libvirt XML generation and start (pinning/hugepages/audio/LookingGlass/hostdev)
- Optional GNOME fallback desktop (`configuration/gui-local.nix`)
- VFIO guided flow + Nix snippet, bridge helper, snapshots/backups
- Hardened kernel, non-root QEMU, auditd, SSH (keys only)

## Documentation
- Install and host details: `docs/README_install.md`
- Optional GNOME fallback: `docs/gui_fallback.md`
- Advanced options and feature toggles: `docs/advanced_features.md`
- Updating to latest or a specific ref: use the menu option “Update Hypervisor (pin to latest)” or run:
```bash
sudo bash /etc/hypervisor/scripts/update_hypervisor.sh [--ref <commit|branch|tag>]
```

When you finish configuring and validating the system, you can optionally harden permissions on `/etc/hypervisor`:
```bash
sudo bash /etc/hypervisor/scripts/harden_permissions.sh
```

If you need to update or prune old generations later, temporarily relax permissions, perform the maintenance, then harden again:
```bash
sudo bash /etc/hypervisor/scripts/relax_permissions.sh
# ... perform updates, GC, or generation cleanup ...
sudo bash /etc/hypervisor/scripts/harden_permissions.sh
```

## Advanced Configuration

### Disable Autologin (For Multi-User Security)

By default, autologin is enabled for a seamless appliance experience. To require manual login:

Create `/var/lib/hypervisor/configuration/security-local.nix`:
```nix
{ config, lib, ... }:
{
  # Disable autologin - require manual login
  services.getty.autologinUser = lib.mkForce null;
  
  # Also disable GUI autologin if using GUI mode
  services.xserver.displayManager.autoLogin.enable = lib.mkForce false;
}
```

Then rebuild: `sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"`

**After this change:**
- You'll need to login at the console/GUI
- The menu/wizard will start after login
- More secure for multi-user systems

---

## Troubleshooting

### "User not in sudoers file" error
If you get this error when trying to run `sudo nix run .#bootstrap`:

**The Issue:** You need sudo access to run the bootstrap script initially.

**Solutions:**

1. **On a fresh NixOS install:** The installer usually creates your first user with sudo access via the wheel group. Try:
```bash
# Check if you're in the wheel group
groups $USER | grep -q wheel && echo "In wheel group ✓" || echo "Not in wheel group"
```

2. **If not in wheel group:** You can either:
   - **Option A:** Become root directly: `su -` then run the bootstrap
   - **Option B:** Have an admin add you to wheel: `sudo usermod -aG wheel your-username`

3. **After bootstrap completes:** The script automatically adds your user to the wheel group in `users-local.nix`. After `nixos-rebuild switch` completes, you'll have permanent sudo access through the NixOS configuration (no manual sudoers editing needed!)

**How it works:**
- Bootstrap detects your username via `$SUDO_USER` or system detection
- Generates `users-local.nix` with your user in the wheel group
- NixOS configuration has `security.sudo.wheelNeedsPassword = false`
- After rebuild, wheel group members have passwordless sudo

### Force fresh fetch on rebuild
If you hit cache/NAR issues:
```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --impure --flake "/etc/hypervisor#$(hostname -s)" \
  --refresh --option tarball-ttl 0 \
  --option narinfo-cache-positive-ttl 0 \
  --option narinfo-cache-negative-ttl 0
```

### More help
See `/etc/hypervisor/docs` on the running system, especially:
- `docs/TROUBLESHOOTING.md` - Comprehensive troubleshooting guide
- `docs/QUICKSTART_EXPANDED.md` - Detailed VM creation guide
