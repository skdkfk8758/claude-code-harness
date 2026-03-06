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

## Input Resolution

입력을 다음 우선순위로 해석:

1. **정확한 서브커맨드** — `list`, `show brainstorming` → 즉시 실행
2. **자연어** — 아래 NL 맵으로 서브커맨드 매칭 → 대상 이름 추출 후 실행
3. **매칭 불가** — 도움말 표시

### NL → Command Map

| 자연어 키워드 | 매핑 커맨드 |
|--------------|------------|
| 목록, 뭐 있어, 보여줘(대상 없이), list all | `list` |
| 상세, 정보, 보여줘 + 이름, show, detail | `show <name>` |
| 스킬 만들어, 스킬 추가, new skill, create skill | `create-skill <name>` |
| 에이전트 만들어, 에이전트 추가, new agent | `create-agent <name>` |
| 수정, 변경, 고쳐, edit, modify, update | `edit <name>` |
| 삭제, 제거, 없애, delete, remove | `delete <name>` |
| 검증, 확인, 유효, validate, check | `validate [name]` |
| 의존성, 참조, 누가 쓰는, deps, dependency | `deps` |
| 영향, 바꾸면, impact, 뭐가 깨져 | `impact <name>` |

이름 추출: 자연어에서 기존 스킬/에이전트명과 매칭되는 단어를 `<name>`으로 사용. 매칭 불가 시 사용자에게 질문.

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
| `impact <name>` | Impact analysis — what breaks if this changes |
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

#### Context (auto-scan before asking)
1. Glob existing skills: `{plugin-root}/skills/*/SKILL.md` — extract names + descriptions
2. Read `skill-schema.md` for current types and rules
3. Present: "현재 스킬 {N}개가 있습니다: {list with descriptions}"

#### Questions

**Q1. Purpose**
- type: open
- dependency: none
```
이 스킬이 무엇을 하나요? 한 문장으로 설명해주세요:
(CCH 컨벤션: "Use when"으로 시작하면 좋지만 필수 아님)
```

**Q2. Use Case**
- type: open
- dependency: Q1
```
이 스킬이 가장 자주 쓰이는 구체적 상황 1-2개를 알려주세요:
```

**Q3. Overlap Check**
- type: confirm
- dependency: Q1, Q2
- 기존 스킬 중 description 유사도가 높은 것이 있으면 자동 표시:
```
기존 스킬과 겹치는 부분이 있습니다:
  - {similar-skill}: {description}
이 스킬과 다른 점이 무엇인가요? (겹치지 않으면 "없음")
```
겹치는 스킬이 없으면 이 질문을 건너뜁니다.

**Q4. Type**
- type: select
- dependency: none
```
스킬 타입을 선택해주세요:
  1. Gate — 사용자 승인 필요 (예: brainstorming, finishing-branch)
  2. Cross-cutting — 에이전트에 규칙 주입 (예: tdd, verification)
  3. Manager — CRUD 작업 (예: workflow-manager)
```

**Q5. Invocation & Execution**
- type: multi-select
- dependency: Q1, Q4
- Q4 타입 기반 기본값 자동 적용:
  - Gate/Manager → `user-invocable: true`, `disable-model-invocation: true`
  - Cross-cutting → `user-invocable: false`, `disable-model-invocation: false`
  - Orchestrator → `user-invocable: true`, `disable-model-invocation: true`
```
호출 방식을 확인해주세요 (기본값 적용됨):
  1. 사용자가 /명령으로 직접 호출 가능? (user-invocable) [{default}]
  2. Claude가 자동으로 트리거 가능? (disable-model-invocation=false) [{default}]
  3. 서브에이전트에서 격리 실행? (context: fork) [아니오]
     → "예"면: 에이전트 타입? (Explore / Plan / general-purpose / 커스텀)
```

**Q6. Process**
- type: open
- dependency: Q1, Q4
```
이 스킬의 주요 단계를 설명해주세요 (구조화는 제가 합니다):
```

**Q7. Failure Scenarios**
- type: open
- dependency: Q6
```
이 스킬이 실패하거나 적합하지 않은 상황은 어떤 경우인가요?
```

**Q8. Tools & Arguments**
- type: multi-select + open
- dependency: Q4, Q6
- 타입별 기본값을 자동 선택하고 표시:
```
Q4에서 선택한 타입 기준 기본 도구: {defaults}
추가하거나 제거할 도구가 있나요?

인자를 받나요? 있다면 사용 패턴을 알려주세요:
  예: "<topic>", "<file-path>", "list | show <name>"
```

#### Validation
- Q1 답변이 description으로 적합한지 확인 (무엇을 하는지 + 언제 쓰는지 포함)
- Q3에서 겹치는 스킬이 있으면 차별점이 명확한지 확인
- Q5에서 `context: fork`인데 `agent`가 없으면 경고
- Q5에서 `disable-model-invocation: true`이고 `user-invocable: false`면 도달 불가 경고
- Q6 프로세스가 3단계 이상인지 확인 (너무 짧으면 기존 스킬에 통합 제안)

### Generation

1. Generate SKILL.md with:
   - Frontmatter: name (Q1), description (Q1+Q2), type comment, user-invocable, disable-model-invocation, context, agent (Q5), allowed-tools, argument-hint (Q8)
   - `!echo ${CLAUDE_SKILL_DIR}` path discovery (if needed)
   - **Input Resolution section** (Q8에서 인자가 있는 경우 자동 생성):
     - 서브커맨드형 (`list | show <name>` 등) → NL→Command Map 테이블 포함
     - 모드형 (`extract | record | check` 등) → NL→Mode Map 테이블 포함
     - 자유 텍스트형 (`<topic>` 등) → "입력 전체를 컨텍스트로 사용" 명시
     - 인자 없는 스킬 → Input Resolution 섹션 생략
   - Process from Q6
   - Rules from Q7
   - Output section
2. Show preview, ask confirmation
3. Write to `{plugin-root}/skills/{name}/SKILL.md`
4. Run Validate Handler (includes SK012-SK016 checks)
5. Update synced files

---

## Create-Agent Handler

### Interview

#### Context (auto-scan before asking)
1. Glob existing agents: `{plugin-root}/agents/*.md` — extract names + descriptions
2. Check which workflows currently lack agents or have gaps
3. Present: "현재 에이전트 {N}개가 있습니다: {list with roles}"

#### Questions

**Q1. Role**
- type: open
- dependency: none
```
이 에이전트의 역할을 한 문장으로 설명해주세요:
```

**Q2. Use Context**
- type: open
- dependency: Q1
```
이 에이전트가 어떤 워크플로우/상황에서 호출되나요? 입력으로 무엇을 받나요?
```

**Q3. Process**
- type: open
- dependency: Q2
```
에이전트의 단계별 프로세스를 설명해주세요:
```

**Q4. Output & Success Criteria**
- type: open
- dependency: Q3
```
에이전트의 출력 형식은? 성공/실패를 어떻게 판단하나요?
```

**Q5. Model**
- type: select
- dependency: Q3
- 프로세스 복잡도 기반으로 자동 추천 (답변 후):
```
어떤 모델을 사용할까요?
  1. inherit — 부모 모델 따라감 (기본)
  2. opus — 복잡한 추론, 계획, 구현
  3. sonnet — 빠른 패턴 매칭, 리뷰
  4. haiku — 단순 분류, 가벼운 작업
```

#### Validation
- Q1 역할이 기존 에이전트와 중복되는지 자동 확인
- Q4 출력 형식이 구체적인지 확인 (단순 "마크다운" 등은 재질문)

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
4. Build dependency map with **both directions** (uses → / referenced by ←):

```
Dependency Map
══════════════

workflow (skill)
  ├─→ uses agents: planner, plan-reviewer, code-refactor-master, ...
  ├─→ uses skills: brainstorming, writing-plans, finishing-branch
  ├─→ reads: feature-dev.yaml, bugfix.yaml, refactor.yaml
  └─← referenced by: (root orchestrator, no upstream)

brainstorming (skill)
  ├─→ dispatches: spec-document-reviewer (subagent prompt)
  └─← referenced by: feature-dev.yaml, refactor.yaml

tdd (skill, cross-cutting)
  └─← referenced by:
       feature-dev.yaml → implementation (enforce)
       bugfix.yaml → implementation (enforce)
       refactor.yaml → implementation (enforce)

code-refactor-master (agent)
  ├─→ uses agents: spec-reviewer, code-quality-reviewer (2-stage review)
  └─← referenced by:
       feature-dev.yaml → implementation (executor)
       feature-dev.yaml → review (retry-on-fail fix-agent)
       bugfix.yaml → implementation (executor)
       refactor.yaml → implementation (executor)

Orphans (not referenced by any workflow):
  - web-research-specialist
  - implementer-prompt-template

Circular dependencies: none found
```

---

## Impact Handler (Impact Analysis)

Answers: **"이 컴포넌트를 변경하면 어디가 영향받는가?"**

### Process

1. Identify the target component (skill or agent) by name
2. Build reverse dependency graph:
   a. Grep all workflow YAMLs for references to this component:
      - `skill: {name}` — gate step에서 직접 사용
      - `agent: {name}` — executor step에서 직접 사용
      - `agents:` array 내 `- {name}` — agent-chain에서 사용
      - `cross-cutting:` 내 `- name: {name}` — 규칙 주입으로 사용
      - `fix-agent: {name}` — retry-on-fail에서 사용
   b. Grep all skills for references:
      - `/{name}` invocations
      - `{name}` mentions in dispatch/reference context
   c. Grep all agents for references:
      - `{name}` mentions in process/rules sections
3. Classify each reference by binding strength:
   - **enforce** — 계약적 의존 (cross-cutting enforce, executor). 변경 시 동작이 깨질 수 있음
   - **suggest** — 권고적 의존 (cross-cutting suggest). 변경해도 즉시 깨지지 않음
   - **indirect** — 문서적 참조. 변경해도 동작에 영향 없음
4. Determine change risk level:
   - HIGH: enforce 참조 3개 이상, 또는 2개 이상의 워크플로우에 enforce 연결
   - MEDIUM: enforce 참조 1-2개
   - LOW: suggest/indirect만 존재

### Output

```
Impact Analysis: tdd
════════════════════

Direct dependents (enforce):
  - feature-dev.yaml → step: implementation (cross-cutting, enforce)
  - bugfix.yaml → step: implementation (cross-cutting, enforce)
  - refactor.yaml → step: implementation (cross-cutting, enforce)

Indirect dependents (suggest):
  (none)

Document references:
  - skills/workflow/SKILL.md → Cross-Cutting Rules section

Change risk: HIGH (3 workflows with enforce binding)

Checklist:
  [ ] feature-dev implementation step 동작 확인
  [ ] bugfix implementation step 동작 확인
  [ ] refactor implementation step 동작 확인
  [ ] workflow SKILL.md 내 tdd 관련 설명 업데이트 필요 여부 확인
```

### Agent Impact (에이전트 대상)

에이전트의 경우 추가 분석:

```
Impact Analysis: code-refactor-master
═════════════════════════════════════

As executor:
  - feature-dev.yaml → step: implementation
  - bugfix.yaml → step: implementation
  - refactor.yaml → step: implementation

As fix-agent (retry-on-fail):
  - feature-dev.yaml → step: review (fix-agent)
  - bugfix.yaml → step: review (fix-agent)

As chain member:
  (none)

Cross-cutting rules injected into this agent:
  - tdd (enforce) — RED-GREEN-REFACTOR cycle required
  - verification (enforce) — test execution evidence required
  - git-convention (enforce) — commit message format required
  - systematic-debugging (suggest) — root cause investigation

Change risk: HIGH (5 workflow steps, 3 enforce rules)

Checklist:
  [ ] feature-dev implementation/review steps 동작 확인
  [ ] bugfix implementation/review steps 동작 확인
  [ ] refactor implementation step 동작 확인
  [ ] tdd/verification/git-convention 규칙과의 호환성 확인
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
