# Contributing to Hyper-NixOS

Thank you for your interest in contributing to Hyper-NixOS! We welcome contributions from everyone, whether you're fixing a typo, adding a feature, or improving documentation.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Branding Guidelines](#branding-guidelines)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Licensing](#licensing)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for all. Please be respectful and constructive in your interactions.

### Expected Behavior

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- NixOS 24.05 or later (for full development)
- Basic knowledge of Nix, Bash, and virtualization concepts
- Git for version control

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR-USERNAME/Hyper-NixOS.git
cd Hyper-NixOS

# Add upstream remote
git remote add upstream https://github.com/MasterofNull/Hyper-NixOS.git
```

### Development Environment

```bash
# Enter development shell (provides all needed tools)
nix-shell

# Or use direnv for automatic environment loading
echo "use nix" > .envrc
direnv allow
```

## Development Workflow

### 1. Create a Branch

```bash
# Update your fork
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### 2. Make Changes

Follow our coding standards (see below) and keep commits focused and atomic.

### 3. Test Your Changes

```bash
# Run all tests
./tests/run_all_tests.sh

# Test specific component
sudo nixos-rebuild test  # Test NixOS config without making it default
```

### 4. Commit Your Changes

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "module/area: brief description

Detailed explanation of changes and why they were made.

Fixes #123"  # Reference issues if applicable
```

#### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style/formatting (no functional changes)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(vm): add Windows 11 template support

Implements intelligent defaults for Windows 11 VMs including
TPM 2.0 and secure boot configuration.

Closes #156
```

```
fix(security): prevent password wipe on rebuild

Adds systemd service to backup user credentials before
system rebuild operations.

Fixes #187
```

## Coding Standards

### Nix Code

```nix
# Use 2-space indentation
{
  config = {
    hypervisor.feature = {
      enable = true;
      option = "value";
    };
  };
}

# Prefer lib.mkIf for conditionals
config = lib.mkIf config.hypervisor.feature.enable {
  # configuration
};

# Always add descriptions to options
options.hypervisor.feature.enable = lib.mkEnableOption "description";

# Use lib.mkEnableOption, lib.mkOption, etc.
```

### Bash Scripts

```bash
#!/usr/bin/env bash
# Always include our standard header (see Branding Guidelines)

# Use strict error handling
set -euo pipefail

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/branding.sh"

# Use readonly for constants
readonly CONSTANT_VALUE="value"

# Quote variables
echo "${VARIABLE}"

# Use [[ ]] for conditionals, not [ ]
if [[ "${CONDITION}" == "value" ]]; then
    # code
fi

# Function documentation
# Description of what function does
function_name() {
    local param1="$1"
    local param2="${2:-default}"

    # implementation
}
```

### Python Code

```python
# Follow PEP 8
# Use type hints
# Include docstrings

def function_name(param: str) -> bool:
    """
    Brief description.

    Args:
        param: Description of parameter

    Returns:
        Description of return value
    """
    pass
```

### Rust Code

```rust
// Follow standard Rust conventions
// Use rustfmt for formatting
// Include documentation comments

/// Brief description of function
///
/// # Arguments
///
/// * `param` - Description of parameter
///
/// # Returns
///
/// Description of return value
pub fn function_name(param: &str) -> Result<bool, Error> {
    // implementation
}
```

## Branding Guidelines

All source files must include proper branding headers.

### Bash Scripts

Every `.sh` file must start with:

```bash
#!/usr/bin/env bash
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Script: filename.sh
# Purpose: Brief description of what this script does
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################
```

### Nix Modules

Every `.nix` file in `modules/` should start with:

```nix
################################################################################
# Hyper-NixOS - Next-Generation Virtualization Platform
# https://github.com/MasterofNull/Hyper-NixOS
#
# Module: filename.nix
# Purpose: Brief description of what this module does
#
# Copyright © 2024-2025 MasterofNull
# Licensed under the MIT License
#
# Author: MasterofNull
################################################################################

{ config, lib, pkgs, ... }:
```

### Wizards and User-Facing Scripts

Wizards should display the Hyper-NixOS banner:

```bash
# Source branding library
source "${SCRIPT_DIR}/lib/branding.sh"

# In main function or at start:
show_banner_large    # For full wizard experience
# or
show_banner_compact  # For smaller UI elements
```

### Markdown Documentation

All `.md` files should include a footer:

```markdown
---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
```

## Testing Requirements

### Before Submitting

1. **Run all tests:**
   ```bash
   ./tests/run_all_tests.sh
   ```

2. **Test NixOS rebuild:**
   ```bash
   sudo nixos-rebuild test
   ```

3. **Lint your code:**
   ```bash
   # Bash
   shellcheck scripts/*.sh

   # Nix
   nix-instantiate --parse <file> > /dev/null

   # Python
   pylint <file>

   # Rust
   cargo clippy
   ```

### Writing Tests

- Add unit tests for new functions
- Add integration tests for new features
- Update existing tests if behavior changes
- Document test scenarios in test files

Example test structure:

```bash
#!/usr/bin/env bash
# Test: Description of what is being tested

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

test_feature() {
    # Setup
    local expected="value"

    # Execute
    local result=$(your_function)

    # Assert
    if [[ "$result" == "$expected" ]]; then
        echo "✓ Test passed"
        return 0
    else
        echo "✗ Test failed: expected $expected, got $result"
        return 1
    fi
}

# Run test
test_feature
```

## Documentation

### Required Documentation

When adding a feature, you must update:

1. **README.md** - If it's a user-facing feature
2. **docs/user-guides/** - User guide for the feature
3. **docs/reference/** - Technical reference
4. **Code comments** - Inline documentation
5. **docs/dev/CLAUDE.md** - If it affects development workflow

### Documentation Style

- Use clear, concise language
- Include code examples
- Add screenshots for UI features
- Link to related documentation
- Keep formatting consistent

## Pull Request Process

### Before Submitting

- [ ] All tests pass
- [ ] Code follows style guidelines
- [ ] Branding headers are present
- [ ] Documentation is updated
- [ ] Commit messages are descriptive
- [ ] No merge conflicts with main

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How this was tested

## Checklist
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Branding headers added
- [ ] Follows code style
- [ ] No merge conflicts

## Related Issues
Fixes #123
Related to #456
```

### Review Process

1. Submit PR with clear description
2. Automated tests will run
3. Maintainers will review code
4. Address any requested changes
5. PR will be merged once approved

### After Merge

- Your contribution will be acknowledged in AUTHORS.md
- Close related issues
- Share your contribution!

## Licensing

### Contributor License Agreement

By contributing to Hyper-NixOS, you agree that:

1. Your contributions will be licensed under the MIT License
2. You have the right to submit the contribution
3. You grant us the right to distribute your contribution under the MIT License

### Third-Party Code

If including third-party code or dependencies:

1. Ensure it's compatible with MIT License
2. Document the source and license in `THIRD_PARTY_LICENSES.md`
3. Add proper attribution in code comments
4. Include original copyright notices

### Copyright

- All original contributions: © 2024-2025 MasterofNull
- Contributor copyright: © Year Your Name (for substantial contributions)
- Must be compatible with project MIT License

## Questions?

### Get Help

- **Documentation**: Check `docs/` directory first
- **Issues**: Search existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions
- **IRC/Matrix**: (To be announced)

### Contact

- **Project Maintainer**: MasterofNull
- **GitHub**: https://github.com/MasterofNull/Hyper-NixOS
- **Issues**: https://github.com/MasterofNull/Hyper-NixOS/issues

## Recognition

Contributors are recognized in:

- AUTHORS.md file
- Release notes
- Project documentation
- Git commit history

Thank you for contributing to Hyper-NixOS!

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
