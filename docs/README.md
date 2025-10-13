# Hyper-NixOS Documentation

## 📚 Complete Documentation Index

Welcome to Hyper-NixOS - A comprehensive, security-focused virtualization platform built on NixOS.

### 🚀 Quick Start
- [**Quick Start Guide**](QUICK_START.md) - Get up and running in minutes
- [**Installation Guide**](INSTALLATION_GUIDE.md) - Detailed installation instructions
- [**User Setup Guide**](USER_SETUP_GUIDE.md) - Configure users and permissions

### 🏗️ Architecture & Design
- [**System Architecture**](ARCHITECTURE.md) - Overall system design
- [**Module Structure**](dev/MODULE_STRUCTURE.md) - NixOS module organization
- [**Feature Categories**](COMPLETE_FEATURES_SUMMARY.md) - All features with risk assessment

### 🔧 Core Features

#### Virtualization
- [**VM Management**](features/VM_MANAGEMENT.md) - Creating and managing VMs
- [**Storage Management**](features/STORAGE.md) - Storage pools and volumes
- [**Network Configuration**](features/NETWORKING.md) - Bridges, VLANs, and isolation

#### Security
- [**Privilege Separation Model**](dev/PRIVILEGE_SEPARATION_MODEL.md) - User permissions and sudo requirements
- [**Two-Phase Security Model**](dev/TWO_PHASE_SECURITY_MODEL.md) - Setup vs. hardened modes
- [**Threat Defense System**](THREAT_DEFENSE_SYSTEM.md) - Comprehensive threat detection and response
- [**Security Best Practices**](SECURITY_BEST_PRACTICES.md) - Hardening guidelines

#### User Experience
- [**Adaptive Documentation**](features/ADAPTIVE_DOCS.md) - Documentation that adjusts to user level
- [**Interactive Tutorials**](features/TUTORIALS.md) - Hands-on learning
- [**Menu System**](features/MENU_SYSTEM.md) - Console-based management interface

#### Advanced Features
- [**Technology Stack**](dev/TECHNOLOGY_STACK_OPTIMIZATION.md) - Optimized components
- [**Portability Strategy**](dev/PORTABILITY_STRATEGY.md) - Multi-platform support
- [**Backup & Recovery**](features/BACKUP_RECOVERY.md) - Data protection
- [**Monitoring & Alerts**](features/MONITORING.md) - System monitoring

### 📖 Administration

#### Configuration
- [**Configuration Guide**](CONFIGURATION_GUIDE.md) - System configuration options
- [**Feature Manager**](features/FEATURE_MANAGER.md) - Enable/disable features
- [**Script Classification**](SCRIPT_PRIVILEGE_CLASSIFICATION.md) - Which scripts need sudo

#### Operations
- [**Operational Procedures**](OPERATIONAL_PROCEDURES.md) - Day-to-day operations
- [**Troubleshooting Guide**](TROUBLESHOOTING.md) - Common issues and solutions
- [**Performance Tuning**](PERFORMANCE_TUNING.md) - Optimization tips

#### Maintenance
- [**Update Procedures**](UPDATES.md) - Keeping the system current
- [**Backup Strategies**](BACKUP_STRATEGIES.md) - Protecting your data
- [**Audit Procedures**](AUDIT_PROCEDURES.md) - Security auditing

### 🛠️ Development

#### For Contributors
- [**Development Guide**](dev/DEVELOPMENT_GUIDE.md) - Contributing to Hyper-NixOS
- [**Code Standards**](dev/CODE_STANDARDS.md) - Coding conventions
- [**Testing Guide**](dev/TESTING_GUIDE.md) - Test procedures

#### API & Integration
- [**API Reference**](dev/API_REFERENCE.md) - REST/GraphQL APIs
- [**Integration Guide**](dev/INTEGRATION_GUIDE.md) - Third-party integrations
- [**Plugin Development**](dev/PLUGIN_DEVELOPMENT.md) - Extending Hyper-NixOS

### 🆘 Help & Support

#### Troubleshooting
- [**Common Issues & Solutions**](COMMON_ISSUES_AND_SOLUTIONS.md) - Known issues and fixes
- [**Error Messages**](ERROR_MESSAGES.md) - Understanding error messages
- [**FAQ**](FAQ.md) - Frequently asked questions

#### Community
- [**Community Guidelines**](COMMUNITY.md) - Code of conduct
- [**Support Channels**](SUPPORT.md) - Getting help
- [**Contributing**](CONTRIBUTING.md) - How to contribute

### 📋 Reference

#### Technical Specifications
- [**System Requirements**](REQUIREMENTS.md) - Hardware and software requirements
- [**Compatibility Matrix**](COMPATIBILITY_MATRIX.md) - Feature compatibility
- [**Performance Benchmarks**](BENCHMARKS.md) - Performance data

#### Compliance & Standards
- [**Security Compliance**](COMPLIANCE.md) - Security standards
- [**Audit Logs**](AUDIT_LOGS.md) - Logging standards
- [**Data Protection**](DATA_PROTECTION.md) - Privacy and data handling

### 🎯 Use Cases

- [**Home Lab Setup**](use-cases/HOME_LAB.md) - Personal virtualization
- [**Development Environment**](use-cases/DEVELOPMENT.md) - Developer workstations
- [**Production Deployment**](use-cases/PRODUCTION.md) - Enterprise deployment
- [**Security Testing**](use-cases/SECURITY_TESTING.md) - Penetration testing lab

### 📝 Appendices

- [**Glossary**](GLOSSARY.md) - Technical terms
- [**Command Reference**](COMMAND_REFERENCE.md) - All commands
- [**Configuration Reference**](CONFIG_REFERENCE.md) - All options
- [**Release Notes**](RELEASE_NOTES.md) - Version history

## 🚦 Getting Started

1. **New Users**: Start with the [Quick Start Guide](QUICK_START.md)
2. **Administrators**: Review the [Installation Guide](INSTALLATION_GUIDE.md) and [Configuration Guide](CONFIGURATION_GUIDE.md)
3. **Developers**: Check out the [Development Guide](dev/DEVELOPMENT_GUIDE.md)

## 📊 System Status

- **Current Version**: 1.0.0
- **Release Date**: 2025-01-01
- **Stability**: Production-ready
- **License**: MIT

## 🔍 Search Documentation

Use the search function in your viewer or grep through the docs directory:
```bash
grep -r "search term" /etc/hypervisor/docs/
```

---

*This documentation is part of Hyper-NixOS. For the latest updates, visit the project repository.*