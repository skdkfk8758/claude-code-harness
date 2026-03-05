# Skill & Agent Schema Reference

## Skill (SKILL.md) Schema

### Frontmatter (required)

```yaml
---
name: string              # kebab-case (e.g., brainstorming, tdd)
description: string       # starts with "Use when" (CSO optimization)
user-invocable: true      # must be true for /skill-name invocation
allowed-tools: string     # comma-separated (e.g., Read, Write, Glob, Agent)
argument-hint: string     # optional, usage pattern (e.g., "<topic>")
---
```

### Body

Markdown content with instructions for Claude. Recommended sections:
- Process / Steps
- Rules
- Output format

### Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| SK001 | error | Frontmatter exists (starts with `---`) |
| SK002 | error | `name` field present and kebab-case |
| SK003 | error | `description` field present |
| SK004 | warn | Description starts with "Use when" |
| SK005 | warn | Description under 500 characters |
| SK006 | info | Body under 500 words (token efficiency) |
| SK007 | warn | If `user-invocable: true`, `allowed-tools` present |
| SK008 | warn | Description not >80% similar to another skill |
| SK009 | error | Name contains only letters, numbers, hyphens |
| SK010 | info | Has `## Rules` section |
| SK011 | warn | If expects arguments, has `argument-hint` |

## Agent (.md) Schema

### Frontmatter (optional)

```yaml
---
name: string              # kebab-case (e.g., planner, code-refactor-master)
description: string       # one-line purpose
model: string             # optional: opus, sonnet, haiku, inherit
---
```

If no frontmatter, agent name is derived from filename.

### Body

Markdown content with:
- Role description (who the agent is)
- Input (what it receives)
- Process (step-by-step)
- Output format
- Rules

### Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| AG001 | error | File exists and is non-empty |
| AG002 | warn | Has role description in first paragraph |
| AG003 | warn | Has `## Input` or `## Process` section |
| AG004 | warn | Has `## Output` section |
| AG005 | warn | Has `## Rules` section |
| AG006 | info | Body under 800 words (token efficiency) |
| AG007 | info | If model specified, valid value (opus/sonnet/haiku/inherit) |

## Skill Types

| Type | Purpose | Example |
|------|---------|---------|
| Gate | User approval checkpoint | brainstorming, writing-plans, finishing-branch |
| Cross-cutting | Rules injected into agents | tdd, verification, systematic-debugging |
| Orchestrator | Manages workflow progression | workflow |
| Manager | CRUD operations | workflow-manager, skill-manager |
| Setup | Environment initialization | setup |

## Agent Roles

| Role | Purpose | Example |
|------|---------|---------|
| Planner | Generate plans, no code | planner, refactor-planner |
| Reviewer | Evaluate artifacts | plan-reviewer, spec-reviewer, code-quality-reviewer |
| Executor | Implement changes | code-refactor-master |
| Researcher | Gather information | web-research-specialist |
| Documenter | Update documentation | documentation-architect |
