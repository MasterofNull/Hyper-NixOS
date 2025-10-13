{ config, lib, pkgs, ... }:
{
  # Optional GNOME management environment (DISABLED by default in base config)
  # Copy to /etc/hypervisor/configuration/gui-local.nix and customize.
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  programs.dconf.enable = true;

  # Minimal management tools
  environment.systemPackages = with pkgs; [
    virt-manager
    gnome.gnome-system-monitor
    gnome.gnome-disk-utility
    gnome.gnome-terminal
    gnome.gedit
    # Codium (VS Code OSS)
    vscodium
  ];

  # Allow hypervisor user to log into GNOME if desired
  users.users.hypervisor = lib.mkMerge [
    (config.users.users.hypervisor or { })
    { isNormalUser = true; createHome = true; }
  ];

  # Note: Touchpad, keyboard, and input device support is automatically
  # enabled via hardware-input.nix, including:
  # - Multitouch gestures (two-finger scroll, tap-to-click)
  # - Keyboard backlighting control (brightness hotkeys)
  # - Screen brightness controls
  # - Natural scrolling and other touchpad features
  # See configuration/hardware-input.nix for customization options.

  # Ensure graphical session starts on demand (gdm service handled by systemd)
  # You can mask GDM until launched via menu script if you prefer.
}
