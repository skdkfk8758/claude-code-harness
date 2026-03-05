---
name: workflow
description: Use when starting a development workflow or checking current workflow progress. Orchestrates skill gates and agent dispatches based on workflow definitions.
user-invocable: true
allowed-tools: Read, Glob, Grep, Agent, AskUserQuestion, Bash, Write
argument-hint: "<workflow-name> [resume]"
---

# Workflow Orchestrator

You manage multi-step development workflows defined in YAML.

## Path Discovery

Plugin root (for reading agents):
!`echo ${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname ${CLAUDE_SKILL_DIR}))}`

This skill's directory (for reading workflow YAMLs):
!`echo ${CLAUDE_SKILL_DIR}`

## Available Workflows
- `feature-dev` — 기능 개발 (설계→플래닝→구현→리뷰→완료)
- `bugfix` — 버그 수정 (근본원인 조사→수정→리뷰→완료)
- `refactor` — 리팩토링 (분석→설계→플래닝→구현→리뷰→완료)

## Startup

1. If argument provided, load that workflow YAML from this skill's directory.
   Otherwise, list available workflows and ask user to choose.
2. Read the workflow YAML file (e.g., `feature-dev.yaml` in this skill's directory)
3. Read current state from `.claude/workflow-state.json` in the project root.
   If `resume` is specified or state file exists, detect progress and offer to continue.

## State Management

Track progress in the project's `.claude/workflow-state.json`:
```json
{
  "workflow": "feature-dev",
  "name": "my-feature",
  "currentStep": 2,
  "startedAt": "2026-03-06T10:00:00Z",
  "steps": {
    "design": { "status": "completed", "output": "docs/plans/2026-03-06-my-feature-design.md" },
    "planning": { "status": "in-progress" }
  }
}
```
Update this file after each step completes.

## Workflow Execution

For each step in the YAML:

### `type: skill` (Gate — requires user action)
1. Announce the gate:
   ```
   ────────────────────────────────────
   [Gate] Step {N}/{total}: {id}
   {description}
   Expected output: {output}
   ────────────────────────────────────
   ```
2. Tell the user: **"Please run `/{skill-name}` to proceed."**
3. You CANNOT invoke the skill yourself — the user must do it.
4. Wait for user to confirm the gate is complete.
5. Verify output file exists, update state.

### `type: agent` (Executor — automatic)
1. Resolve the agent prompt file path:
   - Use the plugin root path discovered above
   - Read `{plugin-root}/agents/{agent-name}.md`
2. Build the dispatch prompt:
   - Include the agent's full prompt content
   - Append context: previous step outputs (read the files)
   - If step has `cross-cutting` list, read each skill's SKILL.md and append the core rules
3. Dispatch via **Agent tool** with `subagent_type: "general-purpose"`
4. If `auto: true`, proceed to next step. Otherwise, present results and ask user.
5. Update state.

### `type: agent-chain` (Chained Executors — automatic)
1. Execute agents sequentially in order
2. First agent: dispatch with full context
3. Subsequent agents: dispatch with previous agent's output as additional context
4. **NEEDS_REVISION handling**: If plan-reviewer returns NEEDS_REVISION:
   - Re-invoke the previous agent with the reviewer's findings
   - Maximum 2 retry cycles, then ask user
5. Update state after chain completes.

## Cross-Cutting Rules

When a step specifies `cross-cutting: [tdd, verification, ...]`:
1. Read each skill from `{plugin-root}/skills/{name}/SKILL.md`
2. Extract the core rules section
3. Append to the agent dispatch prompt with header:
   ```
   ## NON-NEGOTIABLE RULES (from {skill-name})
   {rules content}
   ```

## 2-Stage Review Pattern

For implementation steps, after each batch of 3 tasks:
1. Dispatch **spec-reviewer** agent with task spec + changed files
2. If PASS → dispatch **code-quality-reviewer** agent
3. If either FAIL → report to user, fix before proceeding
4. Only continue to next batch when both PASS

## Progress Display

After each step completion:
```
[workflow] feature-dev: step {N}/{total} ({step-id}) ✓ completed
[workflow] Next: step {N+1}/{total} ({next-step-id}) — {type}
```

## Agent Dispatch Red Flags

When dispatching agents, NEVER:
- Let an agent modify files outside its task scope
- Let an agent skip its verification step
- Dispatch next agent before current agent confirms status (DONE/BLOCKED/etc.)
- Accept "DONE" without checking actual output files
- Re-dispatch more than 2 times without escalating to user
- Let an agent silently swallow errors or suppress test failures
- Accept partial completion as full completion
- Skip the 2-stage review because "the change is small"

When an agent returns status:
- **DONE** → verify output exists, run 2-stage review, proceed
- **DONE_WITH_CONCERNS** → present concerns to user, ask whether to proceed
- **NEEDS_CONTEXT** → provide requested context and re-dispatch
- **BLOCKED** → escalate to user immediately, do not retry automatically

## Error Handling
- Agent dispatch failure → report error, ask user how to proceed
- Never skip a gate step — gates exist to enforce user decisions
- Missing output file after step → warn, ask to retry or skip
- NEEDS_REVISION from reviewer → re-invoke previous agent (max 2 retries)
- If state file is corrupted → ask user to start fresh or specify step to resume from
