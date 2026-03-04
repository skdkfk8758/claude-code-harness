---
name: cch-status
description: Show CCH health status including current mode, health state, and fallback causes.
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Status

Display the current CCH health status and diagnostics.

## Steps

1. Locate `bin/cch` in the plugin directory.
2. Run:
```bash
bash "<plugin-root>/bin/cch" doctor --summary
```

3. Present the output showing:
   - Current mode
   - Health status (Healthy / Degraded / Blocked)
   - Fallback causes (if any)
   - Current branch and linked bead (if branch module loaded)
