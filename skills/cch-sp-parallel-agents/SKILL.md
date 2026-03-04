---
name: cch-sp-parallel-agents
description: Use when facing 2 or more independent tasks or failures that can be investigated or fixed concurrently without shared state or sequential dependencies.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskList
argument-hint: <list of independent problems or tasks>
---

# cch-sp-parallel-agents

Dispatch one agent per independent problem domain and let them work concurrently. Faster than sequential investigation when failures are unrelated.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers dispatching-parallel-agents skill. Follow it exactly:

**Step 1: Identify Independent Domains**
Group failures or tasks by what is broken or what needs to be done:
- Each domain must be independently solvable.
- Fixing one domain must not affect others.
- Agents must not need to edit the same files.

**Step 2: Create Focused Agent Tasks**
Each agent prompt must be:
- **Focused:** one test file or one subsystem only.
- **Self-contained:** all context to understand the problem included inline.
- **Specific about output:** what should the agent return?
- **Constrained:** explicit "Do NOT change X" instructions.

**Step 3: Dispatch in Parallel**
```typescript
Task("Fix agent-tool-abort.test.ts failures")
Task("Fix batch-completion-behavior.test.ts failures")
Task("Fix tool-approval-race-conditions.test.ts failures")
// All three run concurrently
```

**Step 4: Review and Integrate**
- Read each agent's summary.
- Verify fixes do not conflict (same files edited?).
- Run full test suite.
- Spot-check agent changes for systematic errors.

### When NOT to Use
- Failures are related (fixing one might fix others) — investigate together first.
- Need full system context to understand what is broken.
- Agents would edit the same files (shared state).
- Exploratory debugging phase (you do not yet know what is broken).

## Integration

**Pairs with:** `cch-sp-debug` — use systematic debugging per domain once agents identify root causes.

**Source skill:** `superpowers:dispatching-parallel-agents` at `.claude/cch/sources/superpowers/skills/dispatching-parallel-agents/SKILL.md`
