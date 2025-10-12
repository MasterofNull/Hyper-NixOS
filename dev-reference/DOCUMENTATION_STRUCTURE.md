# Hyper-NixOS Documentation Structure

This document explains the organization of documentation in the Hyper-NixOS project.

## Directory Structure

### `/` (Root Directory)
**Purpose**: Essential user-facing information and quick start guides

**Contents**:
- `README.md` - Main project overview and getting started
- `ENTERPRISE_QUICK_START.md` - Quick start guide for enterprise deployments
- `CREDITS.md` - Project credits and acknowledgments
- `LICENSE` - Software license (GPL v3.0)
- `VERSION` - Current version number

**Guidelines**:
- Keep concise and immediately useful
- Focus on "getting started" information
- Maximum 2-3 markdown files plus standard files
- All files should answer: "What do I need to know right now?"

---

### `/docs/` (User Documentation)
**Purpose**: Comprehensive user-facing documentation and guides

**Contents**:
- Architecture and design documents
- Configuration guides
- Feature documentation
- Security model documentation
- Troubleshooting guides
- Best practices
- User-facing migration guides

**Current Files**:
- `GUI_CONFIGURATION.md` - GUI setup and configuration
- `MENU_STRUCTURE.md` - Menu system usage and navigation
- `MIGRATION_GUIDE.md` - Migration guide for users upgrading
- `NETWORKING_FOUNDATION.md` - Network configuration guide
- `RESPECTING_USER_CHOICES.md` - Philosophy on user configuration

**Guidelines**:
- Target audience: End users and system administrators
- Focus on "how to use" the system
- Include examples and practical guidance
- Keep technical implementation details minimal
- Organize by feature or use case

---

### `/dev-reference/` (Developer Reference)
**Purpose**: Development notes, change logs, and implementation reports

**Contents**:
- Change summaries and implementation reports
- Development progress tracking
- Code audit reports
- CI/CD implementation notes
- Internal architecture decisions
- Refactoring and optimization reports
- Historical development records

**Current Files**:
- `OPTIMIZATION_SUMMARY.md` - Code optimization report
- `ADMIN_MENU_STRUCTURE.md` - Admin menu implementation details
- `BOOT_BEHAVIOR_FIXED.md` - Boot behavior implementation notes
- `CHANGES_IMPLEMENTED.md` - Change implementation log
- `CHANGES_SUMMARY.md` - Summary of changes
- `CI_CD_FIXES_COMPLETE.md` - CI/CD implementation report
- `COMPREHENSIVE_MENU_SYSTEM.md` - Menu system implementation
- `CONFIGURATION_UPDATED.md` - Configuration change notes
- `DELIVERED.txt` - Delivery checklist
- `DESKTOP_ICONS.md` - Desktop integration notes
- `FINAL_SOLUTION.md` - Solution implementation details
- `FIRST_BOOT_IMPROVEMENTS.md` - First boot experience notes
- `SETUP_COMPLETE.md` - Setup completion checklist
- `VM_BOOT_SELECTOR.md` - VM boot selector implementation
- Plus many more development reports...

**Guidelines**:
- Target audience: Developers and contributors
- Focus on "how it works" and "why we did it this way"
- Include implementation details and technical decisions
- Preserve historical context and rationale
- Used for reference during future development

---

## File Naming Conventions

### Root Directory
- `README.md` - Main readme (required)
- `*_QUICK_START.md` - Quick start guides
- `CREDITS.md`, `LICENSE`, `VERSION` - Standard project files

### User Documentation (`/docs/`)
- Use descriptive names: `FEATURE_NAME.md`
- Use underscores for multi-word names
- Focus on the "what" and "how to use"
- Examples: `SECURITY_MODEL.md`, `BACKUP_GUIDE.md`

### Developer Reference (`/dev-reference/`)
- Use UPPERCASE for importance/visibility
- Include status or type in name when relevant
- Focus on implementation and changes
- Examples: `PHASE_3_COMPLETE.md`, `AUDIT_REPORT.md`

---

## When to Add New Documentation

### Add to Root (`/`)
- ✅ New quick start guide for a major use case
- ✅ Critical information users need immediately
- ❌ Detailed feature documentation (use `/docs/` instead)
- ❌ Implementation notes (use `/dev-reference/` instead)

### Add to `/docs/`
- ✅ New feature user guide
- ✅ Configuration documentation
- ✅ Troubleshooting guides
- ✅ Best practices documentation
- ❌ Development notes (use `/dev-reference/` instead)

### Add to `/dev-reference/`
- ✅ Implementation reports
- ✅ Change summaries
- ✅ Audit reports
- ✅ Development progress tracking
- ✅ Architecture decision records
- ❌ User-facing guides (use `/docs/` instead)

---

## Documentation Maintenance

### Regular Reviews
- **Monthly**: Review root directory for outdated quick starts
- **Quarterly**: Review `/docs/` for accuracy and completeness
- **Annually**: Archive old `/dev-reference/` reports

### Archiving Guidelines
When a development report is > 1 year old and superseded:
1. Create `/dev-reference/archive/` directory if needed
2. Move historical reports to archive
3. Keep a `dev-reference/ARCHIVE_INDEX.md` with archived report summaries

### Update Process
1. New features → Document in `/docs/` first
2. Implementation complete → Add report to `/dev-reference/`
3. Quick start needed → Add concise guide to root
4. Major changes → Update README.md

---

## Documentation Standards

### All Documentation Should Include:
- **Date**: When the document was created/last updated
- **Purpose**: Clear statement of what the document covers
- **Audience**: Who should read this document
- **Status**: (For dev-reference) Current, Archived, Superseded, etc.

### Writing Style:
- **Root**: Brief, action-oriented, welcoming
- **Docs**: Clear, comprehensive, example-rich
- **Dev-reference**: Technical, detailed, historically accurate

### Markdown Standards:
- Use ATX-style headers (`#` not underlines)
- Include table of contents for documents > 200 lines
- Use code blocks with language specification
- Include links to related documentation

---

## Migration History

**2025-10-12**: Reorganized documentation structure
- Moved 14 development reports from root to `/dev-reference/`
- Moved 5 user guides from root to `/docs/`
- Established clear documentation structure
- Kept only essential files in root directory

**Previous Structure Issues**:
- Too many files in root directory (21 markdown files)
- Mixed development reports with user documentation
- Difficult to find relevant information
- No clear organization strategy

**Current Benefits**:
- Clean root directory (3 markdown files)
- Clear separation of concerns
- Easy to find relevant documentation
- Scalable structure for future growth

---

## Quick Reference

**Need to know how to get started?**
→ Check root directory: `README.md`, `ENTERPRISE_QUICK_START.md`

**Need to configure a feature?**
→ Check `/docs/` directory

**Need implementation details or development history?**
→ Check `/dev-reference/` directory

**Contributing documentation?**
→ Follow this structure and naming conventions

---

**Last Updated**: 2025-10-12  
**Maintained By**: Project maintainers  
**Questions**: See `README.md` for contact information
