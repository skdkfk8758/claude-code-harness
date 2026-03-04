---
name: cch-sp-execute-plan
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints between task batches.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskList
argument-hint: <plan file path>
---

# cch-sp-execute-plan

Execute a written implementation plan in batches of 3 tasks, with checkpoints for architect review between batches. Designed for parallel session execution.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers executing-plans skill. Follow it exactly:

1. Announce: "I'm using the executing-plans skill to implement this plan."
2. Read the plan file; review it critically — raise any concerns before starting.
3. Create TodoWrite entries for all tasks.

**Batch execution loop:**
- Execute 3 tasks per batch (default).
- For each task: mark in_progress → follow steps exactly → run verifications → mark completed.
- After each batch: report what was implemented + verification output, then say "Ready for feedback."
- Apply feedback, then execute the next batch.

**On completion:**
- After all tasks verified: invoke `cch-sp-finish-branch` to wrap up.

### Stop Conditions
Stop and ask for help when:
- Any blocker mid-batch (missing dependency, failing test, unclear instruction).
- Verification fails repeatedly.
- Plan has critical gaps preventing a start.

**Never start implementation on main/master without explicit user consent.**

## Integration

**Required before this:** `cch-sp-git-worktree` — set up an isolated workspace first.

**Required after this:** `cch-sp-finish-branch` — complete development.

**Alternative for same-session:** `cch-sp-subagent-dev`

**Source skill:** `superpowers:executing-plans` at `.claude/cch/sources/superpowers/skills/executing-plans/SKILL.md`
