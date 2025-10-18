# Hyper-NixOS Branding Standards

This document defines the official branding standards for Hyper-NixOS. All contributors must follow these guidelines to maintain consistency across the project.

## Project Identity

### Official Name
**Hyper-NixOS** (capital H, capital N, capital O, capital S, hyphen between Hyper and NixOS)

**Incorrect:**
- ❌ hypernixos
- ❌ Hyper NixOS (space instead of hyphen)
- ❌ hyper-nixos (lowercase)
- ❌ HyperNixOS (no hyphen)

**Correct:**
- ✅ Hyper-NixOS

### Tagline
"Next-Generation Virtualization Platform"

### Project Information
- **Author:** MasterofNull
- **Copyright:** © 2024-2025 MasterofNull
- **License:** MIT License
- **Repository:** https://github.com/MasterofNull/Hyper-NixOS
- **Version:** Semantic versioning (e.g., 1.0.0)

## Visual Identity

### ASCII Art Logo (Large)

Use this in:
- Wizard main screens
- First-boot experience
- Documentation headers
- Marketing materials

```
╦ ╦┬ ┬┌─┐┌─┐┬─┐   ╔╗╔┬─┐ ┬╔═╗╔═╗
╠═╣└┬┘├─┘├┤ ├┬┘───║║║│┌┴┬┘║ ║╚═╗
╩ ╩ ┴ ┴  └─┘┴└─   ╝╚╝┴┴ └─╚═╝╚═╝
Next-Generation Virtualization Platform
```

### Compact Banner

Use this in:
- CLI tool output
- Script headers
- Log messages

```
╔════════════════════════════════════════════╗
║  Hyper-NixOS v1.0.0                        ║
║  Next-Gen Virtualization Platform          ║
╚════════════════════════════════════════════╝
```

### Mini Banner (Single Line)

Use this in:
- Quick status messages
- Progress indicators
- Inline references

```
═══ Hyper-NixOS v1.0.0 ═══
```

## Color Scheme

### Terminal Colors

The branding library (`scripts/lib/branding.sh`) defines these colors:

```bash
BLUE='\033[0;34m'      # Primary brand color
CYAN='\033[0;36m'      # Secondary highlights
GREEN='\033[0;32m'     # Success/positive
YELLOW='\033[1;33m'    # Warnings
RED='\033[0;31m'       # Errors/critical
MAGENTA='\033[0;35m'   # Special features
NC='\033[0m'           # No Color (reset)
BOLD='\033[1m'         # Emphasis
```

### Usage Guidelines

- **BLUE**: Project name, borders, primary branding
- **CYAN**: URLs, links, technical details
- **GREEN**: Success messages, positive indicators
- **YELLOW**: Warnings, important notices
- **RED**: Errors, critical warnings
- **MAGENTA**: Special features, highlights
- **BOLD**: Important text, headings

## File Headers

### Bash Scripts (.sh)

Every bash script must include this header:

```bash
#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: <filename>
# Purpose: <brief description>
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################
```

**Placement:**
- Line 1: Shebang
- Lines 2-14: Header block
- Line 15: Empty line
- Line 16: Begin script content

### Nix Modules (.nix)

Every Nix module must include this header:

```nix
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: <filename>
# Purpose: <brief description>
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

{ config, lib, pkgs, ... }:
```

### Python Scripts (.py)

```python
#!/usr/bin/env python3
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: <filename>
# Purpose: <brief description>
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################
"""
Module docstring with detailed description.
"""
```

### Rust Files (.rs)

```rust
////////////////////////////////////////////////////////////////////////////////
// Hyper-NixOS - Next-Generation Virtualization Platform
// https://github.com/MasterofNull/Hyper-NixOS
//
// Module: <filename>
// Purpose: <brief description>
//
// Copyright © 2024-2025 MasterofNull
// Licensed under the MIT License
//
// Author: MasterofNull
////////////////////////////////////////////////////////////////////////////////

//! Module documentation
```

### Go Files (.go)

```go
////////////////////////////////////////////////////////////////////////////////
// Hyper-NixOS - Next-Generation Virtualization Platform
// https://github.com/MasterofNull/Hyper-NixOS
//
// Package: <package name>
// Purpose: <brief description>
//
// Copyright © 2024-2025 MasterofNull
// Licensed under the MIT License
//
// Author: MasterofNull
////////////////////////////////////////////////////////////////////////////////

package packagename
```

## Documentation Standards

### Markdown Headers

All `.md` files should include a footer:

```markdown
---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
```

**Exception:** README.md has its own custom footer with badges and additional info.

### Document Titles

Format: `# Title - Hyper-NixOS`

Example:
```markdown
# Installation Guide - Hyper-NixOS

Brief description of document.
```

## Branding Library Usage

### Sourcing the Library

All user-facing scripts should source the branding library:

```bash
# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source branding library with fallback
source "${SCRIPT_DIR}/lib/branding.sh" 2>/dev/null || {
    # Fallback color definitions if branding unavailable
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
    BOLD='\033[1m'
}
```

### Available Functions

```bash
# Banners
show_banner_large       # Full ASCII art banner
show_banner_compact     # Compact boxed banner
show_banner_mini        # Single-line mini banner

# Footers
show_footer            # Full footer with all info
show_footer_compact    # Compact single-line footer

# Information
show_mini_header       # Short header with version
show_version           # Version information
show_credits           # Full credits screen
show_copyright         # Single copyright line
show_license_notice    # Full MIT license text
```

### Banner Usage Guidelines

**Wizards and Interactive Tools:**
```bash
main() {
    clear
    show_banner_large
    # ... wizard content
    show_footer
}
```

**CLI Commands:**
```bash
main() {
    show_banner_compact
    # ... command output
}
```

**Background/Automated Scripts:**
```bash
# No banner needed, but include header comments
# and log with project name
log "Hyper-NixOS: Starting backup process..."
```

## Systemd Services

All systemd service descriptions must be prefixed with "Hyper-NixOS:":

```nix
systemd.services.myservice = {
  description = "Hyper-NixOS: Service description";
  # ...
};
```

**Examples:**
```nix
description = "Hyper-NixOS: Password Protection Service";
description = "Hyper-NixOS: VM Lifecycle Manager";
description = "Hyper-NixOS: Threat Detection Monitor";
```

## CLI Tools

### Version Flag

All CLI tools must support `--version`:

```bash
$ hv --version
Hyper-NixOS v1.0.0
© 2024-2025 MasterofNull | MIT License
```

### Credits Flag

All main CLI tools should support `--credits`:

```bash
$ hv --credits
╦ ╦┬ ┬┌─┐┌─┐┬─┐   ╔╗╔┬─┐ ┬╔═╗╔═╗
╠═╣└┬┘├─┘├┤ ├┬┘───║║║│┌┴┬┘║ ║╚═╗
╩ ╩ ┴ ┴  └─┘┴└─   ╝╚╝┴┴ └─╚═╝╚═╝
Next-Generation Virtualization Platform

PROJECT CREDITS
[... full credits from branding.sh ...]
```

### License Flag

All CLI tools should support `--license`:

```bash
$ hv --license
[... full MIT license text ...]
```

## MOTD (Message of the Day)

The system MOTD should include Hyper-NixOS branding:

```
╔═══════════════════════════════════════════════════════════╗
║             Welcome to Hyper-NixOS                         ║
║       Next-Generation Virtualization Platform              ║
╚═══════════════════════════════════════════════════════════╝

Quick Start:
  • Run 'hv help' for command reference
  • Run 'hv discover' to see system capabilities
  • Run 'hv vm-create' to create your first VM

Documentation: /usr/share/doc/hypervisor/
Project: https://github.com/MasterofNull/Hyper-NixOS
```

## Web Interface

### Page Titles
Format: `Feature Name - Hyper-NixOS`

Example: `Dashboard - Hyper-NixOS`

### Logo Display
- Use SVG version of ASCII art logo when available
- Maintain aspect ratio
- Include alt text: "Hyper-NixOS Logo"

### Footer
All web pages must include:
```
Hyper-NixOS v1.0.0 | © 2024-2025 MasterofNull | MIT License
```

## Git Commit Messages

While not strictly branding, commit messages should reference components by their proper names:

```
feat(vm-management): add Windows 11 template

fix(security): resolve password protection race condition

docs(README): update installation instructions
```

## README Badges

Standard badges for README.md:

```markdown
[![NixOS](https://img.shields.io/badge/NixOS-24.05-blue.svg)](https://nixos.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Beta-yellow.svg)](https://github.com/MasterofNull/Hyper-NixOS)
```

## External References

When referencing Hyper-NixOS in external documentation, blogs, or communications:

**Correct:**
- "We use Hyper-NixOS for our virtualization needs"
- "Hyper-NixOS is a next-generation virtualization platform"
- "Built on Hyper-NixOS"

**Avoid:**
- "We use hyper-nixos" (lowercase)
- "Powered by HyperNixOS" (no hyphen)
- "Running on Hyper NixOS" (space instead of hyphen)

## Enforcement

### Automated Checks

The following can be automated in CI:

- [ ] All `.sh` files have proper headers
- [ ] All `.nix` files have proper headers
- [ ] All `.md` files have proper footers
- [ ] All systemd services use "Hyper-NixOS:" prefix
- [ ] CLI tools respond to `--version`

### Manual Review

During PR review, check:

- [ ] Branding is consistent
- [ ] Project name is correctly capitalized
- [ ] Colors follow guidelines
- [ ] Banners are displayed appropriately
- [ ] Documentation is properly formatted

## Tools

### Header Templates

Use the provided templates in `scripts/lib/`:

```bash
# For new bash scripts
cp scripts/lib/TEMPLATE.sh scripts/my-new-script.sh
# Edit and customize
```

### Branding Functions

Always use functions from `scripts/lib/branding.sh` rather than duplicating:

```bash
# Good
source "${SCRIPT_DIR}/lib/branding.sh"
show_banner_large

# Bad - don't duplicate
echo "╦ ╦┬ ┬┌─┐┌─┐┬─┐   ╔╗╔┬─┐ ┬╔═╗╔═╗"
# ...
```

## Updates and Maintenance

### When to Update Branding

- New major version release (update version numbers)
- Copyright year changes (update © 2024-2025)
- Tagline or positioning changes (update all references)
- New branding assets (update templates and docs)

### Branding Review Checklist

Before release, verify:

- [ ] All version numbers are updated
- [ ] Copyright years are current
- [ ] All headers are present and correct
- [ ] Branding library is up to date
- [ ] Documentation footers are correct
- [ ] Web interface reflects current branding
- [ ] MOTD is current
- [ ] CLI tools show correct version

## Questions?

If you're unsure about branding usage:

1. Check this document first
2. Review `scripts/lib/branding.sh` for examples
3. Look at existing files for patterns
4. Ask in GitHub Discussions
5. Reference CONTRIBUTING.md

## Examples

### Good Branding Examples

**Script Header:**
```bash
#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: vm-manager.sh
# Purpose: Manages virtual machine lifecycle operations
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

source "${SCRIPT_DIR}/lib/branding.sh"

main() {
    show_banner_large
    # ... functionality
    show_footer
}
```

**Nix Module:**
```nix
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: vm-lifecycle.nix
# Purpose: Virtual machine lifecycle management
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

{ config, lib, pkgs, ... }:

{
  options.hypervisor.vm-lifecycle = {
    enable = lib.mkEnableOption "VM lifecycle management";
  };
}
```

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
