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

## Input Resolution

입력을 다음 우선순위로 해석:

1. **정확한 서브커맨드** — `list`, `show feature-dev` → 즉시 실행
2. **자연어** — 아래 NL 맵으로 서브커맨드 매칭 → 대상 이름 추출 후 실행
3. **매칭 불가** — 도움말 표시

### NL → Command Map

| 자연어 키워드 | 매핑 커맨드 |
|--------------|------------|
| 목록, 뭐 있어, 어떤 워크플로우, list all | `list` |
| 상세, 구조, 보여줘 + 이름, show, detail | `show <name>` |
| 만들어, 추가, 새로, new, create | `create <name>` |
| 수정, 변경, 고쳐, edit, modify | `edit <name>` |
| 삭제, 제거, 없애, delete, remove | `delete <name>` |
| 검증, 확인, 유효, validate, check | `validate [name]` |
| 영향, 바꾸면, impact, 뭐가 깨져 | `impact <name>` |

이름 추출: 자연어에서 기존 워크플로우명과 매칭되는 단어를 `<name>`으로 사용. 매칭 불가 시 사용자에게 질문.

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
| `impact <name>` | Impact Handler — what breaks if this workflow changes |
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

### Interview

#### Context (auto-scan before asking)
1. Glob existing workflows: `{plugin-root}/skills/workflow/*.yaml` — extract names + step counts
2. Glob available skills and agents — build component list
3. Present: "현재 워크플로우 {N}개: {list}. 사용 가능한 컴포넌트 {M}개."

#### Questions

**Q1. Goal**
- type: open
- dependency: none
```
이 워크플로우의 목적은 무엇인가요? 어떤 작업을 처음부터 끝까지 처리하나요?
```

**Q2. Scope**
- type: open
- dependency: Q1
```
기존 워크플로우와 어떻게 다른가요? 적용 대상이나 범위를 알려주세요:
```
기존 워크플로우 중 유사한 것이 있으면 자동 표시합니다.

**Q3. Steps**
- type: open
- dependency: Q1, Q2
- 사용 가능한 컴포넌트를 게이트/에이전트로 구분하여 표시:
```
사용 가능한 게이트 (사용자 승인 필요):
  {auto-generated list from scan}

사용 가능한 에이전트 (자동 실행):
  {auto-generated list from scan}

어떤 단계들이 필요한가요? (순서대로, 예: brainstorming, planner+plan-reviewer, code-refactor-master)
```

**Q4. Per Step Configuration** (Q3의 각 step에 대해 순차적으로)
- type: select per step
- dependency: Q3
- 각 step마다 개별적으로 질문 (한 번에 묶지 않음):
```
Step {N}: {component}
  - Cross-cutting 규칙 주입: [none / tdd / verification / tdd+verification]
  - Optional 여부: [yes / no]
  (타입과 auto는 자동 감지: skill=gate, agent=auto)
```

**Q5. Branch & Router**
- type: multi-input
- dependency: Q1, Q2
```
브랜치 접두사를 지정해주세요 (예: "feature/", "fix/", "refactor/"):

이 워크플로우를 자동 제안할 때 사용할 키워드를 알려주세요 (쉼표 구분):
  예: "보안 점검, security audit, 취약점, vulnerability"
```
키워드 입력 기반으로 `intentPatterns`와 `complexityIndicators`를 자동 생성합니다.
사용자가 키워드를 제공하지 않으면 Q1, Q2 답변에서 자동 추출합니다.

**Q6. Scenario Test**
- type: open
- dependency: Q3, Q4
```
이 워크플로우로 처리할 구체적 작업 예시를 1개 알려주세요.
각 단계에서 어떤 산출물이 나오는지 함께 설명해주시면 됩니다:
```

#### Validation
- 첫 번째 또는 마지막 step이 gate인지 확인 (아니면 경고)
- 참조된 모든 skill/agent가 실제 존재하는지 확인
- Q6 시나리오가 단계별로 자연스럽게 흐르는지 확인

**Q7. Confirmation**
YAML 프리뷰를 생성하여 최종 확인을 요청합니다.

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

## Impact Handler

Answers: **"이 워크플로우를 변경하면 어디가 영향받는가?"**

### Process

1. Read the specified workflow YAML
2. Extract all referenced components:
   - Skills used in gate steps
   - Agents used in executor steps
   - Agents in chains
   - Cross-cutting skills
   - Fix-agents in retry-on-fail
3. For each component, check if it is shared with other workflows:
   - Grep all other workflow YAMLs for the same component name
4. Identify shared vs exclusive components:
   - **Shared**: 다른 워크플로우에서도 사용 → 이 워크플로우 변경이 공유 컴포넌트 수정을 유발하면 다른 워크플로우에도 영향
   - **Exclusive**: 이 워크플로우에서만 사용 → 자유롭게 변경 가능

### Output

```
Impact Analysis: feature-dev
════════════════════════════

Components used (7):
  Skills:  brainstorming, writing-plans, finishing-branch
  Agents:  planner, plan-reviewer, code-refactor-master,
           code-architecture-reviewer, documentation-architect
  X-cut:   tdd, verification, git-convention, systematic-debugging

Shared with other workflows:
  ┌─────────────────────────┬──────────────────────────┐
  │ Component               │ Also used by             │
  ├─────────────────────────┼──────────────────────────┤
  │ finishing-branch        │ bugfix, refactor         │
  │ code-refactor-master    │ bugfix, refactor         │
  │ code-architecture-rev.  │ bugfix, refactor         │
  │ tdd (enforce)           │ bugfix, refactor         │
  │ verification (enforce)  │ bugfix, refactor         │
  │ git-convention (enforce)│ bugfix, refactor         │
  └─────────────────────────┴──────────────────────────┘

Exclusive to this workflow:
  - brainstorming (gate)
  - writing-plans (gate)
  - planner (chain)
  - plan-reviewer (chain)
  - documentation-architect (optional)
  - systematic-debugging (suggest)

Safe to modify: exclusive components — 변경해도 다른 워크플로우에 영향 없음
Caution needed: shared components — 수정 시 bugfix, refactor 워크플로우도 확인 필요
```

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

### 3. Router Rules (`skills/workflow/workflow-router-rules.json`)

When a workflow is created, add its routing entry:
```json
"{name}": {
  "description": "{description}",
  "signals": {
    "keywords": [...from Q5 keywords...],
    "intentPatterns": [...auto-generated from keywords...],
    "complexityIndicators": [...auto-generated if applicable...]
  }
}
```

When a workflow is deleted, remove its entry from the `workflows` object.

When edited, update description and signals if workflow scope changed.

### 4. Branch Prefix in project-config.json

Sync `git.branchPrefix` from workflow YAML `branch-prefix` fields:
1. Read all workflow YAMLs
2. For each with `branch-prefix` field, ensure `git.branchPrefix.{name}` matches
3. Remove entries for deleted workflows
4. This is a bidirectional convenience sync — YAML is the source of truth

---

## Rules
- Always run validate after create or edit
- Never delete without explicit name confirmation
- Keep synced files updated after every change
- Use the schema reference for validation — do not hardcode rules
