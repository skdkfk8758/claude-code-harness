---
name: cch-gp-team
description: Build AI agent teams from natural language. Multi-model (Claude+Codex+Gemini).
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, TaskCreate, TaskUpdate, TaskList
argument-hint: <natural language team description>
---

# cch-gp-team

Build AI agent teams from natural language descriptions. Supports multi-model orchestration across Claude, Codex, and Gemini agents.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/kkirikkiri`
4. If either command fails, report the error and stop.

### Execution
1. Read kkirikkiri plugin configuration from the submodule directory.
2. Parse the user's natural language team description to extract roles and model assignments.
3. Map roles to agent types: claude, codex, gemini.
4. Use `omc_run_team_start` MCP tool to spawn the team:
   - teamName: derived from description
   - agentTypes: mapped model array
   - tasks: parsed task list
   - cwd: current working directory
5. Use `omc_run_team_wait` to collect results from all workers.
6. Generate a team execution report with per-worker results, timing, and overall status.
