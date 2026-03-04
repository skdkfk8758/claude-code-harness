---
name: cch-sp-finish-branch
description: Use when implementation is complete and all tests pass. Guides branch completion by verifying tests, presenting merge/PR/keep/discard options, and cleaning up the worktree.
user-invocable: true
allowed-tools: Bash, Read
argument-hint: [optional: base branch name]
---

# cch-sp-finish-branch

Complete development work: verify tests, present 4 structured options, execute the chosen option, clean up worktree.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers finishing-a-development-branch skill. Follow it exactly:

**Announce:** "I'm using the finishing-a-development-branch skill to complete this work."

**Step 1: Verify Tests**
- Run the project's full test suite.
- If tests fail: show failures, stop. Do not proceed until tests pass.

**Step 2: Determine Base Branch**
```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

**Step 3: Present Exactly These 4 Options**
```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Step 4: Execute the Chosen Option**
- **Option 1 (Merge):** checkout base, pull, merge, verify tests, delete feature branch, clean worktree.
- **Option 2 (PR):** push branch, run `gh pr create`, keep worktree.
- **Option 3 (Keep):** report branch and worktree location. Do nothing else.
- **Option 4 (Discard):** require typed `discard` confirmation, then delete branch and clean worktree.

**Step 5: Cleanup Worktree**
- Only for Options 1 and 4: `git worktree remove <worktree-path>`
- Options 2 and 3: keep worktree.

### Key Rules
- Never proceed to options if tests are failing.
- Never delete work without typed "discard" confirmation.
- Never force-push unless explicitly requested.
- Present exactly 4 options — no more, no less.

## Integration

**Called by:** `cch-sp-execute-plan` and `cch-sp-subagent-dev` — final step after all tasks complete.

**Pairs with:** `cch-sp-git-worktree` — cleans up the worktree that skill created.

**Source skill:** `superpowers:finishing-a-development-branch` at `.claude/cch/sources/superpowers/skills/finishing-a-development-branch/SKILL.md`
