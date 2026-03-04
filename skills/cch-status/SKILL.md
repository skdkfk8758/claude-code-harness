---
name: cch-status
description: Show CCH health status including current mode, tier, health state, and reason codes.
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Status

Display the current CCH health status and diagnostics.

## Steps

1. Locate `bin/cch` in the plugin directory.
2. Run:
```bash
bash "<plugin-root>/bin/cch" status
```

3. Present the output showing:
   - Current mode (plan/code)
   - Tier level (0/1/2)
   - Health status (Healthy / Degraded / Blocked)
   - Reason codes (if any)
   - Current branch and linked bead (if available)

4. If health is not Healthy, suggest remediation based on reason codes.
