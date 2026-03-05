---
name: skill-manager
description: Use when adding, removing, editing, or validating skills and agents. Manages SKILL.md and agent .md files with schema validation and config sync.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
argument-hint: "list | show <name> | create-skill <name> | create-agent <name> | edit <name> | delete <name> | validate [name] | deps"
---

# Skill & Agent Manager

You manage skill and agent definitions for the CCH plugin.

Skill directory: !`echo ${CLAUDE_SKILL_DIR}`
Plugin root: !`echo ${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname ${CLAUDE_SKILL_DIR}))}`

## Command Router

| Command | Handler |
|---------|---------|
| `list` | List all skills and agents |
| `show <name>` | Show detail of a skill or agent |
| `create-skill <name>` | Create new skill via interview |
| `create-agent <name>` | Create new agent via interview |
| `edit <name>` | Edit existing skill or agent |
| `delete <name>` | Delete skill or agent (with confirmation) |
| `validate [name]` | Validate schema compliance |
| `deps` | Dependency analysis — who references whom |
| (no argument) | Show help |

## Paths

- Skills: `{plugin-root}/skills/*/SKILL.md`
- Agents: `{plugin-root}/agents/*.md`
- Skill rules: `{plugin-root}/skills/skill-rules.json`
- Schema reference: `skill-schema.md` in this skill's directory
- Workflow YAMLs: `{plugin-root}/skills/workflow/*.yaml` (for reference checking)

---

## List Handler

1. Glob skills: `{plugin-root}/skills/*/SKILL.md`
2. Glob agents: `{plugin-root}/agents/*.md`
3. For each, extract name and description from frontmatter
4. Output:

```
Skills (8)
──────────────────────────────────────────────
 Name                  Type           Description
──────────────────────────────────────────────
 workflow              Orchestrator   워크플로우 오케스트레이터
 brainstorming         Gate           설계 탐색 및 승인
 writing-plans         Gate           태스크 분해 및 승인
 finishing-branch      Gate           완료 처리
 verification          Cross-cutting  검증 강제
 tdd                   Cross-cutting  TDD 강제
 systematic-debugging  Cross-cutting  근본원인 조사
 workflow-manager      Manager        워크플로우 CRUD
 skill-manager         Manager        스킬/에이전트 CRUD
──────────────────────────────────────────────

Agents (10)
──────────────────────────────────────────────
 Name                        Model    Description
──────────────────────────────────────────────
 planner                     inherit  3종 플랜 문서 생성
 plan-reviewer               opus     플랜 비판적 리뷰
 code-refactor-master        opus     배치 실행 + TDD
 spec-reviewer               inherit  spec 준수 검증
 code-quality-reviewer       inherit  코드 품질 리뷰
 code-architecture-reviewer  sonnet   아키텍처 리뷰
 documentation-architect     inherit  문서 업데이트
 web-research-specialist     sonnet   기술 조사
 refactor-planner            inherit  리팩토링 분석
 implementer-prompt-template inherit  서브에이전트 템플릿
──────────────────────────────────────────────
```

---

## Show Handler

1. Determine if name matches a skill or agent
2. Read the file fully
3. Display:
   - Frontmatter fields
   - Section headers (## headings)
   - Word count
   - Referenced by: which workflows use this component (Grep workflow YAMLs)
   - References: which other skills/agents this component mentions

---

## Create-Skill Handler

### Interview

**Q1. Purpose**
```
What does this skill do? Describe in one sentence starting with "Use when":
```

**Q2. Type**
```
Skill type:
  1. Gate — requires user approval (e.g., brainstorming, finishing-branch)
  2. Cross-cutting — rules injected into agents (e.g., tdd, verification)
  3. Manager — CRUD operations (e.g., workflow-manager)
```

**Q3. Tools**
```
Which tools does this skill need?
Available: Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion, WebFetch, WebSearch
Default for gates: Read, Glob, Grep, Agent, AskUserQuestion, Write, Bash
Default for cross-cutting: Read, Grep, Glob, Bash
```

**Q4. Arguments**
```
Does this skill accept arguments? If yes, what's the usage pattern?
Example: "<topic>", "<file-path>", "list | show <name>"
```

**Q5. Process**
```
Describe the main steps this skill should follow (I'll structure them):
```

**Q6. Rules**
```
Any specific rules or constraints?
```

### Generation

1. Generate SKILL.md with:
   - Frontmatter from Q1-Q4
   - `!echo ${CLAUDE_SKILL_DIR}` path discovery
   - Process from Q5
   - Rules from Q6
   - Output section
2. Show preview, ask confirmation
3. Write to `{plugin-root}/skills/{name}/SKILL.md`
4. Run Validate Handler
5. Update synced files

---

## Create-Agent Handler

### Interview

**Q1. Role**
```
What role does this agent play? (one sentence)
```

**Q2. Model preference**
```
Which model should this agent use?
  1. inherit (default — uses whatever the parent uses)
  2. opus (complex reasoning, planning, implementation)
  3. sonnet (fast, pattern matching, review)
  4. haiku (simple tasks, classification)
```

**Q3. Input**
```
What does this agent receive as input?
```

**Q4. Process**
```
Describe the agent's step-by-step process:
```

**Q5. Output format**
```
What should the agent output? Describe the format:
```

**Q6. Rules**
```
Any specific rules or constraints?
```

### Generation

1. Generate agent .md with:
   - Frontmatter (name, description, model)
   - Role description
   - Input/Process/Output/Rules sections
2. Show preview, ask confirmation
3. Write to `{plugin-root}/agents/{name}.md`
4. Run Validate Handler
5. Update synced files

---

## Edit Handler

1. Find the skill or agent by name
2. Read current content
3. Show current structure (frontmatter + section headings)
4. Present options:
```
Edit options:
  1. Edit frontmatter (name, description, tools, etc.)
  2. Edit a section (select by heading)
  3. Add a section
  4. Remove a section
  5. Full rewrite (re-run interview)
  6. Done editing
```
5. Loop until "Done"
6. Show final preview, confirm
7. Write updated file
8. Validate + sync

---

## Delete Handler

1. Find the skill or agent
2. Show its detail (use Show Handler)
3. Check references:
   - Which workflows reference this component?
   - Which other skills/agents reference it?
4. If referenced, warn:
```
⚠️  This component is referenced by:
  - workflows/feature-dev.yaml (step: implementation)
  - skills/workflow/SKILL.md

Deleting will break these references. Continue?
```
5. Require explicit confirmation: type the name
6. Delete the file (and directory for skills)
7. Update synced files

---

## Validate Handler

If name specified, validate that component only.
If no name, validate ALL skills and agents.

### Process

1. Read `skill-schema.md` from this skill's directory
2. For skills: apply rules SK001-SK011
3. For agents: apply rules AG001-AG007
4. Check cross-references:
   - Skills referenced in workflow YAMLs exist
   - Agents referenced in workflow YAMLs exist
   - skill-rules.json entries match existing skills
5. Output:

```
Validating skills...
──────────────────────────────
 brainstorming      ✓ valid (0 errors, 0 warnings)
 tdd                ⚠ SK004: description doesn't start with "Use when"
 writing-plans      ✓ valid

Validating agents...
──────────────────────────────
 planner            ✓ valid
 plan-reviewer      ✓ valid
 spec-reviewer      ⚠ AG006: body is 850 words (over 800 limit)

Cross-references...
──────────────────────────────
 ✓ All workflow skill references valid
 ✓ All workflow agent references valid
 ⚠ skill-rules.json has entry "workflow-manager" but no matching promptTrigger update needed

Summary: 0 errors, 3 warnings, 0 info
```

---

## Deps Handler (Dependency Analysis)

1. Scan all skills — extract references to other skills/agents:
   - `/<skill-name>` invocations
   - `agents/<name>.md` references
   - `Agent(name)` mentions
2. Scan all agents — extract references
3. Scan workflow YAMLs — extract skill/agent references
4. Build dependency map and output:

```
Dependency Map
══════════════

workflow (skill)
  ├── uses agents: planner, plan-reviewer, code-refactor-master, ...
  ├── uses skills: brainstorming, writing-plans, finishing-branch
  └── reads: feature-dev.yaml, bugfix.yaml, refactor.yaml

brainstorming (skill)
  ├── dispatches: spec-document-reviewer (subagent prompt)
  └── referenced by: feature-dev.yaml, refactor.yaml

code-refactor-master (agent)
  ├── uses agents: spec-reviewer, code-quality-reviewer (2-stage review)
  └── referenced by: feature-dev.yaml, bugfix.yaml, refactor.yaml

Orphans (not referenced by any workflow):
  - web-research-specialist
  - implementer-prompt-template

Circular dependencies: none found
```

---

## Sync Handler (internal, after create/edit/delete)

### 1. skill-rules.json

For new skills, add a trigger entry:
```json
"{name}": {
    "type": "domain",
    "enforcement": "suggest",
    "priority": "high",
    "description": "{description}",
    "promptTriggers": {
        "keywords": ["{name}", ...extracted from description...],
        "intentPatterns": [...]
    }
}
```

For deleted skills, remove the entry.

### 2. README.md

Update the skill/agent tables if they exist.

### 3. Validation

Run validate on the changed component after every sync.

---

## Rules
- Always validate after create or edit
- Never delete without checking references first
- Never delete without explicit name confirmation
- Keep skill-rules.json in sync after every change
- Skill names must be unique across all skills
- Agent names must be unique across all agents
- No name collision between skills and agents
