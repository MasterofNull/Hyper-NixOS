# Global Rules for Hyper-NixOS Development

## Code Quality Standards

### NixOS Module Standards
1. All modules MUST use `lib.mkOption` with proper type annotations
2. All modules MUST include `meta.description` and `meta.doc`
3. Default values MUST be sensible for production use
4. Options MUST NOT introduce circular dependencies

### Shell Script Standards
1. All scripts MUST use `set -euo pipefail`
2. All scripts MUST source `scripts/lib/common.sh` when available
3. Scripts MUST handle errors gracefully with cleanup
4. Scripts MUST use `mktemp` for temporary files

### Go Code Standards
1. All Go code MUST pass `go vet` and `golint`
2. GraphQL resolvers MUST include proper error handling
3. API endpoints MUST validate input
4. Concurrent operations MUST use proper synchronization

## Security Requirements

1. **No hardcoded secrets** - Use NixOS secrets management
2. **Principle of least privilege** - Request minimal permissions
3. **Input validation** - All user input must be sanitized
4. **Audit logging** - Security-relevant operations must be logged
5. **Secure defaults** - Features must be secure by default

## Testing Requirements

1. All new features MUST have corresponding tests
2. All bug fixes MUST include regression tests
3. Tests MUST NOT require network access (use mocks)
4. Tests MUST clean up any created resources

## Documentation Requirements

1. All public modules MUST have documentation
2. All CLI tools MUST have `--help` output
3. Breaking changes MUST be documented in CHANGELOG
4. Complex logic MUST have inline comments

## Commit Standards

### Message Format
```
<type>(<scope>): <description>

[body]

[footer]
```

### Types
- `fix` - Bug fixes
- `feat` - New features
- `docs` - Documentation only
- `chore` - Maintenance, dependencies
- `test` - Test additions/changes
- `refactor` - Code restructuring

### Co-authorship
All AI-assisted commits MUST include:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## AI Agent Constraints

### Do's
- Always read files before modifying
- Validate changes with `nix flake check`
- Test changes with `bash tests/run_all_tests.sh`
- Create small, focused commits
- Use the AI harness for context retrieval

### Don'ts
- Never force-push to main
- Never skip pre-commit hooks
- Never commit secrets or credentials
- Never make breaking changes without discussion
- Never modify production configurations without approval

## Branch Strategy

- `main` - Production-ready code
- `feature/*` - Feature development
- `fix/*` - Bug fixes
- `release/*` - Release preparation

## Version Policy

- Semantic versioning (MAJOR.MINOR.PATCH)
- Breaking changes increment MAJOR
- New features increment MINOR
- Bug fixes increment PATCH

## AI Harness Integration

### Available Tools
- `hybrid_search` - Query knowledge base
- `store_memory` - Persist decisions
- `recall_memory` - Retrieve context
- `workflow_plan` - Generate phase plans

### Endpoints
- Hybrid Coordinator: http://127.0.0.1:8003
- AIDB: http://127.0.0.1:8002

### Best Practices
1. Query AI harness before major changes
2. Store important decisions in memory
3. Use workflow plans for complex features
4. Validate against known patterns
