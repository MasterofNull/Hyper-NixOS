# 🚨 CRITICAL REQUIREMENTS - MANDATORY FOR ALL OPERATIONS 🚨

## ⚠️ HIGH PRIORITY - READ BEFORE ANY DEVELOPMENT ⚠️

This document outlines **MANDATORY** requirements that **MUST** be followed for ALL Hyper-NixOS operations, development, and maintenance. Failure to follow these requirements may result in system instability, security vulnerabilities, or project failure.

---

## 🔴 REQUIREMENT #1: AI CONTEXT MAINTENANCE

### **CRITICAL**: All AI assistants and developers MUST maintain and update context

**MANDATORY ACTIONS:**
1. **BEFORE** any development work:
   - Read `/docs/AI_ASSISTANT_CONTEXT.md`
   - Review `/docs/dev/PROJECT_DEVELOPMENT_HISTORY.md`
   - Check recent changes in `/docs/CHANGELOG.md`

2. **DURING** development:
   - Document ALL decisions in appropriate files
   - Update context documents in real-time
   - Maintain consistency with existing patterns

3. **AFTER** making changes:
   - Update `AI_ASSISTANT_CONTEXT.md` with new patterns
   - Add entries to `PROJECT_DEVELOPMENT_HISTORY.md`
   - Update all affected documentation

### **Enforcement:**
```bash
# Pre-commit hook (REQUIRED)
#!/bin/bash
if ! grep -q "$(date +%Y-%m)" docs/AI_ASSISTANT_CONTEXT.md; then
  echo "ERROR: AI_ASSISTANT_CONTEXT.md not updated this month"
  exit 1
fi
```

---

## 🔴 REQUIREMENT #2: DOCUMENTATION SYNCHRONIZATION

### **CRITICAL**: Documentation MUST be updated with EVERY change

**MANDATORY CHECKLIST:**
- [ ] Code change → Update technical docs
- [ ] Feature addition → Update user guides
- [ ] Bug fix → Update troubleshooting
- [ ] Security change → Update security docs
- [ ] API change → Update API reference
- [ ] Configuration change → Update examples

**ZERO TOLERANCE** for undocumented changes.

---

## 🔴 REQUIREMENT #3: SECURITY-FIRST DEVELOPMENT

### **CRITICAL**: Every change MUST be evaluated for security impact

**MANDATORY SECURITY REVIEW:**
```nix
# REQUIRED in every new feature
security = {
  riskLevel = "minimal|low|moderate|high|critical";
  impacts = [ "list all security impacts" ];
  mitigations = [ "list all mitigations" ];
  reviewer = "security-team-member";
  reviewDate = "YYYY-MM-DD";
};
```

**NO EXCEPTIONS** - Even "minor" changes require security assessment.

---

## 🔴 REQUIREMENT #4: INFINITE RECURSION PREVENTION

### **CRITICAL**: Module pattern MUST be followed

**FORBIDDEN PATTERN** (will break system):
```nix
# ❌ NEVER DO THIS
let
  someValue = config.hypervisor.someOption;
in {
  config = { /* ... */ };
}
```

**MANDATORY PATTERN**:
```nix
# ✅ ALWAYS DO THIS
{
  config = lib.mkIf config.hypervisor.enable {
    # Access config here only
  };
}
```

**Automatic validation REQUIRED** before any commit.

---

## 🔴 REQUIREMENT #5: PRIVILEGE MODEL INTEGRITY

### **CRITICAL**: Maintain privilege separation

**IMMUTABLE RULES:**
1. VM operations MUST NOT require sudo
2. System operations MUST require sudo
3. NO EXCEPTIONS without security team approval
4. ALL scripts MUST declare sudo requirements

**Template enforcement:**
```bash
# MANDATORY in every script
readonly REQUIRES_SUDO=true|false  # MUST be set
readonly OPERATION_TYPE="vm_management|system_config"  # MUST be set
```

---

## 🔴 REQUIREMENT #6: BACKWARD COMPATIBILITY

### **CRITICAL**: Breaking changes FORBIDDEN without migration path

**MANDATORY for ANY interface change:**
1. Deprecation notice (minimum 2 releases)
2. Migration script
3. Compatibility layer
4. User notification system
5. Rollback procedure

---

## 🔴 REQUIREMENT #7: TEST COVERAGE

### **CRITICAL**: No deployment without tests

**MINIMUM REQUIREMENTS:**
- Unit tests: 80% coverage
- Integration tests: All critical paths
- Security tests: All auth/privilege paths
- Performance tests: Baseline metrics
- Documentation tests: All examples must work

---

## 📋 ENFORCEMENT MECHANISMS

### 1. **Automated Checks** (CI/CD Pipeline)
```yaml
pre-merge-checks:
  - documentation-sync-check
  - ai-context-freshness
  - security-review-present
  - module-pattern-validation
  - privilege-model-check
  - test-coverage-threshold
```

### 2. **Manual Review Gates**
- Security team sign-off for risk changes
- Documentation team approval
- Two maintainer approval minimum

### 3. **Monitoring & Alerts**
```bash
# Continuous monitoring for violations
hypervisor-compliance-monitor --strict --alert-on-violation
```

---

## 🚫 CONSEQUENCES OF NON-COMPLIANCE

1. **Immediate:** PR/MR rejection
2. **Automated:** Rollback of changes
3. **Escalation:** Security incident filed
4. **Severe:** Contributor access review

---

## ✅ COMPLIANCE CERTIFICATION

Every contributor MUST acknowledge these requirements:

```bash
# Run before first contribution
hv dev certify --requirements-read --username <your-name>
```

---

## 📞 ESCALATION CONTACTS

- **Security Issues**: security@hyper-nixos.org
- **Documentation**: docs@hyper-nixos.org
- **Architecture**: architects@hyper-nixos.org
- **Emergency**: emergency@hyper-nixos.org

---

## 🔄 REVIEW SCHEDULE

This document is reviewed and enforced:
- **Weekly**: Automated compliance checks
- **Monthly**: Manual audit
- **Quarterly**: Full review and update
- **Annually**: Major revision consideration

---

**REMEMBER**: These requirements exist to ensure Hyper-NixOS remains secure, stable, and maintainable. They are not guidelines - they are MANDATORY.

**Last Updated**: 2025-01-01
**Next Review**: 2025-02-01
**Version**: 1.0.0-CRITICAL