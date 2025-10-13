# Migration Guide: First-Boot Wizard → Install VMs Workflow

## For Existing Users

If you're upgrading from a previous version of Hyper-NixOS, here's what's changed and how to adapt.

## What Changed?

### Before (v2.0)
- **First boot:** Automatic wizard runs once
- **Subsequent boots:** Main menu with separate tools
- **VM creation:** Multiple scattered tools

### After (v2.1)
- **All boots:** Main menu immediately
- **VM creation:** Single "Install VMs" workflow
- **Better UX:** Integrated, guided, can exit anytime

## Impact on Your System

### ✅ No Breaking Changes
- **Existing VMs:** Work exactly as before
- **Network config:** Unchanged
- **ISOs:** All still available
- **Scripts:** Individual tools still accessible

### 📝 Changed Defaults
- **First-boot wizard:** Disabled by default
- **Menu option:** New "Install VMs" workflow available
- **Boot behavior:** Console menu loads directly

## What You Need to Do

### Option 1: Nothing (Recommended)
Your system continues to work. The first-boot wizard is simply disabled. Use "Install VMs" workflow when you need to create new VMs.

### Option 2: Re-enable First-Boot Wizard (Not Recommended)
If you really want the old behavior:

```bash
# Edit local config
sudo nano /var/lib/hypervisor/configuration/boot-local.nix
```

Add:
```nix
{ config, lib, ... }:
{
  hypervisor.firstBootWizard.enableAtBoot = true;
}
```

Rebuild:
```bash
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

**Note:** We recommend using the new "Install VMs" workflow instead. It provides better UX and can be run anytime from the menu.

## How to Use the New Workflow

### Creating Your Next VM

**Old way (v2.0):**
```
1. Boot → See main menu
2. More Options → ISO manager
3. Download ISO
4. Back to menu
5. More Options → Create VM wizard
6. Configure VM
7. Back to menu
8. Select VM → Start VM
9. Select VM → Console
```

**New way (v2.1):**
```
1. Boot → See main menu
2. More Options → Install VMs
3. Guided workflow:
   - Network check ✓
   - ISO download ✓
   - VM creation ✓
   - Auto-launch ✓
   - Console access ✓
4. Back to main menu → Done!
```

### Accessing Individual Tools

If you prefer the old way, all individual tools are still available:

```
Main Menu → More Options:
  1. ISO manager (download/validate/attach)
  2. Cloud image manager (cloud-init images)
  3. Create VM (wizard only - advanced)
  9. Bridge helper (network setup)
```

## FAQ

### Q: Will my existing VMs work?
**A:** Yes! No changes to VM definitions or runtime behavior.

### Q: Do I need to reconfigure networking?
**A:** No. Existing network bridges continue to work.

### Q: What happens to my ISOs?
**A:** They're all still in `/var/lib/hypervisor/isos/` and work perfectly.

### Q: Can I still use the first-boot wizard?
**A:** Yes, but it must be run manually:
```bash
sudo bash /etc/hypervisor/scripts/setup_wizard.sh
```

However, we recommend trying the new "Install VMs" workflow first.

### Q: Why disable the first-boot wizard?
**A:** User feedback showed:
- Confusion when wizard exits
- Hard to re-run if needed
- Scattered tools after wizard
- No easy "start over"

The new workflow addresses all these issues:
- Always accessible from menu
- Can exit/resume anytime
- Integrated experience
- Repeatable process

### Q: What if I don't like the new workflow?
**A:** 
1. Try it a few times - it's significantly improved
2. Use individual tools if preferred (they're all still there)
3. Provide feedback: https://github.com/MasterofNull/Hyper-NixOS/issues

### Q: How do I uninstall this update?
**A:** To rollback to previous configuration:
```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous (e.g., 42)
sudo nix-env --rollback --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

## Feature Comparison

| Feature | First-Boot Wizard (v2.0) | Install VMs Workflow (v2.1) |
|---------|-------------------------|---------------------------|
| **Availability** | Once at first boot | Anytime from menu |
| **Exit behavior** | Exits to nothing | Returns to menu |
| **Resume capability** | No | Yes (planned) |
| **Integration** | Calls separate tools | Fully integrated |
| **Status display** | Minimal | Comprehensive |
| **Help/Tips** | Some | Extensive (💡 TIP) |
| **Auto-launch VM** | No | Yes |
| **Console access** | Manual | Offered automatically |
| **Progress tracking** | Limited | Full (✓ ⚠ ○) |
| **Error recovery** | Abort | Continue or retry |
| **Logging** | Separate files | Unified log |

## Recommended Workflow

For most users, we recommend:

1. **First VM:** Use "Install VMs" workflow
   - Guided setup
   - All steps in one place
   - Auto-launch and test
   
2. **Subsequent VMs:** Use "Install VMs" workflow OR individual tools
   - Workflow: For guided experience
   - Individual tools: For quick tasks
   
3. **Advanced users:** Mix and match
   - Workflow for complex setups
   - Individual tools for specific tasks

## Getting Help

### Documentation
- **Quick Start:** README.md section "Install Your First VM"
- **UX Guide:** docs/UX_IMPROVEMENTS.md
- **Full docs:** /etc/hypervisor/docs/

### Logs
```bash
# Installation workflow
cat /var/lib/hypervisor/logs/install_vm.log

# Menu actions
cat /var/lib/hypervisor/logs/menu.log

# System logs
journalctl -u hypervisor-menu.service
```

### Interactive Help
```
Main Menu → More Options → Help & Learning Center
```

### Community Support
- **Issues:** https://github.com/MasterofNull/Hyper-NixOS/issues
- **Discussions:** https://github.com/MasterofNull/Hyper-NixOS/discussions

## Feedback Welcome!

We've made these changes based on user feedback and usability testing. If you have suggestions or encounter issues, please let us know:

- GitHub Issues: https://github.com/MasterofNull/Hyper-NixOS/issues
- In-app: Main Menu → More Options → Help & Learning Center

Your feedback helps make Hyper-NixOS better for everyone!

---

**Migration Guide Version:** 1.0  
**Applies to:** Hyper-NixOS v2.1+  
**Last Updated:** 2025-10-12
