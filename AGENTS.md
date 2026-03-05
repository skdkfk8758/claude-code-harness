# Agent Instructions

This project uses **plan documents** (`docs/plans/`) for task tracking and **`bin/cch`** as the CLI engine.

## Quick Reference

```bash
bin/cch setup             # Initialize CCH environment
bin/cch status            # Check health/mode/tier
bin/cch mode [plan|code]  # Switch mode
bin/cch branch create <type> <work-id>  # Create feature branch
bin/cch skill list        # List available skills
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update plan documents** - Mark completed items, update status
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
