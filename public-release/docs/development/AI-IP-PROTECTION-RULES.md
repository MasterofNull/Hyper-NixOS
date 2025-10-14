# AI Agent IP Protection Rules

**THIS IS A PRIVATE IP DOCUMENT**

## Mandatory Rules for AI Agents

### 1. Content Classification

**PRIVATE IP (Never Include in Public Distributions):**
- All AI-*.md files (AI-Development, AI-LESSONS, AI-QUICK-REFERENCE)
- All audit scripts (audit-platform.sh, test-*.sh, validate-*.sh)
- All implementation reports (*IMPLEMENTATION*.md, *COMPLETE-*.md)
- Development methodologies and lessons learned
- Internal test results and reports

**PUBLIC (Safe to Distribute):**
- README.md
- User guides (SECURITY-QUICKSTART.md, ENTERPRISE_QUICK_START.md)
- Basic deployment guides
- Core platform scripts (security-platform-deploy.sh, etc.)
- Architecture overviews (without implementation details)

### 2. Required Directory Structure

```
workspace/
├── private-ip/          # ALL PRIVATE CONTENT HERE
│   ├── ai-development/  # AI docs go here
│   ├── audit-tools/     # Test scripts go here
│   └── implementation/  # Details go here
│
└── public/             # ONLY PUBLIC CONTENT HERE
    ├── README.md
    ├── docs/guides/    # User guides only
    └── scripts/        # Core scripts only
```

### 3. AI Agent Behavioral Rules

1. **ALWAYS** check if content is private IP before suggesting locations
2. **NEVER** include private-ip/ directory in public distributions
3. **ALWAYS** add IP protection headers to private documents
4. **NEVER** reference private implementation details in public docs
5. **ALWAYS** use .gitignore to exclude private content
6. **MAINTAIN** strict separation between private and public

### 4. When Creating Documents

For PRIVATE documents, add header:
```markdown
**PRIVATE IP DOCUMENT - NOT FOR PUBLIC DISTRIBUTION**
```

For PUBLIC documents, ensure:
- No references to private implementation details
- No inclusion of audit/test methodologies
- Generic, user-focused content only

### 5. When Organizing Files

```bash
# Private IP files go here:
private-ip/ai-development/AI-Development-Best-Practices.md
private-ip/audit-tools/audit-platform.sh
private-ip/implementation/COMPLETE-IMPLEMENTATION-SUMMARY.md

# Public files go here:
public/README.md
public/docs/guides/SECURITY-QUICKSTART.md
public/scripts/security-platform-deploy.sh
```

### 6. Distribution Rules

When preparing for distribution:
1. ONLY distribute contents of `public/` directory
2. NEVER include `private-ip/` or its contents
3. VERIFY no private content leaked into public
4. CHECK all internal references are removed

### 7. Cursor AI Access

- Cursor AI can ACCESS private-ip/ for development assistance
- Cursor AI should RESPECT the privacy when generating responses
- Cursor AI should MAINTAIN separation in suggestions

## Summary

**The owner's AI development documentation, audit tools, and implementation methodologies are PRIVATE INTELLECTUAL PROPERTY. They must be protected and never included in public distributions.**

AI agents must enforce this separation strictly and consistently.