---
name: cch-gp-pumasi
description: Parallel coding - Claude as PM, Codex workers as devs. 7-phase workflow.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, TaskCreate, TaskUpdate, TaskList
argument-hint: <coding task description>
---

# cch-gp-pumasi

Parallel coding workflow with Claude as PM and Codex workers as developers. Implements a 7-phase workflow for structured parallel execution.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/pumasi`
4. If either command fails, report the error and stop.

### Execution
1. Read pumasi plugin configuration.
2. **PM Phase**: Use Agent(architect) to analyze the task and decompose into parallel work units.
3. **Task Creation**: Use TaskCreate to register each work unit with descriptions and dependencies.
4. **Distribution**: Assign work units to worker agents (PM=claude, workers=codex).
5. **Execution**: Use `omc_run_team_start` to spawn parallel workers. Each worker implements its assigned unit.
6. **Collection**: Use `omc_run_team_wait` to gather all results.
7. **Integration**: Merge worker outputs, resolve conflicts.
8. **Review**: Use Agent(verifier) to validate the integrated result. Report pass/fail with details.
