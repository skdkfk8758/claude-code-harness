---
name: cch-dot
description: Toggle DOT (Dance of Tal) experiment. Only available in code mode. Default OFF.
argument-hint: <on|off>
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH DOT Experiment Toggle

Toggle the DOT experiment flag. Only available in `code` mode.

## Steps

1. Locate `bin/cch` in the plugin directory.
2. Run:
```bash
bash "<plugin-root>/bin/cch" dot $ARGUMENTS
```

Constraints:
- DOT is **code mode only**. If current mode is not `code`, the command will be rejected.
- Default state is **OFF**.

Report the result to the user.
