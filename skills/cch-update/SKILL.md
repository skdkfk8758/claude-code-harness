---
name: cch-update
description: Check for and apply CCH updates. Validates pinned versions and provides change summaries with rollback points.
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Update

Check for available updates and apply them with safety checks.

## Steps

1. Locate `bin/cch` in the plugin directory.
2. Run:
```bash
bash "<plugin-root>/bin/cch" update check
```

3. Report the update status including version info and any changes detected.
