# Skill Manager Design

> Date: 2026-03-04
> Status: Approved
> Approach: Hybrid (single skill + dedicated agent)

## Problem

68+ skills across 4 sources (CCH repo, CCH cache, Superpowers, custom) with no unified inventory, quality analysis, lifecycle management, or dependency tracking.

## Architecture

```
┌──────────────────────────────────────────────────┐
│  /cch-skill-manager <subcommand> [args]          │
│  list | info | lint | create | edit | deps | search │
└──────────┬──────────────────┬────────────────────┘
           │                  │
      Light ops          Heavy analysis
      (direct)           (agent dispatch)
           │                  │
           ▼                  ▼
    bin/lib/skill.sh    .claude/agents/skill-analyzer.md
```

### Skill Sources

| Source | Path | Type |
|--------|------|------|
| CCH repo | `./skills/cch-*/SKILL.md` | Development |
| CCH cache | `~/.claude/plugins/cache/claude-code-harness-marketplace/.../skills/` | Deployed |
| Superpowers | `~/.claude/plugins/cache/superpowers-marketplace/.../skills/` | External plugin |
| Custom | `~/.claude/commands/*.md` | User-defined |

### Command Routing

| Command | Handler | Description |
|---------|---------|-------------|
| `list` | skill.sh | All skills inventory (JSON table) |
| `info <name>` | skill.sh | Single skill metadata detail |
| `search <q>` | skill.sh + Agent | Keyword/context search |
| `lint [name]` | Agent | Quality analysis with lint rules |
| `create <name>` | Agent | TDD-based skill creation guide |
| `edit <name>` | Agent | Existing skill modification guide |
| `deps [name]` | Agent | Dependency graph & conflict analysis |

## Components

### 1. Skill: `cch-skill-manager/SKILL.md`

```yaml
name: cch-skill-manager
description: Manage, analyze, and create skills across all plugin sources. Use for skill inventory, linting, creation, and dependency analysis.
user-invocable: true
allowed-tools: [Bash, Read, Glob, Grep, Agent, Write, Edit, AskUserQuestion]
argument-hint: "list | info <name> | lint [name] | create <name> | edit <name> | deps [name] | search <query>"
```

Entry point that routes subcommands. Light ops run `bin/cch skill` directly; heavy analysis dispatches the skill-analyzer agent.

### 2. Agent: `.claude/agents/skill-analyzer.md`

Specialized analysis agent with 4 modes:

| Mode | Trigger | Action |
|------|---------|--------|
| lint | `lint` subcommand | SKILL.md format, CSO rules, token efficiency, description quality |
| create | `create` subcommand | writing-skills TDD workflow guided creation |
| edit | `edit` subcommand | Analyze existing skill, guide modification |
| deps | `deps` subcommand | Cross-reference, duplicate, conflict analysis |

Tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion

### 3. CLI Utility: `bin/lib/skill.sh`

```bash
skill_scan_all()      # Collect metadata from all sources → JSON
skill_parse_meta()    # Parse single SKILL.md frontmatter
skill_validate()      # Basic format validation
skill_search()        # Name/description keyword matching
skill_list_sources()  # Registered source paths
```

Output format (JSON per skill):
```json
{
  "name": "cch-commit",
  "source": "cch-repo",
  "path": "./skills/cch-commit/SKILL.md",
  "user_invocable": true,
  "allowed_tools": ["Bash", "Read", "Glob"],
  "description": "Analyze changes and create logical commits...",
  "word_count": 342,
  "has_enhancement": true
}
```

### 4. `bin/cch` Extension

Add `skill` subcommand:
```bash
case "$1" in
  skill) shift; source "$LIB_DIR/skill.sh"; skill_dispatch "$@" ;;
esac
```

## Lint Rules

| Rule | Severity | Description |
|------|----------|-------------|
| SM001 | error | Missing frontmatter or YAML parse failure |
| SM002 | error | Missing `name` field |
| SM003 | error | Missing `description` field |
| SM004 | warn | Description doesn't start with "Use when" (CSO) |
| SM005 | warn | Description exceeds 500 chars |
| SM006 | info | Skill body exceeds 500 words (token efficiency) |
| SM007 | warn | `user-invocable: true` without `allowed-tools` |
| SM008 | info | No Enhancement section (tier underutilization) |
| SM009 | warn | Description similarity >80% with another skill (duplicate suspect) |
| SM010 | error | Invalid characters in name (only letters, numbers, hyphens) |
| SM011 | info | Missing `## When to Use` section |
| SM012 | warn | Expects arguments but no `argument-hint` |

## Dependency Analysis Patterns

Cross-reference patterns the agent scans:
- `superpowers:skill-name` — Superpowers skill reference
- `cch-skill-name` — CCH skill reference
- `Skill("skill-name")` — Skill tool invocation
- `bin/cch <command>` — CLI dependency
- `Enhancement (Tier N+)` — Tier dependency

## Error Handling

- Unknown subcommand → usage help
- Missing skill name → list available skills, ask selection
- Source path inaccessible → skip source, warn
- bin/cch execution failure → fallback to direct Glob/Read
- SKILL.md parse failure → report SM001, analyze parseable parts
- Skill not found → fuzzy match suggestions
- Too many analysis targets → batch by source

### Graceful Degradation

- No plugin cache → repo + custom skills only
- No Superpowers → CCH skills only, "Tier 0 mode" notice
- `bin/cch skill` not implemented yet → skill falls back to Glob/Read

## Testing Strategy

### Automated (harness.sh)

`tests/test_skill_manager.sh`:
- `skill_scan_all` finds repo/cache/custom skills
- `skill_parse_meta` extracts all frontmatter fields
- `skill_parse_meta` handles missing/malformed frontmatter
- `skill_validate` rejects invalid YAML, missing required fields
- `skill_search` matches name and description
- `skill_list_sources` includes all configured paths

### Skill Metadata (test_skill.sh extension)

- cch-skill-manager has valid frontmatter
- cch-skill-manager is user-invocable with argument-hint
- cch-skill-manager has enhancement section

### Agent Verification

- Lint rule fixtures in `tests/fixtures/` (valid + defective skills)
- TDD approach per writing-skills methodology
- Manual E2E workflow testing

## File Inventory

| File | Type | Purpose |
|------|------|---------|
| `skills/cch-skill-manager/SKILL.md` | New | Entry point skill |
| `.claude/agents/skill-analyzer.md` | New | Analysis agent |
| `bin/lib/skill.sh` | New | Metadata parsing utilities |
| `bin/cch` | Modified | Add `skill` subcommand |
| `tests/test_skill_manager.sh` | New | Unit tests |
| `tests/fixtures/valid-skill/SKILL.md` | New | Test fixture |
| `tests/fixtures/defective-skill/SKILL.md` | New | Test fixture |
