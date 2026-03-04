---
name: cch-rf-memory
description: Agent shared memory - store, search, retrieve with HNSW vector search.
user-invocable: true
allowed-tools: Bash, Read
argument-hint: <store|search|retrieve|status>
---

# cch-rf-memory

Agent shared memory with HNSW vector search: store, search, retrieve, and status operations.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure ruflo`
3. Set: `RUFLO_CLI="$(sources_resolve_path ruflo)/bin/cli.js"` — or resolve manually: `RUFLO_CLI="$(pwd)/.claude/cch/sources/ruflo/bin/cli.js"`
4. Verify: `test -f "$RUFLO_CLI"` — if missing, report error and stop.

### Execution

1. Parse the action argument.

2. **store** action:
   - Accept key and content from user arguments.
   - Run: `node "$RUFLO_CLI" memory store --key "<key>" --content "<content>"`
   - Report: stored entry ID, key, timestamp.

3. **search** action:
   - Accept query string from user arguments.
   - Run: `node "$RUFLO_CLI" memory search --query "<query>" --limit 10`
   - Display: matching entries ranked by relevance score with snippets.

4. **retrieve** action:
   - Accept key or ID from user arguments.
   - Run: `node "$RUFLO_CLI" memory retrieve --key "<key>"`
   - Display: full entry content with metadata.

5. **status** action:
   - Run: `node "$RUFLO_CLI" memory status`
   - Display: total entries, memory usage, index health, last compaction time.
