---
name: cch-rf-swarm
description: Multi-agent swarms. 4 topologies (hierarchical, mesh, hybrid, adaptive).
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, TaskCreate, TaskUpdate, TaskList
argument-hint: <init|status|stop> [--topology T] [--agents N]
---

# cch-rf-swarm

Multi-agent swarms with 4 topologies: hierarchical, mesh, hybrid, and adaptive.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure ruflo`
3. Set: `RUFLO_CLI="$(sources_resolve_path ruflo)/bin/cli.js"` — or resolve manually: `RUFLO_CLI="$(pwd)/.claude/cch/sources/ruflo/bin/cli.js"`
4. Verify: `test -f "$RUFLO_CLI"` — if missing, report error and stop.

### Execution

1. Parse arguments: action (init/status/stop), topology (hierarchical/mesh/hybrid/adaptive, default: hierarchical), agent count (default: 3).

2. **init** action:
   - Run: `node "$RUFLO_CLI" swarm init --topology <T> --max-agents <N>` to initialize swarm configuration.
   - Create TaskCreate entries for tracking each agent's work.
   - Spawn agents using the Agent tool with appropriate OMC subagent types based on roles:
     - executor: implementation tasks
     - test-engineer: testing tasks
     - verifier: validation tasks
     - code-reviewer: review tasks
   - Monitor progress via TaskList/TaskUpdate.

3. **status** action:
   - Run: `node "$RUFLO_CLI" swarm status` to get current swarm state.
   - Report: active agents, completed tasks, pending tasks, topology diagram.

4. **stop** action:
   - Run: `node "$RUFLO_CLI" swarm stop` to gracefully stop all agents.
   - Collect final results and generate summary report.
