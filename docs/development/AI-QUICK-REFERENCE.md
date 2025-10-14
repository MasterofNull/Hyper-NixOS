# AI Agent Quick Reference Card

## 🚀 Essential Commands

### Always Run After Implementation
```bash
./audit-platform.sh          # Must show 100% pass rate
./test-platform-features.sh  # Verify features work
./validate-implementation.sh # Confirm completeness
```

### File Organization Commands
```bash
# Move docs to proper locations
mkdir -p docs/{guides,reports,implementation,development,deployment}

# Move files by type
find . -name "*QUICKSTART*.md" -exec mv {} docs/guides/ \;
find . -name "*REPORT*.md" -exec mv {} docs/reports/ \;
find . -name "*IMPLEMENTATION*.md" -exec mv {} docs/implementation/ \;
```

## ⚠️ Critical Requirements

### Resource Constants (MUST HAVE)
```bash
# In modular-security-framework.sh
readonly MAX_MEMORY_MINIMAL="512M"
readonly MAX_MEMORY_STANDARD="2048M"
readonly MAX_MEMORY_ADVANCED="4096M"
readonly MAX_MEMORY_ENTERPRISE="16384M"

readonly MAX_CPU_MINIMAL="25"
readonly MAX_CPU_STANDARD="50"
readonly MAX_CPU_ADVANCED="75"
readonly MAX_CPU_ENTERPRISE="90"
```

### File Permissions
```bash
chmod +x *.sh                    # All shell scripts executable
chmod 644 *.yaml *.json *.md    # Config and docs readable
```

### Directory Structure
```
workspace/
├── docs/          # ALL documentation here
├── scripts/       # Implementation scripts
├── modules/       # Feature modules
└── *.sh          # Only executables in root
```

## 🔍 Common Audit Failures

| Failure | Cause | Fix |
|---------|-------|-----|
| Resource limits | Missing MAX_* constants | Add constants to framework |
| Docs not found | Wrong location | Move to docs/ subdirs |
| Not executable | Wrong permissions | chmod +x script.sh |
| Syntax error | Bash/Python issues | Run syntax check first |

## 📋 Implementation Checklist

Before starting:
- [ ] Read [AI Lessons Learned](AI-LESSONS-LEARNED.md)
- [ ] Understand audit requirements
- [ ] Plan file organization

During implementation:
- [ ] Test incrementally with audit script
- [ ] Keep docs organized in folders
- [ ] Use correct naming conventions
- [ ] Maintain 100% audit pass rate

After implementation:
- [ ] Run full audit suite
- [ ] Organize all documentation
- [ ] Update this reference if needed
- [ ] Verify 100% success rate

## 🎯 Golden Rules

1. **100% or bust** - 97% is not acceptable
2. **Test early, test often** - Don't wait until the end
3. **Organization matters** - Clean structure = clean code
4. **Details count** - Exact naming, paths, permissions
5. **Document everything** - Including problems faced

## 🆘 Quick Fixes

```bash
# Fix all permissions at once
find . -name "*.sh" -exec chmod +x {} \;

# Update all paths after moving files
grep -r "old/path" . --include="*.sh" | sed 's|old/path|new/path|g'

# Check what audit is looking for
grep "test_check" audit-platform.sh

# See what's failing
./audit-platform.sh | grep "✗"
```

---

**Remember**: The audit script is the source of truth. If it fails, the implementation is incomplete.