---
name: plan-viewer
description: Use when checking project progress, remaining tasks, or deciding what to do next. Aggregates workflow state, plan documents, and task lists into a unified dashboard.
user-invocable: true
allowed-tools: Read, Glob, Grep, AskUserQuestion, Bash
argument-hint: "[<query>]"
---

# Plan Viewer

프로젝트의 플랜, 태스크, 워크플로우 진행 상황을 통합 조회하고 다음 작업을 제안합니다.

## Path Discovery

Plugin root:
!`echo ${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname ${CLAUDE_SKILL_DIR}))}`

Project root:
!`echo ${CLAUDE_PROJECT_ROOT:-.}`

## Data Sources

| Source | Path | Content |
|--------|------|---------|
| Workflow State | `.claude/workflow-state.json` | step별 status, summary, decisions |
| Task Documents | `docs/plans/*-tasks.md` | 체크박스 기반 태스크 목록 |
| Plan Documents | `docs/plans/*-plan.md` | 전략 + 태스크 개요 |
| Design Documents | `docs/plans/*-design.md` | 설계 결정사항 |

## Input Classification

인자를 자유 형식으로 받아 의도를 분류합니다:

### Classification Rules

1. **인자 없음** → `mode: dashboard`
2. **step-id 매칭** (workflow-state.json의 step id와 일치) → `mode: detail`, `target: {step-id}`
3. **상태 키워드 매칭** → `mode: status-filter`
   - 완료/done/completed → `filter: completed`
   - 남은/remaining/todo → `filter: pending`
   - 진행중/current/in-progress → `filter: in-progress`
4. **다음/next/할 일** → `mode: next-action`
5. **그 외** → `mode: keyword-filter`, `keyword: {추출된 핵심어}`
   - 입력에서 조사/어미 제거 후 핵심 키워드 추출
   - 예: "로그인 관련 작업만 보여줘" → keyword: "로그인"

## Process

### 1. Data Collection

1. Read `.claude/workflow-state.json` — 없으면 "활성 워크플로우 없음" 표시
2. Glob `docs/plans/*-tasks.md` — 가장 최근 파일 선택 (날짜 기준)
3. Glob `docs/plans/*-plan.md`, `docs/plans/*-design.md` — 경로만 수집

### 2. Mode Execution

#### `mode: dashboard` (기본)

워크플로우 + 태스크 통합 뷰:

```
📋 Project Status: {name} ({workflow})
════════════════════════════════════════════

Workflow Progress: {completed}/{total} steps
──────────────────────────────────────────
  1. {step-id}  ✓  {summary}
  2. {step-id}  ✓  {summary}
  3. {step-id}  ●  진행중 ({completed-tasks}/{total-tasks} tasks)
  4. {step-id}  ○  대기
  ...

Task Details (step {N}: {current-step-id})
──────────────────────────────────────────
  ✓ 1. {completed task}
  ✓ 2. {completed task}
  ● 3. {current task}       ← 현재
  ○ 4. {pending task}
  ...

Plan Documents
──────────────────────────────────────────
  • design:  {path}
  • plan:    {path}
  • tasks:   {path}

Next Action
──────────────────────────────────────────
  {next-action-suggestion}
```

**Step status 기호:**
- `✓` — status: completed
- `●` — status: in-progress
- `○` — 아직 시작 안 됨
- `✗` — status: blocked

**Task status 파싱:**
- `- [x]` → completed (✓)
- `- [ ]` → pending (○)
- 현재 진행중 태스크 = 첫 번째 pending 태스크 (●)

#### `mode: detail`

특정 step의 상세 정보:

1. workflow-state.json에서 해당 step의 전체 데이터 표시
   - status, summary, decisions, issues, userFeedback
2. 해당 step의 output 파일이 있으면 내용 요약
3. 해당 step이 implementation이면 tasks.md에서 해당 범위의 태스크 상세 표시

#### `mode: status-filter`

지정된 상태의 항목만 표시:

- `completed`: 완료된 step + 완료된 task만
- `pending`: 대기 중인 step + 미완료 task만
- `in-progress`: 현재 진행중인 step + 현재 태스크만

#### `mode: next-action`

다음 할 일을 구체적으로 제안:

1. workflow-state.json에서 현재 step 확인
2. 현재 step이 gate이면:
   ```
   다음 작업: /{skill-name} 실행
   설명: {step description}
   ```
3. 현재 step이 agent/auto이면:
   ```
   다음 작업: /workflow resume
   자동 실행 step입니다. 워크플로우를 재개하면 자동으로 진행됩니다.
   ```
4. 워크플로우가 없으면:
   ```
   활성 워크플로우가 없습니다.
   /workflow 로 새 워크플로우를 시작하세요.
   ```

#### `mode: keyword-filter`

키워드로 태스크/플랜 필터링:

1. tasks.md에서 키워드가 포함된 태스크 추출
2. plan.md에서 키워드가 포함된 섹션 제목 추출
3. design.md에서 키워드가 포함된 결정사항 추출
4. 매칭 결과를 소스별로 그룹화하여 표시:
   ```
   🔍 Filter: "{keyword}"
   ════════════════════════════════════════════

   Tasks (3 matches)
   ──────────────────────────────────────────
     ✓ 1. {keyword} 관련 태스크 A
     ○ 4. {keyword} 관련 태스크 B
     ○ 7. {keyword} 관련 태스크 C

   Plan Sections (1 match)
   ──────────────────────────────────────────
     • "3.2 {keyword} 처리 전략" in {plan-path}

   Design Decisions (1 match)
   ──────────────────────────────────────────
     • "{keyword}는 이벤트 기반으로 처리" in {design-path}
   ```
5. 매칭 없으면: `"{keyword}"와 일치하는 항목이 없습니다.`

### 3. Fallback (워크플로우 없을 때)

workflow-state.json이 없는 경우에도 동작:

1. `docs/plans/` 아래 문서가 있으면 → 문서 목록 + tasks.md 파싱하여 표시
2. 문서도 없으면 → "플랜 문서가 없습니다. /workflow 로 시작하세요."

## Output

항상 텍스트 기반 대시보드를 출력합니다.
출력 후 추가 질문이 없으면 종료합니다 (gate 승인 불필요).

## Rules

- 파일을 수정하지 않음 — 읽기 전용 스킬
- tasks.md 파싱 시 마크다운 체크박스(`- [x]`, `- [ ]`)만 태스크로 인식
- workflow-state.json이 없어도 에러 없이 fallback 동작
- 키워드 필터링은 대소문자 무시, 부분 매칭
- 플랜 문서 본문을 전체 출력하지 않음 — 경로와 매칭된 라인만 표시
