---
name: cch-setup
description: Initialize Claude Code Harness environment. Checks paths, permissions, creates state directory, and validates capability sources.
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Setup

Initialize the Claude Code Harness environment.

## Steps

1. Find the plugin root by searching for the `bin/cch` executable:
   - Use Glob for `**/bin/cch` or check known paths
   - The plugin root is the parent directory of `bin/`

2. Run setup:
```bash
bash "<plugin-root>/bin/cch" setup
```

3. Report results to the user. If setup fails, explain which checks failed.

4. Verify vendor readiness:
   - **Superpowers**: Run `bash "<plugin-root>/bin/cch" sources check superpowers` — if not installed, advise: `claude plugin install superpowers@superpowers-marketplace`
   - Report summary: installed sources and synced skill count.

5. On success, suggest running `/cch-mode` to select a working mode.
