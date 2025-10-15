{ config, lib, pkgs, ... }:
{
  # Example Sway/Wayland GUI configuration (DISABLED by default)
  # Copy to /var/lib/hypervisor/configuration/gui-local.nix to enable GUI mode
  # This is a PURE WAYLAND system - NO X11 (security risk)
  
  # Enable GUI at boot
  hypervisor.gui.enableAtBoot = true;
  
  # Additional Wayland-native GUI tools
  environment.systemPackages =  [
    # VM management
    pkgs.virt-manager  # Uses GTK, works natively on Wayland
    
    # System monitoring
    pkgs.btop          # Modern system monitor (TUI)
    
    # File manager
    pkgs.nnn           # Terminal file manager
    pkgs.thunar        # GUI file manager (GTK, Wayland-native)
    
    # Terminal emulator (already included in Sway, but can add more)
    pkgs.foot          # Lightweight Wayland terminal
    pkgs.kitty         # GPU-accelerated terminal
    
    # Text editor
    pkgs.neovim        # Terminal editor
    pkgs.helix         # Modern terminal editor
    
    # Browser (Wayland-native)
    pkgs.firefox-wayland
    
    # Productivity
    pkgs.wdisplays     # Display configuration for Wayland
    pkgs.grim          # Screenshot tool for Wayland
    pkgs.slurp         # Region selector for screenshots
    
    # System utilities
    pkgs.pavucontrol   # Audio control (works on Wayland)
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
  # NOTE: These services may not exist in minimal configurations
  # Ensure rtkit and pipewire modules are available before using this example
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
