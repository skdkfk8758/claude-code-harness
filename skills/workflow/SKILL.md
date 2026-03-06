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

이 스킬 디렉토리의 `*.yaml` 파일을 스캔하여 동적으로 목록을 구성한다.
각 YAML의 `name`과 `description` 필드를 읽어 사용자에게 표시:

```
사용 가능한 워크플로우:
  1. {name} — {description}
  2. {name} — {description}
  ...

번호 또는 이름을 입력하세요:
```

YAML 파일이 없거나 읽기 실패 시: "등록된 워크플로우가 없습니다."

## Input Resolution

입력을 다음 우선순위로 해석:

| 우선순위 | 입력 예시 | 동작 |
|----------|----------|------|
| 1. 정확한 YAML명 | `/workflow feature-dev` | 즉시 로드 |
| 2. YAML명 + resume | `/workflow feature-dev resume` | 상태 복원 후 재개 |
| 3. 자연어 (YAML명 없음) | `/workflow 사용자 인증 기능 개발해줘` | 라우터 분류 → 워크플로우 제안 |
| 4. 인자 없음 | `/workflow` | 목록 표시 + 선택 요청 |

### 자연어 라우팅 (우선순위 3)

인자가 이 스킬 디렉토리의 YAML 파일명(`*.yaml`에서 확장자 제거)과 매칭되지 않으면:

1. 입력 전체를 `workflow-router-rules.json`의 분류 로직에 전달
2. 최고 점수 워크플로우가 `minSignalCount` 이상이면 즉시 제안:
   ```
   입력 분석 결과 `feature-dev` 워크플로우가 적합합니다.
   이 워크플로우로 시작할까요? (y/n)
   ```
3. 사용자 확인 시 해당 워크플로우 로드 + 입력에서 워크플로우 이름 추출:
   - "사용자 인증 기능 개발해줘" → name: `user-auth`
   - "로그인 버그 고쳐줘" → name: `login-bug`
   - 이름 추출 불가 시 사용자에게 질문
4. 동점 또는 `minSignalCount` 미달 시 → 우선순위 4로 폴백 (목록 + 선택)

## Startup

1. Input Resolution에 따라 워크플로우를 결정
2. Read the workflow YAML file (e.g., `feature-dev.yaml` in this skill's directory)
3. Read current state from `.claude/workflow-state.json` in the project root.
   If `resume` is specified or state file exists, detect progress and offer to continue.

### Branch Validation

After loading the workflow (and before executing any step):

1. Check current branch: `git branch --show-current`
2. Read `.claude/project-config.json` for branch settings
3. If on `main` (or default branch):
   - Look up the branch prefix in this priority order:
     a. Workflow YAML's top-level `branch-prefix` field (e.g., `branch-prefix: "feature/"`)
     b. `git.branchPrefix.{workflow-name}` in project config (fallback)
     c. If neither exists, use the workflow name as prefix: `{workflow-name}/`
   - Generate branch name: `{prefix}{name}` (name은 워크플로우 주제를 kebab-case로 변환)
   - Announce and auto-create:
     ```
     [workflow] 브랜치를 생성합니다: git checkout -b {prefix}{name}
     ```
   - Execute `git checkout -b {prefix}{name}` to create and switch to the branch.
   - If branch already exists, switch to it: `git checkout {prefix}{name}`
   - Verify branch switch: `git branch --show-current`
4. If already on a non-main branch:
   - Check if current branch prefix matches the workflow's `branch-prefix` (e.g., `feature/` branch에서 feature-dev 워크플로우)
   - If **matches** → proceed on current branch.
   - If **doesn't match** → Ask:
     ```
     [workflow] 현재 브랜치: {current-branch}
     이 워크플로우의 브랜치 prefix는 "{prefix}"입니다.

     1. 현재 브랜치에서 새 브랜치 분기  → git checkout -b {prefix}{name}
     2. 현재 브랜치에서 그대로 진행
     ```
   - If user selects 1 → create and switch to new branch from current HEAD.
   - If user selects 2 → proceed on current branch.
5. If `git.requireBranch` is `false` in project config, skip this check entirely.

## Workflow Router

When this skill is invoked without arguments, or when integrated with a UserPromptSubmit hook:

1. Read `workflow-router-rules.json` from this skill's directory
2. Analyze the user's input against classification rules:
   - Check `excludePatterns` first — if matched, do NOT suggest a workflow
   - Check `config.skipKeywords` — if matched, do NOT suggest
   - Score each workflow: keyword match = 1pt, intentPattern match = 2pt, complexity/simplicity indicator = 1pt
   - If quick-fix `simplicityIndicators` match, subtract 2pt from other workflows
   - Suggest the highest-scoring workflow only if score >= `config.minSignalCount` (default: 2)
3. Suggestion format (soft):
   ```
   이 작업은 `{workflow}` 워크플로우가 적합해 보입니다.
   `/workflow {workflow}`로 시작하시겠어요? (무시하고 진행해도 됩니다)
   ```
4. If user ignores or declines, proceed without workflow — do NOT re-suggest in the same session.

## State Management

Track progress in the project's `.claude/workflow-state.json`:
```json
{
  "workflow": "feature-dev",
  "name": "my-feature",
  "currentStep": 2,
  "startedAt": "2026-03-06T10:00:00Z",
  "steps": {
    "design": {
      "status": "completed",
      "output": "docs/plans/2026-03-06-my-feature-design.md",
      "summary": "Redis 기반 캐싱 전략 채택. Memcached 대비 TTL 관리 우수성이 결정 근거",
      "decisions": ["캐시 무효화는 이벤트 기반으로 처리", "TTL 기본값 300초"],
      "issues": [],
      "userFeedback": "승인"
    },
    "planning": { "status": "in-progress" }
  }
}
```

### Session Continuity Fields

Each step records these fields on completion for context recovery:

| Field | Source | Description |
|-------|--------|-------------|
| `status` | orchestrator | completed, in-progress, blocked |
| `output` | YAML definition | 산출물 파일 경로 |
| `summary` | auto-extracted | 에이전트 결과에서 핵심 1-2줄 요약 |
| `decisions` | auto-extracted | 해당 스텝에서 내린 주요 결정사항 목록 |
| `issues` | auto-extracted | 발견된 이슈 또는 우려사항 |
| `userFeedback` | gate steps only | 사용자 승인 시 코멘트 |
| `retries` | retry-on-fail only | 재시도 횟수 |
| `finalVerdict` | review steps only | 최종 판정 (PASS, PASS_WITH_NOTES, NEEDS_CHANGES) |

### Auto-Extraction Rules

After each Auto step completes:
1. Parse the agent's output for key decisions (look for "decided", "chose", "selected", "채택", "결정")
2. Parse for issues (look for "concern", "risk", "warning", "우려", "위험", "주의")
3. Summarize in 1-2 sentences focusing on **what was decided and why**
4. Write to state file immediately
5. Perform knowledge indexing (see Knowledge Graph Management > Indexing)

After each Gate step:
1. Record the user's approval response as `userFeedback`
2. If user added comments beyond "승인", capture those too
3. Perform knowledge indexing if output file exists (see Knowledge Graph Management > Indexing)

### Resume with Context Recovery

When `resume` is specified or state file exists:

1. Read `workflow-state.json`
2. Display session context summary:
   ```
   ────────────────────────────────────
   [Resume] feature-dev: "my-feature"
   Started: 2026-03-06T10:00:00Z

   Completed steps:
     1. design ✓ — Redis 기반 캐싱 전략 채택
     2. planning ✓ — 3종 문서 생성 완료

   Resuming from: step 3/7 (task-breakdown)
   ────────────────────────────────────
   ```
3. Re-read the last completed step's output file to restore full context
4. Inject the `summary` and `decisions` from all completed steps into the next agent's dispatch prompt
5. If `.claude/knowledge-graph.json` exists, append knowledge summary to the resume display:
   ```
   Knowledge: 주요 개념 {N}개 ({concept names}), 관련 결정 {M}건
   ```
   knowledge-graph.json이 없으면 이 줄을 생략.

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
   - Append knowledge context (see Knowledge Graph Management > Context Injection)
3. Dispatch via **Agent tool** with `subagent_type: "general-purpose"`
4. If `auto: true`, proceed to next step. Otherwise, present results and ask user.
5. Update state.

### `type: agent-chain` (Chained Executors — automatic)
1. Execute agents sequentially in order
2. First agent: dispatch with full context
   - Include knowledge context in first agent dispatch only (see Knowledge Graph Management > Context Injection)
3. Subsequent agents: dispatch with previous agent's output as additional context
4. **NEEDS_REVISION handling**: If plan-reviewer returns NEEDS_REVISION:
   - Re-invoke the previous agent with the reviewer's findings
   - Maximum 2 retry cycles, then ask user
5. Update state after chain completes.

### `type: parallel` (Parallel Executors — automatic)
Execute multiple independent steps concurrently. Use when steps have no data dependency.

```yaml
- id: docs-and-review
  type: parallel
  steps:
    - agent: documentation-architect
      id: documentation
    - agent: code-architecture-reviewer
      id: review
  description: 문서화와 아키텍처 리뷰를 동시에 진행
  auto: true
```

1. Dispatch all sub-steps simultaneously via Agent tool
   - Include knowledge context in each sub-step dispatch independently (see Knowledge Graph Management > Context Injection)
2. Wait for ALL to complete before proceeding to next step
3. If any sub-step returns BLOCKED → mark the parallel step as BLOCKED, escalate to user
4. State records each sub-step's result individually:
   ```json
   {
     "docs-and-review": {
       "status": "completed",
       "sub-steps": {
         "documentation": { "status": "completed", "summary": "..." },
         "review": { "status": "completed", "summary": "..." }
       }
     }
   }
   ```
5. Cross-cutting rules apply to each sub-step independently
6. Review pipeline, if configured, runs after ALL sub-steps complete

### `type: conditional` (Conditional Branch — automatic)
Execute different steps based on a condition evaluated at runtime.

```yaml
- id: review-or-skip
  type: conditional
  condition:
    check: file-count          # built-in check type
    threshold: 5               # condition parameter
    operator: ">="             # >=, <=, ==, !=, >, <
  then:
    agent: code-architecture-reviewer
    id: full-review
  else:
    agent: code-quality-reviewer
    id: light-review
  description: 변경 파일 5개 이상이면 아키텍처 리뷰, 미만이면 코드 품질 리뷰
  auto: true
```

Built-in condition checks:
| Check | Description | Parameter |
|-------|-------------|-----------|
| `file-count` | `git diff --name-only` 결과의 파일 수 | `threshold` (number) |
| `line-count` | `git diff --stat` 총 변경 줄 수 | `threshold` (number) |
| `has-output` | 이전 step의 output 파일 존재 여부 | `step-id` (string) |
| `step-status` | 이전 step의 상태값 | `step-id`, `expected` (string) |
| `command` | 임의 셸 명령 exit code (0=true) | `run` (string) |

1. Evaluate the condition at the point of execution
2. Dispatch `then` or `else` branch accordingly
   - Include knowledge context in the dispatched branch (see Knowledge Graph Management > Context Injection)
3. State records which branch was taken:
   ```json
   {
     "review-or-skip": {
       "status": "completed",
       "branch": "then",
       "executed": "full-review"
     }
   }
   ```
4. If `else` is omitted, the step is simply skipped when condition is false

## Cross-Cutting Rules

When a step specifies `cross-cutting`:
1. Read each skill from `{plugin-root}/skills/{name}/SKILL.md`
2. Extract the core rules section
3. Append to the agent dispatch prompt with header:
   ```
   ## NON-NEGOTIABLE RULES (from {skill-name})
   {rules content}
   ```

### Enforcement Verification

Cross-cutting rules support two enforcement levels:

```yaml
cross-cutting:
  - name: tdd
    enforcement: enforce    # orchestrator verifies compliance
  - name: verification
    enforcement: suggest    # injected but not verified
```

**`suggest`** (default): Rules are injected into the agent prompt. Compliance is the agent's responsibility.

**`enforce`**: After the agent returns DONE, the orchestrator dynamically loads enforcement logic from the cross-cutting skill itself:

1. Read `{plugin-root}/skills/{skill-name}/SKILL.md`
2. Find the `## Enforcement Verification` section
3. Execute the checks described in that section:
   - **Pre-Step Setup**: If defined, execute before dispatching the agent (e.g., recording commit hash)
   - **Evidence Required**: Parse agent output according to the skill's criteria
   - **Pass Criteria**: Evaluate against the skill's pass conditions
   - **Failure Response**: Use the skill's re-dispatch message verbatim
4. Max 2 re-dispatches per enforce rule, then escalate to user
5. If a cross-cutting skill has `enforcement: enforce` but no `## Enforcement Verification` section, treat as `suggest` and log a warning:
   ```
   [workflow] {skill-name}에 enforcement: enforce가 설정되었으나
   Enforcement Verification 섹션이 없습니다. suggest로 처리합니다.
   ```

This allows new cross-cutting skills to define their own enforcement logic without modifying the orchestrator.

Record enforcement results in state:
```json
{
  "enforcement": {
    "tdd": "passed",
    "verification": "passed_after_retry"
  }
}
```

## Review Pipeline

Implementation steps can define a `review-pipeline` to specify which reviewers run and in what order. This replaces the previous hardcoded 2-stage review.

### YAML Configuration

```yaml
- id: implementation
  type: agent
  agent: code-refactor-master
  review-pipeline:
    batch-size: 3                    # tasks per batch (default: 3)
    reviewers:
      - agent: spec-reviewer         # executed first
      - agent: code-quality-reviewer # executed if previous passes
    fix-agent: code-refactor-master  # agent to dispatch for fixes
    max-retries-per-reviewer: 1      # per reviewer per batch
```

### Execution

1. After each batch of `batch-size` tasks completes:
2. Execute reviewers **sequentially in order** — each reviewer runs only if the previous one PASS
3. If any reviewer returns FAIL:
   a. Extract failing items from review output
   b. Re-dispatch `fix-agent` with fix targets (scope: failing items only)
   c. Re-run the failing reviewer
   d. Max `max-retries-per-reviewer` retries per reviewer per batch
   e. If still FAIL after retry → pause, report to user
4. Only continue to next batch when all reviewers PASS

### Default Behavior

If a step has no `review-pipeline`, **no automatic review is performed**. The step simply executes and completes. This is intentional — review should be explicitly configured per step.

## Retry-on-Fail Handling

When a step has `retry-on-fail` configured in the YAML:

1. Execute the step normally
2. Parse the agent's output for the `trigger-status` value (e.g., `NEEDS_CHANGES`)
3. If triggered:
   a. Extract blocking issues from the review report (only blocking items, not advisory)
   b. Select the appropriate fix-agent:
      - **String syntax**: `fix-agent: code-refactor-master` — always use this agent
      - **Map syntax**: Route to different agents based on trigger category:
        ```yaml
        retry-on-fail:
          fix-agents:
            SECURITY_FAIL: security-fixer
            PERFORMANCE_FAIL: performance-optimizer
            default: code-refactor-master
          max-retries: 2
          trigger-status: "NEEDS_CHANGES"
        ```
        Match the review output's category tag against map keys. If no match, use `default`.
   c. Dispatch the selected fix-agent with:
      - Original task context (previous step outputs)
      - Blocking issues as fix targets
      - Instruction: "Fix ONLY the blocking issues listed below. Do not refactor or change anything else."
   d. Re-dispatch the review agent to re-verify
   e. Repeat up to `max-retries` times
4. If still failing after max-retries → escalate to user:
   ```
   [workflow] Review found blocking issues after {N} fix attempts.
   Manual intervention needed. See: {review-report-path}
   ```
5. Update state with retry info:
   ```json
   { "status": "completed", "retries": 1, "finalVerdict": "PASS_WITH_NOTES" }
   ```

Note: Steps without `retry-on-fail` behave exactly as before — no retry, escalate on failure.

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
- Skip review-pipeline because "the change is small"

When an agent returns status:
- **DONE** → verify output exists, run review-pipeline if configured, proceed
- **DONE_WITH_CONCERNS** → present concerns to user, ask whether to proceed
- **NEEDS_CONTEXT** → provide requested context and re-dispatch
- **BLOCKED** → escalate to user immediately, do not retry automatically

## Knowledge Graph Management

이 섹션은 워크플로우 step 완료 시 산출물에서 도메인 지식을 추출하고,
에이전트 dispatch 시 관련 지식을 자동 주입하는 기능을 정의한다.
knowledge-graph.json이 없으면 이 섹션의 모든 로직을 건너뛴다 (하위 호환).

### Schema

`.claude/knowledge-graph.json` 구조 (빈 그래프 초기화 시):

    {
      "version": "1.0",
      "lastUpdated": "ISO-8601",
      "projectId": "프로젝트명 (디렉터리명 또는 package.json name)",
      "concepts": [],
      "decisions": [],
      "artifacts": [],
      "changelog": []
    }

#### Concept types

| Type | 예시 |
|------|------|
| `entity` | User, Order, Product |
| `service` | PaymentGateway, AuthService |
| `pattern` | EventBus, Repository, Saga |
| `module` | src/order/, src/auth/ |
| `infrastructure` | Redis, PostgreSQL, S3 |

#### Artifact types

| Type | 설명 |
|------|------|
| `design` | 설계 문서 (brainstorming 산출물) |
| `plan` | 전략 플랜 (planner 산출물) |
| `context` | 컨텍스트 & 결정 문서 |
| `tasks` | 태스크 분해 목록 |
| `review` | 아키텍처 리뷰 리포트 |

#### Relation types

| Type | 의미 |
|------|------|
| `has-one` | 1:1 관계 |
| `has-many` | 1:N 관계 |
| `belongs-to` | 소유 관계 |
| `uses` | 의존/사용 |
| `extends` | 확장/상속 |
| `derived-from` | 산출물 파생 |

### Indexing (step 완료 후)

각 step 완료 후 output 파일이 존재하면:

1. `.claude/knowledge-graph.json` 읽기 (없으면 빈 그래프 초기화)
2. output 마크다운을 읽고, 아래 추출 지시에 따라 concepts/decisions/changelog 추출
3. 기존 concept과 name 매칭 — 있으면 병합(files, relations 합집합), 없으면 신규 생성
4. artifact 노드 추가 (derivedFrom은 이전 step의 artifact id)
5. knowledge-graph.json 저장
6. 인덱싱 실패 시 (파일 I/O 에러 등) 경고만 출력하고 워크플로우는 계속 진행:

    [workflow] Knowledge indexing failed: {error}. Continuing without indexing.

#### Step type별 Indexing 적용

| Step Type | Indexing 시점 |
|-----------|--------------|
| `type: skill` (Gate) | 사용자 승인 후, output 파일이 존재하면 인덱싱 |
| `type: agent` | 에이전트 완료 후 output 인덱싱 |
| `type: agent-chain` | 체인 전체 완료 후 최종 output 인덱싱 |
| `type: parallel` | 모든 sub-step 완료 후 각각의 output 개별 인덱싱 |
| `type: conditional` | 실행된 branch의 output 인덱싱 |

#### 추출 지시

step output 마크다운을 읽은 후, 다음을 추출:

1. **concepts** — 도메인 엔티티, 서비스, 패턴, 모듈, 인프라
   - name, type, description (1줄), files (언급된 파일 경로), relations
2. **decisions** — 설계/구현 결정과 근거
   - content, rationale, 관련 concepts
3. **changelog** — 이 step에서 변경/영향받은 개념과 파일
   - conceptsAffected, filesChanged, summary (1줄)

추출 규칙:
- 기존 concept은 name으로 매칭하여 병합 (files, relations 합집합)
- 새 concept만 신규 생성
- 불확실한 추출은 하지 않음 — 명시적으로 언급된 것만 추출

산출물 유형별 추출 초점:

| 산출물 유형 | 주요 추출 대상 | 파싱 힌트 |
|------------|--------------|----------|
| design.md | concepts, decisions | "## Architecture", "## Components", "## Decision Summary" |
| plan.md | concepts 보강 (파일 매핑) | "## Architecture Impact", "## Task Overview" |
| context.md | decisions | "## Key Decisions", "## Technical Context" |
| tasks.md | concept-file 매핑 | 각 Task의 "Files" 목록 |
| review.md | changelog, 이슈 기록 | "## Blocking Issues", "## Verification Drift" |

### Context Injection (agent dispatch 시)

에이전트 dispatch prompt 구성 시, knowledge-graph.json이 존재하면:

1. knowledge-graph.json 읽기
2. 3단계 관련성 매칭으로 concepts 필터:
   - **P1 (Artifact)**: 현재 step의 input 파일 경로 또는 이전 step의 output 파일 경로 →
     artifacts 배열에서 path 매칭 → 해당 artifact의 concepts.
     YAML에 input 필드가 없는 step은 이전 step의 output만 사용.
   - **P2 (Workflow 내부)**: 현재 workflow의 이전 step에서 생성된 decisions, concepts
     (workflow-state.json의 decisions 필드와 교차 참조)
   - **P3 (Git diff)**: `git diff --name-only main..HEAD`의 변경 파일과
     concept.files의 교집합 (implementation, review step에서 주로 활용)
3. 관련 concepts의 최근 decisions (최대 5개) 수집
4. 관련 concepts의 changelog (최대 3개) 수집
5. 50줄 이내로 포맷하여 dispatch prompt에 추가 (초과 시 P1 > P2 > P3 순 절삭):

    ## Project Knowledge Context (auto-injected)

    ### Domain Concepts Related to This Task
    - {concept.name}: {concept.description}, {concept.files 요약}

    ### Relevant Past Decisions
    - [{decision.date}] "{decision.content}" ({decision.workflow})

    ### Change History for Affected Concepts
    - {concept.name}: {modifiedCount}회 수정 (최근: {lastModified})

6. 관련 concept이 없으면 이 섹션을 생략 (빈 컨텍스트 주입 안 함)

knowledge-graph.json이 없으면 context injection을 건너뛴다 (하위 호환).

#### Step type별 Context Injection 적용

| Step Type | Context Injection |
|-----------|------------------|
| `type: skill` (Gate) | 미적용 — 사용자가 직접 스킬 호출하므로 오케스트레이터 개입 불가 |
| `type: agent` | 적용 — dispatch prompt에 knowledge context 추가 |
| `type: agent-chain` | 첫 번째 에이전트 dispatch에만 주입 (후속 에이전트는 이전 output이 컨텍스트) |
| `type: parallel` | 각 sub-step dispatch에 독립적으로 주입 |
| `type: conditional` | 선택된 branch의 에이전트 dispatch에 주입 |

## Error Handling
- Agent dispatch failure → report error, ask user how to proceed
- Never skip a gate step — gates exist to enforce user decisions
- Missing output file after step → warn, ask to retry or skip
- NEEDS_REVISION from reviewer → re-invoke previous agent (max 2 retries)
- If state file is corrupted → ask user to start fresh or specify step to resume from
