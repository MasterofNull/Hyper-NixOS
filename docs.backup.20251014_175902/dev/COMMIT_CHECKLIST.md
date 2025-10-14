# Pre-Commit/Push/Merge Checklist for AI Assistants

## 🚨 CRITICAL: This checklist MUST be followed before ANY commit, push, or merge

### Documentation Update Checklist

Before committing any changes:

- [ ] **Update AI_ASSISTANT_CONTEXT.md** with:
  - [ ] New patterns discovered
  - [ ] Fixes implemented
  - [ ] Errors encountered and solutions
  - [ ] Any process improvements

- [ ] **Create issue-specific documentation** in `docs/dev/` if:
  - [ ] The fix is complex or non-obvious
  - [ ] New patterns were discovered
  - [ ] Multiple files were affected
  - [ ] The issue might recur

- [ ] **Update relevant existing documentation**:
  - [ ] Module-specific README files
  - [ ] Configuration guides
  - [ ] Troubleshooting guides
  - [ ] Quick reference guides

- [ ] **Explicitly communicate to the user**:
  - [ ] "I am now updating the AI documentation..."
  - [ ] List which documents are being updated
  - [ ] Confirm when documentation is complete
  - [ ] Ask for confirmation before proceeding with push/merge

### Communication Template

```
📝 **Documentation Update Status:**

I am now updating the AI documentation to ensure project continuity.

**Updates in progress:**
- ✅ AI_ASSISTANT_CONTEXT.md - Added [specific section]
- ✅ Created docs/dev/[SPECIFIC_FIX]_[DATE].md
- ✅ Updated [other relevant docs]

**Documentation update complete!**

This ensures future work on this project will have full context of:
- The problem encountered
- The solution implemented
- Any lessons learned

Would you like me to proceed with [push/merge/next steps]?
```

### Why This Matters

**"It is one of the most if not most important aspect of creating complex projects, systems, and the success to project completion."** - Project Lead

Documentation updates ensure:
1. **Continuity**: Future AI assistants have full context
2. **Learning**: Mistakes aren't repeated
3. **Efficiency**: Solutions are readily available
4. **Quality**: Project maintains high standards
5. **Success**: Complex systems remain maintainable

### Consequences of Skipping

- ❌ Lost knowledge and context
- ❌ Repeated errors and wasted time
- ❌ Project complexity becomes unmanageable
- ❌ Future development is hindered
- ❌ Project failure risk increases

## Remember: NO COMMIT WITHOUT DOCUMENTATION!