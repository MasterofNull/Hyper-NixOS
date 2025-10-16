# Git Hooks for Hyper-NixOS

This directory contains git hooks that help maintain code quality.

## Installation

To install the hooks, run from the repository root:

```bash
# Install pre-commit hook
ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit

# Or use git config to set hooks directory (Git 2.9+)
git config core.hooksPath .githooks
```

## Available Hooks

### pre-commit

Validates shell scripts before committing:

- ✅ Checks for `echo` commands with color codes missing `-e` flag
- ✅ Prevents commits with formatting issues
- ✅ Fast - only checks staged files

**Skip if needed** (not recommended):
```bash
git commit --no-verify
```

## Automatic Fixes

If the pre-commit hook finds issues, fix them automatically:

```bash
./scripts/validate-echo-colors.sh --fix
```

Then stage the changes and commit again:

```bash
git add -u
git commit
```

## Manual Validation

Check all scripts without committing:

```bash
./scripts/validate-echo-colors.sh
```

## Why These Checks?

Shell scripts use ANSI escape codes for colors. Without the `-e` flag, `echo` treats escape sequences as literal text:

```bash
# ❌ Wrong - shows: \033[0;32m✓\033[0m Success
echo "  ${GREEN}✓${NC} Success"

# ✓ Correct - shows: ✓ Success (with green color)
echo -e "  ${GREEN}✓${NC} Success"
```

This ensures all colored output renders correctly for users.
