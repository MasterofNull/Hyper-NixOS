# Quick Fix: Installer Not Accepting Input

## Your Issue

You ran:
```bash
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh | sudo bash
```

The menu appeared, you typed "1", but it said "No input received" and used the default.

## The Solution: Use This Command Instead

```bash
sudo bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)
```

**Why this works:**
- Uses process substitution `<(...)` instead of pipe `|`
- Terminal input works properly
- Interactive menu will accept your choice

## Or: Skip the Prompt Entirely

If you know which download method you want:

```bash
# Use tarball download (fastest, no git needed)
HYPER_INSTALL_METHOD=tarball sudo -E bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)

# Or use git HTTPS clone
HYPER_INSTALL_METHOD=https sudo -E bash <(curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh)
```

## What Was Fixed

The installer script has been updated to:
1. Better detect when terminal input is available
2. Use more reliable file descriptor methods
3. Provide better error messages
4. Recommend the working method

## Download Methods

When the installer asks, these are your options:

- **1) Download Tarball** - Fastest, no git needed (default)
- **2) Git Clone (HTTPS)** - Public access, uses git
- **3) Git Clone (SSH)** - Requires GitHub SSH key
- **4) Git Clone (Token)** - Requires GitHub personal access token

## Still Having Issues?

Download the script first, inspect it, then run:

```bash
# Step 1: Download
curl -sSL https://raw.githubusercontent.com/MasterofNull/Hyper-NixOS/main/install.sh -o /tmp/install.sh

# Step 2: Inspect (optional)
less /tmp/install.sh

# Step 3: Run
sudo bash /tmp/install.sh
```

This is the most reliable method and lets you review the code before running.

---

**Bottom line:** Replace `| sudo bash` with `sudo bash <(...)` and it will work!
