---
name: cch-rf-doctor
description: Ruflo system diagnostics - Node.js, npm, memory DB, MCP health.
user-invocable: true
allowed-tools: Bash, Read
argument-hint: [--fix]
---

# cch-rf-doctor

Ruflo system diagnostics covering Node.js, npm, memory DB, and MCP health.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure ruflo`
3. Set: `RUFLO_CLI="$(sources_resolve_path ruflo)/bin/cli.js"` — or resolve manually: `RUFLO_CLI="$(pwd)/.claude/cch/sources/ruflo/bin/cli.js"`
4. Verify: `test -f "$RUFLO_CLI"` — if missing, report error and stop.

### Execution

1. Parse the `--fix` flag (default: diagnostic only, no auto-fix).

2. **Node.js Check**:
   - Run: `node --version` — verify >= 18.x.
   - Report: version, path, status (OK/WARN/FAIL).

3. **npm Check**:
   - Run: `npm --version` — verify available.
   - Check Ruflo node_modules: `test -d "$(sources_resolve_path ruflo)/node_modules"`.

4. **Ruflo CLI Check**:
   - Run: `node "$RUFLO_CLI" --version` (or `node "$RUFLO_CLI" doctor` if available).
   - Report: CLI version, available commands, configuration status.

5. **Memory DB Check**:
   - Run: `node "$RUFLO_CLI" memory status` to check HNSW index health.
   - Report: entries count, index status, last compaction.

6. **MCP Health**:
   - Check if MCP server connections are active.
   - Report: connected servers, response times.

7. **Summary**:
   - Display a status table: component, status (OK/WARN/FAIL), details.
   - If `--fix` flag:
     - Auto-fix: run `npm install` for missing node_modules.
     - Auto-fix: reinitialize memory DB if corrupt.
     - Report what was fixed and what requires manual intervention.
