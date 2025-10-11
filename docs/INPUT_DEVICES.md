# Input Device Support

## Overview

The Hyper-NixOS hypervisor suite includes comprehensive touchpad and keyboard support, providing a modern input experience when using the optional GNOME GUI management interface.

## Features

### Touchpad Support

The system uses `libinput`, the modern Linux touchpad driver with full multitouch support:

#### Enabled Features:
- **Tap-to-click**: Single tap = left click, two-finger tap = right click
- **Two-finger scrolling**: Natural and smooth scrolling with two fingers
- **Disable-while-typing**: Prevents accidental touches while typing
- **Clickfinger method**: Click anywhere on the touchpad to register clicks
- **Middle button emulation**: Click both buttons simultaneously for middle-click
- **Adaptive acceleration**: Intelligent pointer speed adjustment

#### Customization:
Edit `/etc/hypervisor/configuration/hardware-input.nix` to adjust:
```nix
services.xserver.libinput.touchpad = {
  naturalScrolling = true;    # Enable macOS-style reversed scrolling
  accelSpeed = "0.5";          # Increase pointer speed (-1.0 to 1.0)
  tapping = false;             # Disable tap-to-click
  # ... and more options
};
```

### Multitouch Gestures

Advanced touchpad gestures are supported via `libinput-gestures`:

#### Default Gestures:
- **3-finger swipe up/down**: Switch workspaces
- **3-finger swipe left/right**: Browser forward/back (Alt+Arrow)
- **4-finger swipe left/right**: Switch workspaces (Ctrl+Alt+Arrow)
- **2-finger pinch in/out**: Zoom out/in (Ctrl+Minus/Plus)

#### Customization:
Create or edit `~/.config/libinput-gestures.conf`:
```bash
# Custom gestures
gesture swipe up 4 xdotool key Super_L+Up
gesture swipe down 4 xdotool key Super_L+Down
```

Then restart the service:
```bash
libinput-gestures-setup restart
```

### Keyboard Backlighting

Keyboard backlight control is fully supported with hardware hotkeys:

#### Hotkeys (hardware-dependent):
- **Fn+F5/F6** (or similar): Decrease/increase keyboard backlight
- **Backlight toggle**: Turn backlight on/off completely

#### Manual Control:
```bash
# Increase keyboard backlight by 10%
brightnessctl --device='*::kbd_backlight' set +10%

# Decrease keyboard backlight by 10%
brightnessctl --device='*::kbd_backlight' set 10%-

# Set to 50%
brightnessctl --device='*::kbd_backlight' set 50%

# List all backlight devices
brightnessctl --list
```

### Screen Brightness Control

Display brightness is also controlled via ACPI hotkeys:

#### Hotkeys:
- **Fn+F11/F12** (or similar): Decrease/increase screen brightness

#### Manual Control:
```bash
# Increase brightness by 10%
brightnessctl set +10%

# Set to specific percentage
brightnessctl set 75%

# Get current brightness
brightnessctl get
```

### Keyboard Layout and Features

#### Default Configuration:
- **Layout**: US (QWERTY)
- **Special key**: Ctrl+Alt+Backspace to restart X server (safety feature)
- **NumLock on boot**: Can be enabled (commented out by default)
- **Keyboard repeat**: Standard delay and interval

#### Changing Layout:
**Temporary** (current session):
```bash
setxkbmap dvorak
setxkbmap us -variant colemak
```

**Permanent** (edit `/etc/hypervisor/configuration/hardware-input.nix`):
```nix
services.xserver.xkb = {
  layout = "us,ru";           # Multiple layouts
  variant = "";               # Or "colemak,phonetic"
  options = "grp:alt_shift_toggle,caps:escape";  # Layout switch + Caps as Escape
};
```

Then rebuild:
```bash
sudo nixos-rebuild switch --flake /etc/hypervisor#$(hostname -s)
```

## Permissions

Input device access requires proper group membership. Users are automatically added to:
- **input**: Access to keyboard/mouse/touchpad devices
- **video**: Access to brightness controls

These are configured automatically during installation via the bootstrap script.

## Troubleshooting

### Touchpad Not Working

1. **Check if libinput is detecting the device:**
   ```bash
   libinput list-devices
   ```

2. **Test touchpad events:**
   ```bash
   sudo libinput debug-events
   # Move your finger on the touchpad to see events
   ```

3. **Verify X11 is using libinput:**
   ```bash
   grep -i "libinput" /var/log/Xorg.0.log
   ```

### Keyboard Backlight Not Working

1. **Check if backlight device exists:**
   ```bash
   ls -la /sys/class/leds/*kbd_backlight*/brightness
   ```

2. **Verify permissions:**
   ```bash
   # Should be writable by 'video' group
   ls -l /sys/class/leds/*/brightness
   ```

3. **Test manually:**
   ```bash
   # Find keyboard backlight device
   brightnessctl --list | grep kbd
   
   # Try setting brightness
   brightnessctl --device='*::kbd_backlight' set 100%
   ```

### Gestures Not Working

1. **Check if libinput-gestures is running:**
   ```bash
   ps aux | grep libinput-gestures
   ```

2. **Start/restart the service:**
   ```bash
   libinput-gestures-setup start
   libinput-gestures-setup restart
   ```

3. **Check for errors:**
   ```bash
   libinput-gestures-setup status
   ```

4. **Verify user is in input group:**
   ```bash
   groups | grep input
   ```

## Tools and Utilities

All input-related tools are pre-installed:

- **brightnessctl**: Control screen and keyboard brightness
- **libinput**: Input device management and debugging
- **xinput**: X11 input device configuration
- **evtest**: Low-level input event testing
- **xdotool**: Simulate keyboard/mouse input
- **libinput-gestures**: Multitouch gesture recognition
- **acpi / acpid**: ACPI event monitoring and handling

## Advanced Configuration

### Custom ACPI Events

Add custom handlers in `/etc/hypervisor/configuration/hardware-input.nix`:

```nix
services.acpid.handlers.myCustomKey = {
  event = "button/custom.*";
  action = ''
    # Your custom action here
    ${pkgs.notify-send}/bin/notify-send "Custom key pressed"
  '';
};
```

### Touchpad Profiles

Create per-application touchpad settings using GUI tools:
- **GNOME Settings**: Settings → Mouse & Touchpad
- **GNOME Tweaks**: Advanced touchpad configuration

### Keyboard Shortcuts

System-wide shortcuts can be configured in GNOME Settings or via dconf/gsettings.

## References

- [libinput documentation](https://wayland.freedesktop.org/libinput/doc/latest/)
- [NixOS Manual - X11](https://nixos.org/manual/nixos/stable/#sec-x11)
- [libinput-gestures GitHub](https://github.com/bulletmark/libinput-gestures)

## Integration with Hypervisor

When managing VMs through the GNOME interface:
- Touchpad gestures work seamlessly in virt-manager
- Keyboard shortcuts are captured by the host (use Ctrl+Alt to release in VM viewers)
- Brightness controls always affect the host system, not VMs
- Input devices can be passed through to VMs if needed (USB passthrough)

---

**Note**: Input device support is automatically enabled when using the GUI management interface. For headless/console-only operation, these features remain dormant but don't interfere with system operation.
