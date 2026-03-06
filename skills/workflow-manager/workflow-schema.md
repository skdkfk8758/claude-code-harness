# Workflow YAML Schema Reference

## Top-Level Fields

```yaml
name: string              # kebab-case identifier (e.g., feature-dev, bugfix)
description: string        # one-line description in Korean or English
branch-prefix: string      # optional, git branch prefix (e.g., "feature/", "fix/")
```

### branch-prefix Resolution

The orchestrator resolves branch prefix in this priority:
1. Workflow YAML `branch-prefix` field (recommended)
2. `git.branchPrefix.{workflow-name}` in `.claude/project-config.json` (fallback)
3. `{workflow-name}/` (last resort default)

## Steps Array (required, at least 1)

```yaml
steps:
  - id: string        # unique within workflow (e.g., design, planning, implementation)
    type: string      # one of: skill, agent, agent-chain, parallel, conditional
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
    - name: tdd
      enforcement: enforce   # enforce or suggest (default: suggest)
    - name: verification
      enforcement: suggest
  review-pipeline:           # optional, configurable review after execution
    batch-size: 3            # tasks per batch (default: 3)
    reviewers:               # sequential — each runs only if previous PASS
      - agent: spec-reviewer
      - agent: code-quality-reviewer
    fix-agent: code-refactor-master    # agent for fixes on FAIL
    max-retries-per-reviewer: 1        # per reviewer per batch
  retry-on-fail:             # optional, auto-retry on review failure
    fix-agent: code-refactor-master    # string: single agent
    # OR map syntax for routing:
    # fix-agents:
    #   SECURITY_FAIL: security-fixer
    #   PERFORMANCE_FAIL: performance-optimizer
    #   default: code-refactor-master
    max-retries: 2
    trigger-status: "NEEDS_CHANGES"
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
  auto: true
```

### type: parallel (Concurrent agents — automatic)
```yaml
- id: docs-and-review
  type: parallel
  steps:
    - agent: documentation-architect
      id: documentation          # unique sub-step id
    - agent: code-architecture-reviewer
      id: review
  description: "..."
  auto: true
```

All sub-steps execute concurrently. The parallel step completes when ALL sub-steps finish.
Cross-cutting rules apply to each sub-step independently.

### type: conditional (Branching — automatic)
```yaml
- id: review-or-skip
  type: conditional
  condition:
    check: file-count        # built-in check type
    threshold: 5
    operator: ">="           # >=, <=, ==, !=, >, <
  then:
    agent: code-architecture-reviewer
    id: full-review
  else:                      # optional — if omitted, step is skipped when false
    agent: code-quality-reviewer
    id: light-review
  description: "..."
  auto: true
```

Built-in condition checks:

| Check | Description | Parameters |
|-------|-------------|------------|
| `file-count` | Changed file count (`git diff --name-only`) | `threshold` (number), `operator` |
| `line-count` | Changed line count (`git diff --stat`) | `threshold` (number), `operator` |
| `has-output` | Previous step's output file exists | `step-id` (string) |
| `step-status` | Previous step's state status | `step-id`, `expected` (string) |
| `command` | Shell command exit code (0=true) | `run` (string) |

## Cross-Cutting with Enforcement

```yaml
cross-cutting:
  - name: tdd
    enforcement: enforce     # orchestrator reads skill's ## Enforcement Verification section
  - name: verification
    enforcement: suggest     # rules injected into prompt, no post-verification
```

For `enforcement: enforce`, the referenced skill's SKILL.md must contain a `## Enforcement Verification` section defining:
- **Pre-Step Setup**: Actions before agent dispatch
- **Evidence Required**: What to check in agent output
- **Pass Criteria**: Conditions for passing
- **Failure Response**: Re-dispatch message

If the section is missing, enforcement falls back to `suggest` with a warning.

## Template Variables

| Variable | Expands to |
|----------|-----------|
| `{date}` | Current date (YYYY-MM-DD) |
| `{name}` | Workflow instance name (user-provided) |

## Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| WF001 | error | `name` field exists and is kebab-case |
| WF002 | error | `description` field exists |
| WF003 | error | `steps` array exists and is non-empty |
| WF004 | error | Each step has unique `id` |
| WF005 | error | Each step has valid `type` (skill/agent/agent-chain/parallel/conditional) |
| WF006 | error | `type: skill` has `skill` field referencing existing skill |
| WF007 | error | `type: agent` has `agent` field referencing existing agent |
| WF008 | error | `type: agent-chain` has `agents` array with existing agents |
| WF009 | warn | First or last step should be a gate |
| WF010 | warn | `cross-cutting` references existing skills |
| WF011 | info | Output paths use template variables |
| WF012 | error | `type: parallel` has `steps` array with valid sub-step definitions |
| WF013 | error | `type: conditional` has `condition` with valid `check` and `then` branch |
| WF014 | warn | `cross-cutting` with `enforcement: enforce` references skill with `## Enforcement Verification` section |
| WF015 | warn | `review-pipeline` reviewers reference existing agents |
| WF016 | info | `branch-prefix` present (recommended over project-config.json) |
| WF017 | warn | `retry-on-fail` fix-agent(s) reference existing agents |
