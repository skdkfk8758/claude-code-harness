# Workflow YAML Schema Reference

## Required Fields

```yaml
name: string          # kebab-case identifier (e.g., feature-dev, bugfix)
description: string   # one-line description in Korean or English
```

## Steps Array (required, at least 1)

```yaml
steps:
  - id: string        # unique within workflow (e.g., design, planning, implementation)
    type: string      # one of: skill, agent, agent-chain
    description: string  # what this step does
```

## Step Types

### type: skill (Gate — user must invoke manually)
```yaml
- id: design
  type: skill
  skill: brainstorming       # must exist in skills/ directory
  description: "..."
  output: docs/plans/{date}-{name}-design.md    # optional
  gate: user-approval        # required for skill type
```

### type: agent (Executor — automatic dispatch)
```yaml
- id: implementation
  type: agent
  agent: code-refactor-master   # must exist in agents/ directory
  description: "..."
  input: docs/plans/{date}-{name}-tasks.md      # optional
  output: docs/plans/{date}-{name}-review.md    # optional
  auto: true                 # true = no user confirmation needed
  optional: true             # true = can be skipped
  cross-cutting:             # optional, rules injected into agent prompt
    - tdd
    - verification
```

### type: agent-chain (Sequential agents — automatic)
```yaml
- id: planning
  type: agent-chain
  agents:                    # executed in order
    - planner
    - plan-reviewer
  description: "..."
  output:
    - docs/plans/{date}-{name}-plan.md
    - docs/plans/{date}-{name}-context.md
    - docs/plans/{date}-{name}-tasks.md
  auto: true
```

## Template Variables

| Variable | Expands to |
|----------|-----------|
| `{date}` | Current date (YYYY-MM-DD) |
| `{name}` | Workflow instance name (user-provided) |

## Available Skills (for gate steps)

| Skill | Purpose |
|-------|---------|
| brainstorming | Design exploration and approval |
| writing-plans | Task decomposition and approval |
| finishing-branch | Completion options (merge/PR/keep/discard) |
| systematic-debugging | Root cause investigation |
| verification | Verification before completion claims |
| tdd | TDD enforcement |

## Available Agents (for executor steps)

| Agent | Purpose |
|-------|---------|
| planner | 3-file plan generation |
| plan-reviewer | Critical plan review |
| code-refactor-master | Implementation with batch execution |
| spec-reviewer | Spec compliance check |
| code-quality-reviewer | Code quality review |
| code-architecture-reviewer | Architecture review |
| documentation-architect | Documentation updates |
| web-research-specialist | Technical research |
| refactor-planner | Codebase analysis for refactoring |

## Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| WF001 | error | `name` field exists and is kebab-case |
| WF002 | error | `description` field exists |
| WF003 | error | `steps` array exists and is non-empty |
| WF004 | error | Each step has unique `id` |
| WF005 | error | Each step has valid `type` (skill/agent/agent-chain) |
| WF006 | error | `type: skill` has `skill` field referencing existing skill |
| WF007 | error | `type: agent` has `agent` field referencing existing agent |
| WF008 | error | `type: agent-chain` has `agents` array with existing agents |
| WF009 | warn | First or last step should be a gate |
| WF010 | warn | `cross-cutting` references existing skills |
| WF011 | info | Output paths use template variables |
