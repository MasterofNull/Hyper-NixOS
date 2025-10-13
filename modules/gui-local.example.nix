{ config, lib, pkgs, ... }:
{
  # Example Sway/Wayland GUI configuration (DISABLED by default)
  # Copy to /var/lib/hypervisor/configuration/gui-local.nix to enable GUI mode
  # This is a PURE WAYLAND system - NO X11 (security risk)
  
  # Enable GUI at boot
  hypervisor.gui.enableAtBoot = true;
  
  # Additional Wayland-native GUI tools
  environment.systemPackages = with pkgs; [
    # VM management
    virt-manager  # Uses GTK, works natively on Wayland
    
    # System monitoring
    btop          # Modern system monitor (TUI)
    
    # File manager
    nnn           # Terminal file manager
    thunar        # GUI file manager (GTK, Wayland-native)
    
    # Terminal emulator (already included in Sway, but can add more)
    foot          # Lightweight Wayland terminal
    kitty         # GPU-accelerated terminal
    
    # Text editor
    neovim        # Terminal editor
    helix         # Modern terminal editor
    
    # Browser (Wayland-native)
    firefox-wayland
    
    # Productivity
    wdisplays     # Display configuration for Wayland
    grim          # Screenshot tool for Wayland
    slurp         # Region selector for screenshots
    
    # System utilities
    pavucontrol   # Audio control (works on Wayland)
  ];
  
  # Sway configuration file
  environment.etc."sway/config.d/hypervisor.conf".text = ''
    # Hypervisor-specific Sway configuration
    
    # Autostart hypervisor dashboard
    exec /etc/hypervisor/scripts/management_dashboard.sh --autostart
    
    # Keybindings for hypervisor management
    bindsym $mod+h exec alacritty -e /etc/hypervisor/scripts/menu.sh
    
    # Screenshots
    bindsym Print exec grim -g "$(slurp)" - | wl-copy
    bindsym Shift+Print exec grim - | wl-copy
  '';
  
  # Enable audio support
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
