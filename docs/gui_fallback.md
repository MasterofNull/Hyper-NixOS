# GNOME fallback management environment

The hypervisor host is designed to run headless with a minimal console TUI to reduce overhead. When you need a richer desktop for troubleshooting or graphical tools, you can enable an optional GNOME environment.

## Enable GNOME fallback
1. Copy the example module and rebuild:

```bash
sudo install -m0644 /etc/hypervisor/configuration/gui-local.example.nix /etc/hypervisor/configuration/gui-local.nix
sudo nixos-rebuild switch --flake "/etc/nixos#$(hostname -s)"
```

This enables GDM + GNOME and installs basic tools: virt-manager, GNOME system utilities, and Codium (VS Code OSS).

## Launch from the VM menu
- From the boot-time TUI main screen, choose: "Start GNOME management session (fallback GUI)".
- The menu will enable/start `gdm.service` if necessary and switch to the graphical target.

To return to console-only at next boot:

```bash
sudo systemctl set-default multi-user.target
sudo systemctl disable gdm.service
```

## Notes
- The GUI is optional and off by default. Regular hypervisor operation should remain headless to minimize resource usage.
- `services.xserver.enable` remains false unless you add `gui-local.nix`.
- The auto-start countdown for the last VM still runs before showing the main menu; any key cancels it.
