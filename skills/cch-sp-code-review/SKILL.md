---
name: cch-sp-code-review
description: Use when completing tasks or major features, before merging. Dispatches a code-reviewer subagent to evaluate implementation against spec and code quality standards.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep
argument-hint: <what was implemented> [base-sha] [head-sha]
---

# cch-sp-code-review

Request a code review by dispatching a superpowers code-reviewer subagent. Catches issues before they compound.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers requesting-code-review skill:

**Step 1: Get SHAs**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**Step 2: Dispatch code-reviewer subagent** using the template at:
`.claude/cch/sources/superpowers/skills/requesting-code-review/code-reviewer.md`

Fill in these placeholders:
- `{WHAT_WAS_IMPLEMENTED}` — what you just built
- `{PLAN_OR_REQUIREMENTS}` — what it should do
- `{BASE_SHA}` — starting commit
- `{HEAD_SHA}` — ending commit
- `{DESCRIPTION}` — brief summary

**Step 3: Act on Feedback**
- **Critical:** fix immediately before proceeding.
- **Important:** fix before moving to the next task.
- **Minor:** note for later.
- **If reviewer is wrong:** push back with technical reasoning and show code/tests.

### When to Request

**Mandatory:**
- After each task in `cch-sp-subagent-dev`.
- After completing a major feature.
- Before merge to main.

**Optional but valuable:**
- When stuck (fresh perspective).
- Before refactoring.
- After fixing a complex bug.

## Integration

**Used within:** `cch-sp-subagent-dev` — review after each task.

**Pairs with:** `cch-sp-receive-review` — for handling incoming review feedback.

**Source skill:** `superpowers:requesting-code-review` at `.claude/cch/sources/superpowers/skills/requesting-code-review/SKILL.md`
