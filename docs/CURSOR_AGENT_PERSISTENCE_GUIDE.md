# Cursor Agent Persistence Guide

**How to maintain long-running agent sessions and avoid unnecessary VM spinups**

---

## The Problem

Every time you start a new Cursor agent session:
1. ⏱️ A new VM/container spins up (20-60 seconds)
2. 🔍 The agent needs to search/index your codebase again
3. 💾 Previous context and understanding is lost
4. 💰 This wastes time and resources

---

## Solution: Maintain Persistent Agent Sessions

### 1. **Keep the Conversation Thread Alive**

**Best Practice:** Continue the same agent conversation rather than starting new ones.

✅ **DO THIS:**
```
Session 1:
You: "Fix the network configuration bug"
Agent: [makes changes]
You: "Now update the documentation for that change"
Agent: [updates docs - already has context!]
You: "Add a test for this"
Agent: [adds test - still has full context]
```

❌ **DON'T DO THIS:**
```
Session 1: "Fix the network configuration bug" [closes agent]
Session 2: "Update docs for network config" [NEW VM, re-indexes]
Session 3: "Add test for network config" [NEW VM, re-indexes again]
```

### 2. **Use Background Agents for Long-Running Tasks**

Background agents can run while you continue working:

```bash
# The agent runs in background and maintains state
# until the task is complete
```

**Advantages:**
- Maintains context throughout the entire task
- No need to repeatedly explain what you're working on
- Agent can make multiple related changes in one session

### 3. **Pre-load Context at Session Start**

When starting a new session, immediately provide relevant context:

```
"I'm working on the VM networking feature. The relevant files are:
- configuration/network-isolation.nix
- hypervisor_manager/network_manager.py
- scripts/network_bridge_helper.sh

Let's continue improving the network performance..."
```

**Why this helps:**
- Agent reads these files immediately
- Reduces need for exploratory searches
- Agent has full context from the start

### 4. **Organize Work into Logical Sessions**

**Strategy:** Group related tasks into single agent sessions.

✅ **Good session grouping:**
- "Implement feature X" (includes code + tests + docs)
- "Fix bug Y and all related issues"
- "Refactor module Z completely"

❌ **Poor session usage:**
- "Fix line 23" [close session]
- "Update comment" [new session]
- "Format code" [new session]

### 5. **Use Composer for Multi-File Changes**

Cursor Composer maintains context across multiple files:

- Opens relevant files automatically
- Maintains state across edits
- No need for repeated searches
- Single session for complex multi-file refactoring

---

## Understanding Cursor Agent Lifecycle

### When Does a New VM Spin Up?

1. **Starting a new agent conversation** ✗
2. **Starting a new Composer session** ✗
3. **Clicking "New Agent" button** ✗
4. **Opening a different project** ✗

### When Does the Agent Maintain State?

1. **Continuing the same conversation** ✓
2. **Agent is still processing** ✓
3. **Within the same Composer session** ✓
4. **Background agent running** ✓

---

## Optimization Strategies

### Strategy 1: Batch Related Tasks

**Instead of:**
- Session 1: "Add function X"
- Session 2: "Add test for X"  
- Session 3: "Document X"
- Session 4: "Handle edge case in X"

**Do this:**
```
Single Session: "Implement function X with:
1. Core implementation
2. Unit tests
3. Documentation
4. Edge case handling
5. Error handling

Make all these changes in one session."
```

### Strategy 2: Reference Previous Work

When you must start a new session, reference previous work:

```
"In the previous session we implemented network bridge isolation.
Now let's add monitoring for those bridges. The changes were in
configuration/network-isolation.nix. Continue from there."
```

### Strategy 3: Use File References (@)

Use `@filename` to bring files into context immediately:

```
"Looking at @configuration/network-isolation.nix and 
@scripts/network_bridge_helper.sh, let's optimize the 
bridge creation logic."
```

**This avoids:**
- Agent searching for files
- Repeated "please read file X" requests
- Context-building overhead

### Strategy 4: Create Session Plans

At the start of complex work, create a plan:

```
"We need to refactor the VM backup system. Here's the plan:
1. Update backup.nix to use new format
2. Modify scripts/backup_vms.sh for parallel processing
3. Add monitoring to monitoring/alert-rules.yml
4. Update docs/BACKUP_GUIDE.md

Let's work through these one by one in this session.
Start with step 1."
```

**Benefit:** Agent maintains context for all 4 steps without searching repeatedly.

---

## Working with Large Codebases

### Problem: "Agent is searching too much"

**Solutions:**

1. **Narrow the scope explicitly:**
   ```
   "Only look in the configuration/ directory for this task"
   ```

2. **Provide exact file paths:**
   ```
   "The bug is in configuration/network-isolation.nix line 45-67"
   ```

3. **Use grep patterns to limit search:**
   ```
   "Search for 'bridge.*config' only in .nix files"
   ```

### Problem: "Session is taking too long"

**Solutions:**

1. **Break into smaller focused sessions:**
   - Session 1: Planning and design
   - Session 2: Implementation
   - Session 3: Testing and docs

2. **Use checkpoints:**
   ```
   You: "Good progress. Let's commit this, then continue
        with the next part in this same session."
   ```

3. **Provide file list upfront:**
   ```
   "For this task, you'll need these 5 files: [list].
    Read them all now, then I'll describe the changes."
   ```

---

## Best Practices Summary

### ✅ DO:
- Keep conversations going for related tasks
- Pre-load context with file references (@filename)
- Batch related changes in single sessions
- Use Composer for multi-file work
- Plan complex tasks before starting
- Reference previous work when starting new sessions

### ❌ DON'T:
- Close and reopen agent for every small change
- Start new sessions for follow-up questions
- Make agent search repeatedly for same files
- Split logically-connected work across sessions
- Forget to provide context in new sessions

---

## Example: Efficient Multi-Task Session

```
Session Start:
You: "I need to improve VM network performance. This involves:
     - configuration/network-isolation.nix (main config)
     - scripts/network_bridge_helper.sh (bridge setup)
     - docs/NETWORK_CONFIGURATION.md (documentation)
     
     Let's start by reading all three files, then I'll describe
     the optimizations needed."

Agent: [reads all three files in parallel]
       "I've reviewed all three files. What optimizations 
        do you want to implement?"

You: "1. Enable jumbo frames by default
     2. Add NIC offloading configuration  
     3. Update docs with performance tuning section"

Agent: [implements all changes with full context]
       "I've made all three changes. The network config now
        supports jumbo frames, NIC offloading is enabled, and
        docs are updated with a new performance section."

You: "Great! Now add monitoring for these network features
     to monitoring/alert-rules.yml"

Agent: [adds monitoring - still has full context from earlier]
       "Added network performance alerts to alert-rules.yml"

You: "Perfect. One more thing - add a test script to verify
     these features work."

Agent: [creates test script - maintains all context]
       "Created tests/network_performance_test.sh"

[Single session, 6 files modified, no repeated searching]
```

**Result:** 
- ✅ One VM spinup
- ✅ One code indexing pass
- ✅ Full context maintained throughout
- ✅ ~5 minutes vs ~20 minutes with multiple sessions

---

## Troubleshooting

### "Agent lost context mid-session"

**Causes:**
- Session timeout (rare)
- Network interruption
- Agent crash

**Solution:**
- Start new session with detailed context recap
- Provide git diff to show what was changed
- List files that need further work

### "Agent is still searching after I provided files"

**Why:**
- Agent may need to understand dependencies
- Looking for related patterns
- Verifying no conflicts in other files

**Solution:**
- Be explicit: "Only modify the files I listed, don't search others"
- Use: "Assume no other files are affected"

### "Session is taking too long"

**Solutions:**
1. Cancel and restart with narrower scope
2. Provide more specific instructions
3. List exact files and line numbers to change
4. Break into smaller sub-tasks

---

## Advanced: Session Persistence Patterns

### Pattern 1: Feature Development

```
Session 1 (persistent):
├── Design & planning
├── Core implementation
├── Unit tests
├── Integration tests
├── Documentation
└── Final review
```

### Pattern 2: Bug Investigation

```
Session 1 (persistent):
├── Reproduce issue
├── Identify root cause
├── Implement fix
├── Add regression test
├── Verify fix
└── Update relevant docs
```

### Pattern 3: Refactoring

```
Session 1 (persistent):
├── Analyze current code
├── Design new structure
├── Implement changes (phase 1)
├── Run tests, fix issues
├── Implement changes (phase 2)
├── Final testing
└── Update documentation
```

---

## Measuring Efficiency

### Time Saved with Persistent Sessions

**Typical breakdown:**

```
Traditional approach (multiple sessions):
- VM spinup × 5 sessions: 5 min
- Code indexing × 5: 3 min
- Context rebuilding × 5: 4 min
- Actual work: 10 min
TOTAL: ~22 minutes

Persistent session approach:
- VM spinup × 1 session: 1 min
- Code indexing × 1: 0.5 min
- Actual work: 10 min
TOTAL: ~11.5 minutes

SAVINGS: ~48% faster!
```

---

## Conclusion

**Key Takeaway:** Treat Cursor agent sessions like pair programming sessions - keep the conversation going, maintain context, and batch related work together.

**Golden Rule:** If two tasks are related, do them in the same agent session.

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────┐
│ Cursor Agent Persistence Cheat Sheet               │
├─────────────────────────────────────────────────────┤
│                                                     │
│ ✓ Continue same conversation for related tasks     │
│ ✓ Pre-load files with @filename                    │
│ ✓ Batch changes together                           │
│ ✓ Plan complex tasks upfront                       │
│ ✓ Keep sessions focused but comprehensive          │
│                                                     │
│ ✗ Don't close/reopen for small changes             │
│ ✗ Don't split related work across sessions         │
│ ✗ Don't start new session for follow-ups           │
│                                                     │
│ Time saved: ~48% with good session management      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

**Last Updated:** 2025-10-12  
**For:** Hyper-NixOS Project  
**Related Docs:** [TOOL_GUIDE.md](./TOOL_GUIDE.md), [workflows.txt](./workflows.txt)
