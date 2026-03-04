---
name: cch-sp-git-worktree
description: Use when starting feature work that needs isolation, or before executing implementation plans. Creates an isolated git worktree with safety verification and clean baseline testing.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write
argument-hint: <branch-name or feature description>
---

# cch-sp-git-worktree

Create an isolated git worktree for feature work. Systematic directory selection, gitignore safety verification, and clean baseline test confirmation.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers using-git-worktrees skill. Follow it exactly:

**Announce:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

**Step 1: Directory Selection (priority order)**
1. Check if `.worktrees/` or `worktrees/` already exists — use it if found (`.worktrees/` wins if both exist).
2. Check `CLAUDE.md` for a worktree directory preference — use it without asking.
3. If neither: ask the user to choose between `.worktrees/` (project-local) or `~/.config/superpowers/worktrees/<project>/` (global).

**Step 2: Safety Verification (project-local only)**
- Run: `git check-ignore -q .worktrees` (or `worktrees`)
- If NOT ignored: add to `.gitignore`, commit the change, then proceed.

**Step 3: Create the Worktree**
```bash
git worktree add <path>/<branch-name> -b <branch-name>
```

**Step 4: Run Project Setup**
- Detect and run the appropriate setup (`npm install`, `cargo build`, `pip install`, `go mod download`).

**Step 5: Verify Clean Baseline**
- Run the project's test suite.
- If tests fail: report failures and ask whether to proceed.
- If tests pass: report ready.

**Report:** "Worktree ready at `<full-path>`. Tests passing. Ready to implement `<feature>`."

### Key Rules
- Never create a worktree without verifying it is gitignored (for project-local).
- Never skip baseline test verification.
- Never assume directory location when ambiguous.

## Integration

**Required before:** `cch-sp-subagent-dev` and `cch-sp-execute-plan` — always set up isolated workspace first.

**Pairs with:** `cch-sp-finish-branch` — cleans up the worktree after work is done.

**Source skill:** `superpowers:using-git-worktrees` at `.claude/cch/sources/superpowers/skills/using-git-worktrees/SKILL.md`
