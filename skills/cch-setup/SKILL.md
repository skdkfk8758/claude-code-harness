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

3. Run environment check for detailed capability scan:
```bash
node "<plugin-root>/scripts/check-env.mjs" --cli
```

4. Report results to the user:
   - Tier level (0/1/2) and meaning
   - Detected plugins and MCP servers
   - Health status
   - If setup fails, explain which checks failed

5. On success, suggest next steps:
   - `/cch-plan` to start a design workflow
   - `/cch-todo` to view current tasks