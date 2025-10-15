# Licensing and Attribution Guide

This document explains Hyper-NixOS's licensing structure and how to properly attribute the open source components we use.

---

## Overview

Hyper-NixOS is an **MIT Licensed** project that integrates numerous open source components. While our original code is MIT licensed, we use and respect the licenses of all dependencies.

### Key Documents
1. **LICENSE** - Hyper-NixOS's MIT License
2. **THIRD_PARTY_LICENSES.md** - Complete list of all third-party licenses
3. **CREDITS.md** - Project attributions and acknowledgments
4. **This document** - Guide for developers and contributors

---

## License Summary

### Hyper-NixOS Original Code
- **License**: MIT License
- **Copyright**: © 2024-2025 MasterofNull
- **Applies to**: Original scripts, modules, documentation, and orchestration code

### What is MIT License?
The MIT License is one of the most permissive open source licenses:
- ✅ Commercial use allowed
- ✅ Modification allowed
- ✅ Distribution allowed
- ✅ Private use allowed
- ⚠️ Must include license and copyright notice
- ⚠️ No warranty provided

---

## Third-Party Component Licenses

### GPL-2.0 (GNU General Public License v2.0)
**Components**: QEMU, KVM, iptables/nftables, AppArmor
- Used as separate programs, not linked/modified
- Source available through nixpkgs
- If you modify these components, you must publish modifications

### LGPL-2.1+ (GNU Lesser General Public License v2.1+)
**Components**: Libvirt, SystemD, PolicyKit
- Used as system libraries without modification
- Linking is permitted without source disclosure requirements
- Modifications would require source disclosure

### Apache License 2.0
**Components**: Prometheus, Node Exporter, Restic workflows
- Permissive license similar to MIT
- Requires NOTICE file if provided
- Patent grant included

### AGPL-3.0 (GNU Affero General Public License v3.0)
**Components**: Grafana (optional monitoring component)
- Used as-is from nixpkgs without modifications
- If modified and run as network service, must provide source
- We use it unmodified, so no additional requirements

### BSD Licenses (2-Clause, 3-Clause)
**Components**: Restic, Go toolchain
- Very permissive, similar to MIT
- Requires attribution in binary distributions

---

## File Header Standards

### Nix Configuration Files

```nix
# Hyper-NixOS [Module Name]
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# This module configures:
# - [Component Name] ([License], [Copyright Holder])
# - [Additional components as needed]
#
# These components are used as provided by nixpkgs.
# See THIRD_PARTY_LICENSES.md for complete information.
#
# Attribution:
# - [Component]: [URL]

{ config, lib, pkgs, ... }:
```

### Shell Scripts

```bash
#!/usr/bin/env bash
# Hyper-NixOS [Script Name]
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# This script uses:
# - Bash (GPL-3.0+, Free Software Foundation)
# - [Other components as needed]
#
# For license information, see:
# - LICENSE - Hyper-NixOS license
# - THIRD_PARTY_LICENSES.md - Dependencies
```

### Python Scripts

```python
#!/usr/bin/env python3
# Hyper-NixOS [Script Name]
#
# Copyright (c) 2024-2025 MasterofNull
# Licensed under the MIT License
#
# This script uses:
# - Python (PSF License, Python Software Foundation)
# - [Additional libraries as needed]
#
# See LICENSE and THIRD_PARTY_LICENSES.md for details
```

### Documentation Files

```markdown
# Document Title

Copyright (c) 2024-2025 MasterofNull  
Licensed under the MIT License

For complete licensing information, see:
- LICENSE - Hyper-NixOS license
- THIRD_PARTY_LICENSES.md - Dependencies
- CREDITS.md - Attributions
```

---

## When to Add Attribution

### Always Attribute
1. **Direct Use**: When using a library, tool, or service
2. **Configuration**: When configuring third-party software
3. **Patterns**: When following specific design patterns from other projects
4. **Concepts**: When implementing concepts inspired by other projects (note as inspiration)

### Examples

**Direct Use (Libvirt module)**:
```nix
# This module configures:
# - Libvirt (LGPL-2.1+, Red Hat, Inc.)
# - QEMU (GPL-2.0, Fabrice Bellard)
```

**Inspiration (Not copied code)**:
```nix
# VM management workflow inspired by Proxmox VE
# No code copied - conceptual inspiration only
# See CREDITS.md for attribution
```

---

## License Compatibility

### MIT License Compatibility Matrix

| Their License | Can Use? | Requirements |
|---------------|----------|--------------|
| MIT/BSD | ✅ Yes | Include their license |
| Apache 2.0 | ✅ Yes | Include NOTICE if provided |
| LGPL-2.1+ | ✅ Yes | Don't modify, just use |
| GPL-2.0/3.0 | ✅ Yes* | Keep as separate programs |
| AGPL-3.0 | ✅ Yes* | Use unmodified from nixpkgs |

*As long as we don't create derivative works or link/modify the code

### Safe Integration Patterns

1. **System Programs**: Running GPL programs as separate processes ✅
2. **System Libraries**: Using LGPL libraries through standard APIs ✅
3. **Configuration**: Configuring software without modifying it ✅
4. **Inspiration**: Using concepts/ideas without copying code ✅

---

## How We Use Each License Type

### GPL Components (QEMU, KVM, etc.)
- **How**: Via NixOS/nixpkgs, as system programs
- **Modifications**: None - used as-is
- **Source**: Available through nixpkgs
- **Compliance**: No additional requirements (not derivative works)

### LGPL Components (Libvirt, SystemD)
- **How**: System libraries, standard APIs
- **Modifications**: None - configured, not modified
- **Linking**: Through standard system interfaces
- **Compliance**: No additional requirements (not modifying)

### Apache 2.0 (Prometheus, etc.)
- **How**: Via nixpkgs, configured through our modules
- **Modifications**: None
- **Requirements**: Acknowledge in THIRD_PARTY_LICENSES.md ✅
- **Compliance**: Complete

### AGPL (Grafana)
- **How**: Optional component from nixpkgs
- **Modifications**: None
- **Network Service**: Used as-is
- **Compliance**: No modifications means no disclosure required

---

## For Contributors

### When Adding New Dependencies

1. **Identify the license**:
   ```bash
   # Check nixpkgs metadata
   nix-instantiate --eval -E 'with import <nixpkgs> {}; package.meta.license'
   
   # Or check upstream project
   ```

2. **Add to THIRD_PARTY_LICENSES.md**:
   - Project name and description
   - License type
   - Copyright holder
   - URL
   - How we use it

3. **Add to CREDITS.md**:
   - Project name
   - Attribution note
   - Link to project

4. **Add header to relevant files**:
   - List the components used
   - Note their licenses
   - Reference THIRD_PARTY_LICENSES.md

### When Using Patterns/Concepts

If you're inspired by another project's approach:

```nix
# VM clustering approach inspired by Harvester HCI
# (https://harvesterhci.io/, Apache 2.0)
# No code copied - architectural inspiration only
# See CREDITS.md for full attribution
```

---

## For Distributors

### If You Distribute Hyper-NixOS

1. **Must Include**:
   - LICENSE file (MIT License)
   - THIRD_PARTY_LICENSES.md
   - CREDITS.md
   - Copyright notices in all files

2. **Must Not**:
   - Remove or alter copyright notices
   - Claim the work as solely yours
   - Remove attribution to dependencies

3. **May**:
   - Use commercially
   - Modify and redistribute
   - Use privately
   - Sublicense (but MIT terms still apply)

### If You Modify Hyper-NixOS

1. **Original Code (MIT)**:
   - Modifications can be any license (but keep MIT for original)
   - Must keep LICENSE file
   - Must keep copyright notices

2. **GPL Components**:
   - If you modify QEMU, KVM, etc.: Must release modifications
   - If you just configure: No requirement

3. **AGPL Components (Grafana)**:
   - If you modify Grafana: Must release modifications
   - If you run modified Grafana as service: Must provide source
   - If you use as-is: No requirement

---

## Common Questions

### Q: Can I use Hyper-NixOS commercially?
**A**: Yes! The MIT License explicitly allows commercial use.

### Q: Do I need to open-source my modifications?
**A**: For Hyper-NixOS original code (MIT): No  
For GPL/LGPL/AGPL components: Only if you modify them

### Q: Can I remove the license files?
**A**: No. MIT License requires the copyright notice and license be included in all copies.

### Q: What if I only use parts of Hyper-NixOS?
**A**: Include the LICENSE file and maintain copyright notices for any parts you use.

### Q: Do I need to attribute NixOS?
**A**: Yes, if you distribute. NixOS is MIT licensed and requires attribution.

### Q: Can I sell Hyper-NixOS?
**A**: Yes, but you must:
- Include all license files
- Not remove copyright notices
- Make it clear what's original and what's from us

---

## Compliance Checklist

### For Distributions

- [ ] LICENSE file included
- [ ] THIRD_PARTY_LICENSES.md included
- [ ] CREDITS.md included
- [ ] Copyright notices maintained in all files
- [ ] No modifications to GPL/LGPL components (or disclosed if modified)
- [ ] Attribution to all upstream projects maintained

### For Modifications

- [ ] Original copyright notices maintained
- [ ] Your modifications clearly marked
- [ ] License compatibility verified
- [ ] GPL/LGPL/AGPL modifications disclosed (if any)
- [ ] New dependencies documented

### For New Features

- [ ] New dependencies identified
- [ ] Licenses documented in THIRD_PARTY_LICENSES.md
- [ ] Credits added to CREDITS.md
- [ ] File headers updated
- [ ] License compatibility verified

---

## Resources

### License Texts
- MIT License: https://opensource.org/licenses/MIT
- GPL-2.0: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
- LGPL-2.1: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
- Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
- AGPL-3.0: https://www.gnu.org/licenses/agpl-3.0.html

### Tools
- License compatibility: https://www.gnu.org/licenses/license-compatibility.html
- Choose a License: https://choosealicense.com/
- SPDX License List: https://spdx.org/licenses/

### Getting Help
- Licensing questions: Open an issue on GitHub
- Complex scenarios: Consult with a lawyer
- Community guidance: NixOS Discourse

---

## Updates

This document is maintained alongside the project. When adding dependencies:

1. Update THIRD_PARTY_LICENSES.md
2. Update CREDITS.md
3. Update file headers
4. Update this guide if needed

---

**Last Updated**: 2025-10-15  
**Maintainer**: MasterofNull  
**Contact**: See project repository for contact information

---

## Summary

**Hyper-NixOS** is MIT Licensed and respects all upstream licenses. We:
- ✅ Properly attribute all dependencies
- ✅ Use GPL/LGPL software as system components
- ✅ Don't modify upstream code (just configure)
- ✅ Maintain comprehensive license documentation
- ✅ Follow open source best practices

**When in doubt**: Attribute generously and maintain all copyright notices. It's always better to over-attribute than under-attribute.

---

For questions about licensing, see our documentation or open an issue on GitHub.
