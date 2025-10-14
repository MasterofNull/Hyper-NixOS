# Contact Information Configuration

This document defines the official contact information for Hyper-NixOS. 

## Current Configuration

The following contact information is used throughout the documentation:

### Primary Contact
```yaml
# All inquiries through Discord
primary_contact: "Discord: @quin-tessential"
discord_url: "https://discord.com/users/quin-tessential"
response_time: "24-48 hours"
```

### Web Resources
```yaml
# Main website (GitHub repository)
website: "https://github.com/Hyper-NixOS/Hyper-NixOS"

# Documentation
docs_site: "https://github.com/Hyper-NixOS/Hyper-NixOS/tree/main/docs"

# Issue tracking
issues_url: "https://github.com/Hyper-NixOS/Hyper-NixOS/issues"
```

### Repository
```yaml
github_org: "Hyper-NixOS"
github_repo: "Hyper-NixOS"
full_url: "https://github.com/Hyper-NixOS/Hyper-NixOS"
```

### Communication Channels
```yaml
# Primary support
support: "Discord: @quin-tessential"

# Bug reports
bugs: "GitHub Issues"

# Security issues
security: "Discord (mark as security-related) or GitHub Security Advisory"

# Feature requests
features: "GitHub Issues or Discord"
```

## Placeholder Replacement Script

Run this script to replace all placeholder emails with your actual contact info:

```bash
#!/bin/bash
# update-contacts.sh

# Define your actual contacts
SUPPORT_EMAIL="support@your-actual-domain.com"
SECURITY_EMAIL="security@your-actual-domain.com"
ENTERPRISE_EMAIL="enterprise@your-actual-domain.com"
FORUM_URL="https://your-actual-forum.com"
GITHUB_ORG="your-actual-org"

# Replace in all documentation
find docs/ -name "*.md" -type f -exec sed -i \
  -e "s/support@hyper-nixos.org/${SUPPORT_EMAIL}/g" \
  -e "s/security@hyper-nixos.org/${SECURITY_EMAIL}/g" \
  -e "s/enterprise@hyper-nixos.org/${ENTERPRISE_EMAIL}/g" \
  -e "s|https://hyper-nixos.org/forum|${FORUM_URL}|g" \
  -e "s|hyper-nixos/hyper-nixos|${GITHUB_ORG}/hyper-nixos|g" \
  {} +

# Update README
sed -i \
  -e "s/security@hyper-nixos.org/${SECURITY_EMAIL}/g" \
  -e "s|https://hyper-nixos.org/forum|${FORUM_URL}|g" \
  README.md
```

## Privacy Considerations

1. Use role-based emails (support@, security@) not personal emails
2. Consider using a ticketing system instead of direct email
3. For security issues, provide a PGP public key
4. Use email aliases that can be updated without changing documentation