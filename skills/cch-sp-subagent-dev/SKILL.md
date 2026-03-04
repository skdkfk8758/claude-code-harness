---
name: cch-sp-subagent-dev
description: Use when executing an implementation plan with independent tasks in the current session. Dispatches a fresh subagent per task with two-stage review (spec compliance then code quality) after each.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskList
argument-hint: <plan file path>
---

# cch-sp-subagent-dev

Execute a plan in the current session by dispatching a fresh subagent per task, with spec compliance review then code quality review after each task. High quality with fast iteration.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers subagent-driven-development skill. Follow it exactly:

1. Read the plan file once. Extract ALL tasks with full text. Note surrounding context.
2. Create TodoWrite with all tasks.

**Per-task loop:**
1. Dispatch implementer subagent with full task text + context (do NOT make subagent read the plan file).
2. Answer any questions the subagent raises before letting them proceed.
3. After implementation: dispatch spec compliance reviewer subagent.
   - If issues found: implementer fixes → spec reviewer re-reviews (repeat until approved).
4. After spec approval: dispatch code quality reviewer subagent.
   - If issues found: implementer fixes → quality reviewer re-reviews (repeat until approved).
5. Mark task complete in TodoWrite.
6. Move to next task.

**After all tasks:**
- Dispatch final code reviewer for the entire implementation.
- Invoke `cch-sp-finish-branch` to complete development.

### Review Templates
Prompt templates are at:
- `.claude/cch/sources/superpowers/skills/subagent-driven-development/implementer-prompt.md`
- `.claude/cch/sources/superpowers/skills/subagent-driven-development/spec-reviewer-prompt.md`
- `.claude/cch/sources/superpowers/skills/subagent-driven-development/code-quality-reviewer-prompt.md`

### Key Rules
- Never dispatch multiple implementation subagents in parallel (file conflicts).
- Never start code quality review before spec compliance is approved.
- Never skip review loops — reviewer found issues = implementer fixes = re-review.
- **Never start on main/master without explicit user consent.**

## Integration

**Required before this:** `cch-sp-git-worktree` — isolated workspace required.

**Required after this:** `cch-sp-finish-branch` — complete development.

**Alternative for parallel sessions:** `cch-sp-execute-plan`

**Source skill:** `superpowers:subagent-driven-development` at `.claude/cch/sources/superpowers/skills/subagent-driven-development/SKILL.md`
