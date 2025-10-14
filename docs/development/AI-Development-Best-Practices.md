# AI Development Best Practices for Security Platform

This document outlines best practices for AI agents and developers working with the security platform.

## 🤖 For AI Agents

### Understanding the Platform Architecture

The security platform is designed with:
- **Modular Architecture**: Each feature is an independent module
- **Scalable Profiles**: From minimal (50MB) to enterprise (1GB)
- **Unified CLI**: All commands through `sec` interface
- **Python + Bash**: Core in Python, orchestration in Bash

### Key Implementation Files

1. **Main Deployment**: `security-platform-deploy.sh`
   - Contains all module implementations
   - 2,271 lines of comprehensive code
   - 25 Python classes for security features

2. **Framework**: `modular-security-framework.sh`
   - Profile management
   - Module installation logic
   - Resource allocation

3. **Console**: `console-enhancements.sh`
   - Terminal improvements
   - Productivity features
   - User experience enhancements

### Implementation Patterns

#### Module Structure
```python
class SecurityModule:
    def __init__(self):
        self.config = self.load_config()
        self.initialize()
    
    async def execute(self, *args):
        """Main execution method"""
        results = await self.process(*args)
        return self.format_output(results)
```

#### CLI Integration
```bash
case "$1" in
    scan)     exec "$PLATFORM_HOME/bin/scan" "${@:2}" ;;
    check)    exec "$PLATFORM_HOME/bin/check" "${@:2}" ;;
    monitor)  exec "$PLATFORM_HOME/bin/monitor" "${@:2}" ;;
esac
```

### Testing Approach

1. **Syntax Validation**
   ```bash
   bash -n script.sh
   python3 -m py_compile script.py
   ```

2. **Feature Testing**
   ```bash
   ./test-platform-features.sh
   ```

3. **Integration Testing**
   ```bash
   ./audit-platform.sh
   ```

### Common Pitfalls to Avoid

1. **Don't hardcode paths** - Use `$PLATFORM_HOME`
2. **Don't assume dependencies** - Check and install
3. **Don't mix profiles** - Respect resource limits
4. **Don't skip validation** - Always test changes
5. **Don't forget resource constants** - Define MAX_MEMORY/MAX_CPU for profiles
6. **Don't clutter root directory** - Organize docs in proper folders
7. **Don't ignore audit requirements** - Ensure all expected files/constants exist

## 👨‍💻 For Human Developers

### Development Workflow

1. **Setup Development Environment**
   ```bash
   git clone <repo>
   cd security-platform
   ./setup-dev-env.sh
   ```

2. **Choose Development Profile**
   ```bash
   # For feature development
   ./profile-selector.sh --advanced
   
   # For testing minimal deployments
   ./profile-selector.sh --minimal
   ```

3. **Module Development**
   ```bash
   # Create new module
   mkdir -p modules/my_module/{bin,lib,config}
   
   # Implement module
   vim modules/my_module/main.py
   
   # Register module
   vim modular-security-framework.sh
   ```

### Code Standards

#### Python Standards
- Use type hints
- Async/await for I/O operations
- Comprehensive docstrings
- Error handling with context

```python
from typing import Dict, List, Optional
import asyncio

async def scan_network(
    target: str, 
    options: Optional[Dict] = None
) -> List[Dict]:
    """
    Scan network target with specified options.
    
    Args:
        target: Network range or hostname
        options: Scanning options
        
    Returns:
        List of discovered hosts
    """
    try:
        results = await perform_scan(target, options or {})
        return process_results(results)
    except Exception as e:
        logger.error(f"Scan failed: {e}", exc_info=True)
        raise
```

#### Bash Standards
- Use strict mode
- Consistent formatting
- Meaningful variable names
- Proper error handling

```bash
#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${CONFIG_FILE:-/etc/security/config.yaml}"

main() {
    local target="${1:-}"
    
    if [[ -z "$target" ]]; then
        echo "Error: Target required" >&2
        usage
        exit 1
    fi
    
    perform_scan "$target"
}
```

### Adding New Features

1. **Plan the Feature**
   - Define requirements
   - Choose appropriate module
   - Consider resource impact

2. **Implement Core Logic**
   ```python
   # modules/feature_name/core.py
   class NewFeature:
       async def process(self, data):
           # Implementation
   ```

3. **Create CLI Wrapper**
   ```bash
   # modules/feature_name/bin/feature-cli
   #!/bin/bash
   python3 "$PLATFORM_HOME/modules/feature_name/core.py" "$@"
   ```

4. **Update Documentation**
   - Add to README.md
   - Update command reference
   - Add examples

5. **Test Thoroughly**
   ```bash
   # Unit tests
   python3 -m pytest modules/feature_name/tests/
   
   # Integration tests
   ./test-platform-features.sh
   ```

### Security Considerations

1. **Input Validation**
   - Sanitize all user input
   - Use parameterized queries
   - Validate file paths

2. **Privilege Management**
   - Run with minimal privileges
   - Drop privileges when possible
   - Use capabilities instead of root

3. **Secure Communication**
   - Use TLS for network communication
   - Verify certificates
   - Implement mutual authentication

4. **Secret Management**
   - Never hardcode secrets
   - Use the secrets vault module
   - Rotate credentials regularly

### Performance Guidelines

1. **Resource Awareness**
   ```python
   # Check available resources
   if PROFILE == 'minimal':
       max_workers = 2
   elif PROFILE == 'enterprise':
       max_workers = cpu_count()
   ```

2. **Async Operations**
   ```python
   # Good - parallel execution
   results = await asyncio.gather(
       scan_task1(),
       scan_task2(),
       scan_task3()
   )
   
   # Bad - sequential execution
   result1 = await scan_task1()
   result2 = await scan_task2()
   result3 = await scan_task3()
   ```

3. **Caching Strategy**
   ```python
   @lru_cache(maxsize=1000)
   def expensive_computation(param):
       # Cache results
       return compute(param)
   ```

### File Organization Standards

1. **Directory Structure**
   ```
   workspace/
   ├── docs/                    # All documentation
   │   ├── guides/             # User guides
   │   ├── reports/            # Test/audit reports
   │   ├── implementation/     # Technical details
   │   ├── development/        # Developer docs
   │   └── deployment/         # Deployment info
   ├── scripts/                # Implementation scripts
   │   ├── security/          # Security modules
   │   └── monitoring/        # Monitoring tools
   └── [root files]           # Only executables & configs
   ```

2. **Documentation Placement**
   - User guides → `docs/guides/`
   - Test reports → `docs/reports/`
   - Technical docs → `docs/implementation/`
   - Dev resources → `docs/development/`
   - Deploy guides → `docs/deployment/`

3. **Root Directory Rules**
   - Only executable scripts (.sh)
   - Configuration files (.yaml, .json)
   - Main README.md
   - License files
   - NO documentation dumps

### Audit Compliance

1. **Resource Constants Required**
   ```bash
   # Must define in modular-security-framework.sh
   readonly MAX_MEMORY_MINIMAL="512M"
   readonly MAX_CPU_MINIMAL="25"
   # ... for each profile
   ```

2. **File Location Awareness**
   ```bash
   # Audit script checks specific paths
   test_check "Docs exist" "[[ -f docs/SCALABLE-SECURITY-FRAMEWORK.md ]]"
   ```

3. **Permission Requirements**
   - All .sh files: 755 (rwxr-xr-x)
   - Config files: 644 (rw-r--r--)
   - Sensitive configs: 600 (rw-------)

### Debugging Tips

1. **Enable Debug Mode**
   ```bash
   export SECURITY_DEBUG=1
   sec scan --verbose
   ```

2. **Check Logs**
   ```bash
   # Module logs
   tail -f /var/log/security-platform/module.log
   
   # System logs
   journalctl -u security-platform -f
   ```

3. **Interactive Debugging**
   ```python
   import pdb; pdb.set_trace()
   # or
   import ipdb; ipdb.set_trace()
   ```

### Contributing Guidelines

1. **Code Review Checklist**
   - [ ] Passes all tests
   - [ ] Documentation updated
   - [ ] No hardcoded values
   - [ ] Resource limits respected
   - [ ] Security best practices followed

2. **Pull Request Template**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   
   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Documentation updated
   ```

## 📚 Resources

### Internal Documentation
- [Architecture Guide](docs/architecture.md)
- [Module Development](docs/module-development.md)
- [API Reference](docs/api-reference.md)
- [AI Lessons Learned](AI-LESSONS-LEARNED.md) - **MUST READ**

### External Resources
- [Python AsyncIO](https://docs.python.org/3/library/asyncio.html)
- [Bash Best Practices](https://google.github.io/styleguide/shellguide.html)
- [Security Patterns](https://owasp.org/www-project-security-design-patterns/)

### Tools
- **Development**: VSCode with Python & Bash extensions
- **Testing**: pytest, bats (Bash Automated Testing)
- **Linting**: pylint, shellcheck
- **Security**: bandit, safety

## 🤖 AI Agent Troubleshooting Guide

### Common Issues and Solutions

1. **Audit Failures**
   ```bash
   # Issue: 97% success rate
   # Cause: Missing resource constants
   # Solution: Add MAX_MEMORY_*/MAX_CPU_* to framework script
   
   # Issue: Documentation not found
   # Cause: Files in wrong location
   # Solution: Move to docs/ subdirectories
   ```

2. **File Organization Problems**
   ```bash
   # Issue: Cluttered root directory
   # Solution: Use this structure
   find . -name "*.md" -maxdepth 1 | while read f; do
       # Determine category and move
       case "$f" in
           *QUICKSTART*) mv "$f" docs/guides/ ;;
           *REPORT*) mv "$f" docs/reports/ ;;
           *IMPLEMENTATION*) mv "$f" docs/implementation/ ;;
           *) mv "$f" docs/ ;;
       esac
   done
   ```

3. **Script Validation**
   ```bash
   # Always validate after changes
   bash -n script.sh              # Syntax check
   ./audit-platform.sh            # Full audit
   ./test-platform-features.sh    # Feature tests
   ```

### Best Practices for AI Implementation

1. **Always Run Audits**
   - After any major change
   - Before marking complete
   - Fix all failures before proceeding

2. **Maintain Organization**
   - Keep docs in categorized folders
   - Update paths in scripts when moving files
   - Use consistent naming conventions

3. **Test Incrementally**
   - Don't wait until the end
   - Test each module as implemented
   - Verify audit passes at each stage

4. **Document Changes**
   - Update affected documentation
   - Note breaking changes
   - Provide migration paths

## 🎯 Key Takeaways

1. **Modularity First**: Always think in terms of independent modules
2. **Resource Conscious**: Respect profile limits
3. **Security by Design**: Build security in, don't bolt it on
4. **Test Everything**: Automated tests prevent regressions
5. **Document Always**: Code is read more than written
6. **Organize Properly**: Clean structure = maintainable code
7. **Audit Compliance**: 100% pass rate is the goal

---

**Remember**: The best code is maintainable, secure, and scalable. This platform embodies these principles.