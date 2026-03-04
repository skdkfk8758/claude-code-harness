---
name: cch-mode
description: Switch CCH operating mode. Available modes are plan, code, tool, and swarm.
argument-hint: <plan|code|tool|swarm>
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Mode Switch

Switch the CCH operating mode.

## Steps

1. Locate `bin/cch` in the plugin directory.
2. Run:
```bash
bash "<plugin-root>/bin/cch" mode $ARGUMENTS
```

Mode reference:
- **plan**: Architecture design and task breakdown (ruflo + superpowers)
- **code**: Implementation and development (omc + superpowers, DOT eligible)
- **tool**: External tool integration (gptaku_plugins)
- **swarm**: Multi-agent coordination (ruflo)

If no argument is provided, display the current mode. Report the result to the user.
