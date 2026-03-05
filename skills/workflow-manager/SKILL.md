---
name: workflow-manager
description: Use when adding, removing, editing, or validating workflow definitions. Manages workflow YAML files and keeps related configs in sync.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
argument-hint: "list | show <name> | create <name> | edit <name> | delete <name> | validate [name]"
---

# Workflow Manager

You manage workflow YAML definitions for the CCH plugin.

Skill directory: !`echo ${CLAUDE_SKILL_DIR}`
Plugin root: !`echo ${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname ${CLAUDE_SKILL_DIR}))}`

## Command Router

Parse the argument and route to the appropriate handler:

| Command | Handler |
|---------|---------|
| `list` | List Handler |
| `show <name>` | Show Handler |
| `create <name>` | Create Handler |
| `edit <name>` | Edit Handler |
| `delete <name>` | Delete Handler |
| `validate [name]` | Validate Handler |
| (no argument) | Show help and available commands |

## Paths

- Workflow YAMLs: `{plugin-root}/skills/workflow/*.yaml`
- Available skills: `{plugin-root}/skills/*/SKILL.md`
- Available agents: `{plugin-root}/agents/*.md`
- Workflow orchestrator: `{plugin-root}/skills/workflow/SKILL.md`
- Skill rules: `{plugin-root}/skills/skill-rules.json`
- Schema reference: `workflow-schema.md` in this skill's directory

---

## List Handler

1. Glob for `{plugin-root}/skills/workflow/*.yaml`
2. For each YAML, read `name`, `description`, and count steps
3. Output table:

```
Available Workflows
───────────────────────────────────────
 Name          Steps  Description
───────────────────────────────────────
 feature-dev   7      기능 개발 워크플로우
 bugfix        5      버그 수정 워크플로우
 refactor      8      리팩토링 워크플로우
───────────────────────────────────────
```

---

## Show Handler

1. Read the specified workflow YAML
2. Parse steps and render visualization:

```
feature-dev — 기능 개발 워크플로우 (7 steps)
═══════════════════════════════════════════

① [Gate]  /brainstorming
   설계 승인
   → docs/plans/{date}-{name}-design.md

② [Auto]  Agent(planner) → Agent(plan-reviewer)
   플랜 생성 + 비판적 리뷰
   → *-plan.md, *-context.md, *-tasks.md

③ [Gate]  /writing-plans
   태스크 분해 승인
   → docs/plans/{date}-{name}-tasks.md

④ [Auto]  Agent(code-refactor-master)  [tdd, verification]
   배치 실행 + 2단계 리뷰

⑤ [Auto]  Agent(code-architecture-reviewer)
   아키텍처 리뷰

⑥ [Auto]  Agent(documentation-architect)  (optional)
   문서 정리

⑦ [Gate]  /finishing-branch
   완료 처리
```

---

## Create Handler

### Interview Flow

**Q1. Description**
```
워크플로우 "{name}"의 설명을 입력해주세요:
```

**Q2. Steps**
Present available components:
```
사용 가능한 게이트 (사용자 승인 필요):
  • brainstorming — 설계 탐색 및 승인
  • writing-plans — 태스크 분해 및 승인
  • finishing-branch — 완료 처리
  • systematic-debugging — 근본원인 조사
  • verification — 검증
  • tdd — TDD 강제

사용 가능한 에이전트 (자동 실행):
  • planner — 플랜 3종 문서 생성
  • plan-reviewer — 플랜 비판적 리뷰
  • code-refactor-master — 구현
  • spec-reviewer — spec 준수 검증
  • code-quality-reviewer — 코드 품질 리뷰
  • code-architecture-reviewer — 아키텍처 리뷰
  • documentation-architect — 문서 정리
  • web-research-specialist — 기술 조사
  • refactor-planner — 리팩토링 분석

어떤 단계들이 필요한가요? (순서대로 입력, 예: brainstorming, planner+plan-reviewer, writing-plans, code-refactor-master, finishing-branch)
```

**Q3. Per Step Configuration**
For each step, ask:
- Type: auto-detect (skill = gate, agent = executor, `+` separated = agent-chain)
- Auto: default true for agents, always manual for gates
- Cross-cutting: which rules to inject? (default: none)
- Optional: default false

**Q4. Confirmation**
Generate YAML preview and ask user to confirm.

### Post-Create

1. Write YAML to `{plugin-root}/skills/workflow/{name}.yaml`
2. Run Validate Handler on the new file
3. Update synced files (see Sync Handler below)

---

## Edit Handler

1. Read the specified workflow YAML
2. Show current structure (use Show Handler format)
3. Present edit options:
```
Edit options:
  1. Add step (insert at position)
  2. Remove step
  3. Reorder steps
  4. Edit step details
  5. Change description
  6. Done editing
```
4. Loop until user selects "Done editing"
5. Show final YAML preview, ask confirmation
6. Write updated YAML
7. Run Validate Handler
8. Update synced files

---

## Delete Handler

1. Read the specified workflow YAML
2. Show the workflow (use Show Handler format)
3. Require explicit confirmation:
```
⚠️  This will permanently delete workflow "{name}".
Type the workflow name to confirm:
```
4. Only delete if typed name matches exactly
5. Remove the YAML file
6. Update synced files

---

## Validate Handler

If name specified, validate that workflow only.
If no name, validate ALL workflows.

### Validation Process

1. Read `workflow-schema.md` from this skill's directory for rules
2. Glob available skills: `{plugin-root}/skills/*/SKILL.md` → extract names
3. Glob available agents: `{plugin-root}/agents/*.md` → extract names
4. For each workflow YAML, check rules WF001-WF011:

```
Validating: feature-dev.yaml
────────────────────────────
 ✓ WF001 name: "feature-dev" (valid kebab-case)
 ✓ WF002 description present
 ✓ WF003 steps: 7 steps found
 ✓ WF004 unique ids: design, planning, task-breakdown, implementation, review, documentation, completion
 ✓ WF005 valid types: skill(3), agent(2), agent-chain(1)
 ✓ WF006 skills exist: brainstorming ✓, writing-plans ✓, finishing-branch ✓
 ✓ WF007 agents exist: code-refactor-master ✓, code-architecture-reviewer ✓, documentation-architect ✓
 ✓ WF008 chains: [planner, plan-reviewer] ✓
 ✓ WF009 gate at start and end
 ✓ WF010 cross-cutting: tdd ✓, verification ✓
 ℹ WF011 output paths use template variables

Result: VALID (0 errors, 0 warnings, 1 info)
```

If errors found, show specific fix recommendations.

---

## Sync Handler (internal, called after create/edit/delete)

After any workflow change, update these files to stay in sync:

### 1. Workflow Orchestrator (`skills/workflow/SKILL.md`)

Update the "Available Workflows" section:
```markdown
## Available Workflows
- `feature-dev` — 기능 개발 (설계→플래닝→구현→리뷰→완료)
- `bugfix` — 버그 수정 (근본원인 조사→수정→리뷰→완료)
...
```

Read the current SKILL.md, find the `## Available Workflows` section, replace it with the current list generated from all YAML files.

### 2. Skill Rules (`skills/skill-rules.json`)

Update the `workflow` skill's keywords to include all workflow names:
```json
"keywords": ["workflow", "워크플로우", "feature-dev", "bugfix", "refactor", ...]
```

Read the current JSON, update the `skills.workflow.promptTriggers.keywords` array.

---

## Rules
- Always run validate after create or edit
- Never delete without explicit name confirmation
- Keep synced files updated after every change
- Use the schema reference for validation — do not hardcode rules
