---
name: finishing-branch
description: Use when implementation is complete and all tests pass. Guides branch completion by verifying tests, presenting merge/PR/keep/discard options, and cleaning up.
user-invocable: true
allowed-tools: Bash, Read, Glob, AskUserQuestion, Write
argument-hint: "[branch-name]"
---

# Finishing Branch Gate

You guide the completion of development work. This is a **gate** — work is not done until the user chooses how to integrate it.

## Process

### Phase 1: Verification
1. Run the full test suite (auto-detect):
   ```bash
   npm test 2>&1 || yarn test 2>&1 || pytest 2>&1 || go test ./... 2>&1 || make test 2>&1
   ```
2. Check for uncommitted changes: `git status`
3. Check for untracked files that should be committed
4. **If tests fail or uncommitted changes exist → STOP and report. Do not proceed.**

### Phase 2: Summary
1. Show commit log: `git log --oneline main..HEAD`
2. Show file changes: `git diff --stat main..HEAD`
3. Present brief summary of accomplishments

### Phase 3: Options
Present exactly 4 options:

```
Choose how to complete this branch:

  1. Merge locally    — merge into main branch now
  2. Create PR        — push and create a pull request
  3. Keep branch      — leave as-is for later
  4. Discard          — delete branch and all changes (DESTRUCTIVE)
```

Ask user to choose.

### Phase 4: Execute

**Option 1 (Merge)**:
```bash
git checkout main && git merge <branch>
```

**Option 2 (PR)**:

1. Read `.claude/project-config.json` for PR settings
2. Build PR body based on `pr.bodyStyle`:

   **`summary-with-links`** (default):
   - Read `.claude/workflow-state.json`
   - Extract `summary` and `decisions` from each completed step
   - Format:
     ```markdown
     ## Summary
     {workflow description from YAML}

     ## Key Decisions
     {bullet list of decisions from each step}

     ## Review
     {summary from review step, if exists}

     ## Plan Documents
     - [Design](docs/plans/{date}-{name}-design.md)
     - [Plan](docs/plans/{date}-{name}-plan.md)
     - [Review](docs/plans/{date}-{name}-review.md)

     ## Test Results
     {test pass/fail summary from verification}
     ```
   - Only include sections that have data (skip empty ones)
   - Link paths are relative to repo root

3. Execute:
   ```bash
   git push -u origin <branch>
   gh pr create --title "<title>" --body "<generated-body>"
   ```

4. If `workflow-state.json` not found (non-workflow usage), fall back to commit log:
   ```bash
   gh pr create --title "<title>" --body "$(git log --oneline main..HEAD)"
   ```

Return PR URL.

**Option 3 (Keep)**:
Confirm branch name and state. No action.

**Option 4 (Discard)**:
Require explicit: "Type DISCARD to confirm"
```bash
git checkout main && git branch -D <branch>
```

### Phase 5: Cleanup
1. Update `.claude/workflow-state.json` status to "completed"
2. If worktree was used, offer to clean it up
3. If `docs/plans/` has files from this workflow, suggest: "플랜 문서를 정리하려면: `/plan-cleanup`"

## Output

```
✅ Branch completed: {action taken}
   {branch name} → {result}
```

## Common Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|-----------|
| Merging with failing tests | Broken main branch | Phase 1 blocks until all tests pass |
| Forgetting uncommitted files | Incomplete feature shipped | `git status` check in Phase 1 |
| Force-pushing shared branch | Other people's work lost | Never use `--force` on shared branches |
| Skipping PR description | Reviewers waste time understanding changes | Option 2 auto-generates description from commit log |

## Red Flags

Stop and reassess if:
- You're tempted to merge with "known" test failures
- There are untracked files that look like they belong to the feature
- The branch is significantly behind main (rebase first)
- Commit messages are unclear or missing context
- The diff includes debugging code (console.log, print statements)

## Quick Reference

```
Tests pass? ──No──→ STOP. Fix first.
            │
           Yes
            │
Uncommitted? ──Yes──→ Commit or stash first.
            │
            No
            │
Present 4 options → User chooses → Execute → Cleanup state
```

## Rules
- NEVER proceed past Phase 1 if tests fail
- NEVER execute Option 4 without explicit confirmation
- For Option 2, include test results in PR body
- Check for debug/temporary code before allowing merge
