# Skill & Agent Schema Reference

## Skill (SKILL.md) Schema

### Frontmatter (required)

```yaml
---
name: string                    # kebab-case, max 64 chars (e.g., brainstorming, tdd)
description: string             # what this skill does and when to use it
user-invocable: boolean         # true = appears in /menu (default: true)
allowed-tools: string           # comma-separated (e.g., Read, Write, Glob, Agent)
argument-hint: string           # optional, usage pattern (e.g., "<topic>")
disable-model-invocation: boolean  # true = manual /invoke only, Claude cannot auto-trigger (default: false)
model: string                   # optional: model to use when skill is active
context: string                 # optional: "fork" to run in isolated subagent
agent: string                   # optional: subagent type when context=fork (e.g., Explore, Plan, general-purpose)
hooks: object                   # optional: lifecycle hooks scoped to this skill
---
```

### Field Details

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | yes | (dir name) | Slash-command name. Lowercase letters, numbers, hyphens only. |
| `description` | recommended | (first paragraph) | Drives auto-trigger matching. Include what the skill does AND when to use it. |
| `user-invocable` | no | `true` | `false` hides from /menu but Claude can still auto-invoke. |
| `disable-model-invocation` | no | `false` | `true` prevents Claude from auto-triggering. Use for side-effect actions (deploy, commit). |
| `allowed-tools` | no | — | Tools Claude can use without per-use approval when this skill is active. |
| `argument-hint` | no | — | Autocomplete hint. e.g., `"<topic>"`, `"[issue-number]"` |
| `model` | no | — | Override model for this skill's execution. |
| `context` | no | — | `"fork"` runs skill in isolated subagent context. |
| `agent` | no | `general-purpose` | Subagent type when `context: fork`. Built-in: `Explore`, `Plan`, `general-purpose`, or custom agent name. |
| `hooks` | no | — | Skill-scoped lifecycle hooks. See Claude Code hooks docs. |

### CCH Convention: Skill Types

CCH plugin skills use an additional classification for workflow integration. This is a CCH convention, not part of the official skill spec.

| Type | Purpose | Example |
|------|---------|---------|
| Gate | User approval checkpoint | brainstorming, writing-plans, finishing-branch |
| Cross-cutting | Rules injected into agents | tdd, verification, systematic-debugging |
| Orchestrator | Manages workflow progression | workflow |
| Manager | CRUD operations | workflow-manager, skill-manager |
| Setup | Environment initialization | setup |

### Body

Markdown content with instructions for Claude. Recommended sections:
- Process / Steps
- Rules
- Output format

### String Substitutions

Available in skill content (resolved before Claude sees it):

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking |
| `$ARGUMENTS[N]` or `$N` | Specific argument by 0-based index |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_SKILL_DIR}` | Directory containing this SKILL.md |

### Dynamic Context Injection

Use `` !`command` `` to run shell commands at load time. Output replaces the placeholder:

```markdown
Current branch: !`git branch --show-current`
Plugin root: !`echo ${CLAUDE_PLUGIN_ROOT}`
```

### Validation Rules

| Rule | Severity | Description |
|------|----------|-------------|
| SK001 | error | Frontmatter exists (starts with `---`) |
| SK002 | error | `name` field present and kebab-case (max 64 chars) |
| SK003 | error | `description` field present |
| SK004 | info | Description starts with "Use when" (CCH convention, not required) |
| SK005 | warn | Description under 1024 characters |
| SK006 | info | Body under 500 lines (token efficiency; move detail to supporting files) |
| SK007 | warn | If `user-invocable: true` and not `disable-model-invocation`, `allowed-tools` recommended |
| SK008 | warn | Description not >80% similar to another skill |
| SK009 | error | Name contains only lowercase letters, numbers, hyphens |
| SK010 | info | Has `## Rules` section |
| SK011 | warn | If expects arguments, has `argument-hint` |
| SK012 | warn | If `context: fork`, `agent` field recommended |
| SK013 | warn | If `disable-model-invocation: true` and `user-invocable: false`, skill is unreachable |
| SK014 | info | All frontmatter fields are recognized (no unknown keys) |
| SK015 | warn | Cross-cutting skills used with `enforcement: enforce` in any workflow have `## Enforcement Verification` section |
| SK016 | warn | If `user-invocable: true` and has `argument-hint` with subcommands (`\|` separator), must have `## Input Resolution` section with NL→Command Map |

---

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

### Agent Roles

| Role | Purpose | Example |
|------|---------|---------|
| Planner | Generate plans, no code | planner, refactor-planner |
| Reviewer | Evaluate artifacts | plan-reviewer, spec-reviewer, code-quality-reviewer |
| Executor | Implement changes | code-refactor-master |
| Researcher | Gather information | web-research-specialist |
| Documenter | Update documentation | documentation-architect |

---

## Interview Section Rules

Skills with user interviews (`## Interview` section) must follow these rules:

| Rule | Severity | Description |
|------|----------|-------------|
| IV001 | warn | Interview section has `### Context` subsection — what to auto-scan before asking |
| IV002 | warn | Each question has: text, type (open/select/multi-select/confirm), dependency (if any) |
| IV003 | warn | Questions with dependencies are marked sequential — not bundled in one turn |
| IV004 | info | Recommendations separated from question text (not inline with options) |
| IV005 | warn | Interview ends with `### Validation` subsection — how to verify answers |
| IV006 | info | Has scenario examples for testing interview output |
