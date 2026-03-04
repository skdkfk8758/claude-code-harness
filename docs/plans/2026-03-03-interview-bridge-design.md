# Interview-to-Execution Bridge 설계

> Created: 2026-03-03
> Status: proposed
> Work Item: w-interview-bridge

## 배경

인터뷰(계획) 단계 완료 후 에이전트가 실행 단계로 자동 전환되지 않는 구조적 문제가 발견되었다.

### 근본 원인

1. **ExitPlanMode 훅이 수동 힌트만 제공**: `plan-doc-reminder.sh`는 `additionalContext`에 텍스트만 주입하고 강제/검증/자동화 없음
2. **구조화 데이터 부재**: 인터뷰 결과가 자유 형식 Markdown으로만 저장되어 후속 에이전트가 프로그래밍적으로 소비 불가
3. **work item 수동 생성**: `cch work create`가 사용자/에이전트의 명시적 호출에만 의존
4. **파이프라인 자동 트리거 없음**: `/cch-team` 파이프라인이 존재하지만 명시적 호출 필요
5. **에이전트 리플레이 로그 증거**: Plan 에이전트 완료 후 executor 에이전트가 생성되지 않음

### 요구사항 (인터뷰 결과)

- 자동화 수준: **완전 자동** (인터뷰 → 구조화 → work item → 파이프라인)
- 데이터 포맷: **JSON** (기존 state.json, hooks.json과 일관성)
- 복원 범위: **동일 세션 내**
- 승인 시점: **ExitPlanMode 시점에 1회**

## 선택한 접근 방식

### A안: PostToolUse 훅 기반 자동 브릿지 (채택)

**이유**:
1. 최소 변경 — hooks.json 엔트리 1개 + 스크립트 1개
2. ExitPlanMode 자체가 사용자 승인이므로 PostToolUse에서 후속 처리가 논리적
3. activity-tracker.mjs와 동일한 Node.js 훅 스크립트 패턴
4. JSON 생성 + 파일 쓰기만 하므로 5초 타임아웃 내 완료 가능
5. 브릿지는 "데이터 준비"만, 실제 파이프라인 실행은 에이전트가 담당 (관심사 분리)

### 검토한 대안

| 방식 | 장점 | 단점 | 결정 |
|------|------|------|------|
| **B: cch CLI 확장** | bash 패턴 일관성 | bash로 JSON 생성 복잡, 파싱 불안정 | 기각 |
| **C: 전용 오케스트레이터** | 단일 파일에 모든 로직 | bash cch와 스타일 불일치, 타임아웃 위험 | 기각 |

## 아키텍처

### 전체 흐름

```
기존 (끊김):
  ExitPlanMode → [PreToolUse] plan-doc-reminder.sh (힌트만) → ❌ 끊김

개선 (완전 자동):
  ExitPlanMode 호출
       │
  [PreToolUse] plan-doc-reminder.sh ← 기존 유지
       │
  사용자가 ExitPlanMode 승인 ← 유일한 승인 지점
       │
  [PostToolUse] plan-bridge.mjs ← 신규
       │
       ├─① plan 문서 탐색 및 파싱
       │    └─ docs/plans/${today}-*.md (최신 mtime 우선)
       │
       ├─② execution-plan.json 생성
       │    └─ .claude/cch/execution-plan.json
       │
       ├─③ work item 자동 생성
       │    └─ bin/cch work create <work-id>
       │    └─ bin/cch work transition <work-id> doing
       │
       ├─④ 모드 자동 전환
       │    └─ bin/cch mode code
       │
       └─⑤ additionalContext 반환
            └─ 파이프라인 실행 지시 + 실행 계획 요약
                 → 에이전트가 /cch-team 자동 시작
```

### 변경 범위

| 구분 | 파일 | 변경 내용 |
|------|------|----------|
| 수정 | `hooks/hooks.json` | PostToolUse ExitPlanMode 엔트리 1개 추가 |
| 신규 | `scripts/plan-bridge.mjs` | plan 파싱 → JSON 생성 → work item → 모드 전환 → 지시 주입 |

## 상세 설계

### 1. hooks.json 변경

추가할 엔트리:

```json
{
  "event": "PostToolUse",
  "matcher": "ExitPlanMode",
  "command": "node scripts/plan-bridge.mjs",
  "timeout": 5000
}
```

기존 PreToolUse `plan-doc-reminder.sh`는 그대로 유지.

### 2. execution-plan.json 스키마

저장 경로: `.claude/cch/execution-plan.json`

```json
{
  "version": "1",
  "created_at": "2026-03-03T12:34:56Z",
  "work_id": "2026-03-03-login-feature",
  "plan_file": "docs/plans/2026-03-03-login-feature.md",
  "status": "ready",
  "goal": "사용자 로그인 기능 구현",
  "tasks": [
    { "id": 1, "description": "로그인 API 엔드포인트 구현", "done": false },
    { "id": 2, "description": "JWT 토큰 발급 로직", "done": false }
  ],
  "acceptance_criteria": [
    "로그인 성공 시 JWT 반환",
    "잘못된 비밀번호 시 401 응답"
  ],
  "changed_files": [
    "src/auth/login.ts",
    "src/middleware/jwt.ts"
  ],
  "pipeline": "cch-team",
  "mode": "code"
}
```

필드 추출 매핑:

| JSON 필드 | plan 문서 소스 | 추출 방법 |
|-----------|---------------|----------|
| `goal` | `## Goal` 섹션 | 첫 번째 비어있지 않은 줄 |
| `tasks` | 체크박스 (`- [ ] ...`, `- [x] ...`) | 정규식 매칭 |
| `acceptance_criteria` | `## Acceptance Criteria` 섹션 | 체크박스 또는 목록 항목 |
| `changed_files` | `## 예상 변경 파일` 섹션 | 백틱 코드 경로 추출 |
| `work_id` | plan 파일명 | `${today}-` 제거한 slug |

### 3. plan-bridge.mjs 로직

```
stdin (JSON) → 파싱
    │
    ├─ tool_name === "ExitPlanMode" 확인
    │
    ├─ 오늘 날짜의 plan 문서 탐색
    │    └─ docs/plans/${today}-*.md (최신 mtime 우선)
    │    └─ 없으면 경고 반환 후 종료
    │
    ├─ plan 문서 섹션별 파싱
    │    ├─ ## Goal → goal (첫 비어있지 않은 줄)
    │    ├─ 체크박스 (- [ ], - [x]) → tasks[]
    │    ├─ ## Acceptance Criteria → acceptance_criteria[]
    │    └─ ## 예상 변경 파일 → changed_files[]
    │
    ├─ 빈 템플릿 감지
    │    └─ goal이 비어있거나 tasks가 0개면 경고 반환
    │
    ├─ work_id 생성 (파일명 기반)
    │
    ├─ execution-plan.json 저장
    │    └─ .claude/cch/execution-plan.json
    │
    ├─ shell 명령 실행 (execSync, 각 2초 제한)
    │    ├─ bin/cch work create ${work_id} "${goal}"
    │    ├─ bin/cch work transition ${work_id} doing
    │    └─ bin/cch mode code
    │
    └─ JSON 출력
         { "continue": true, "hookSpecificOutput": { "additionalContext": "..." } }
```

### 4. additionalContext 주입 내용

```
[CCH BRIDGE ACTIVATED]

인터뷰 결과가 자동 처리되었습니다:
- 실행 계획: .claude/cch/execution-plan.json
- 작업 항목: ${work_id} (status: doing)
- 모드: code

지금 즉시 /cch-team 파이프라인을 시작하세요.
작업 ID: ${work_id}
계획 문서: ${plan_file}

실행 계획 요약:
- 목표: ${goal}
- 작업 수: ${tasks.length}개
- 완료 기준: ${acceptance_criteria.length}개
```

### 5. 에러 처리

| 상황 | 처리 | 결과 |
|------|------|------|
| plan 문서 없음 | 경고 메시지만 additionalContext에 주입 | `continue: true` |
| plan 문서가 빈 템플릿 | "plan 문서를 먼저 작성하세요" 안내 | `continue: true` |
| tasks가 0개 | "체크박스 항목을 추가하세요" 안내 | `continue: true` |
| work item 이미 존재 | `work create` 실패 무시, 기존 work item 사용 | `continue: true` |
| `cch` 명령 실패 | 개별 실패를 로그, 전체 흐름 중단 안 함 | `continue: true` |
| 타임아웃 (5초 초과) | shell 명령 각각에 2초 제한, try-catch 안전 종료 | `continue: true` |
| stdin 파싱 실패 | 즉시 `continue: true` 반환 | 무해한 실패 |

**핵심 원칙**: 훅은 절대 도구 실행을 차단하지 않음. `continue: true`를 항상 반환.

## 테스트 전략

| 계층 | 검증 항목 |
|------|----------|
| Unit | plan 문서 파싱 로직 (Goal, tasks, criteria 추출) |
| Unit | execution-plan.json 스키마 유효성 |
| Unit | work_id 생성 로직 (파일명 → slug 변환) |
| Integration | ExitPlanMode → PostToolUse → plan-bridge.mjs 호출 체인 |
| Integration | work item 생성 + doing 전이 + mode 전환 연동 |
| E2E | 인터뷰 완료 → 자동 파이프라인 시작까지 전체 흐름 |
| Edge | 빈 템플릿, 문서 없음, work item 중복, 타임아웃 |

## 위험 및 완화

| 위험 | 영향 | 완화 |
|------|------|------|
| additionalContext만으로 에이전트가 파이프라인을 시작하지 않을 수 있음 | 중 | `[CCH BRIDGE ACTIVATED]` 마커와 명시적 지시문으로 강제성 확보 |
| plan 문서 형식이 템플릿과 다를 수 있음 | 중 | 유연한 정규식 파싱 + 빈 값 허용 + 경고 메시지 |
| 5초 타임아웃 초과 가능 | 저 | shell 명령 개별 2초 제한, 병렬 불가 시 순차 실행 |
| 기존 plan-doc-reminder.sh와 중복 안내 | 저 | PreToolUse는 저장 안내, PostToolUse는 실행 안내로 역할 분리 |

## Notes

- 세션 간 복원은 현재 범위에서 제외 (동일 세션 내 브릿지만 해결)
- 향후 `UserPromptSubmit` 훅에서 pending execution-plan.json을 감지하는 확장 가능
- cch-team 스킬 자체의 수정은 불필요 — additionalContext를 통한 지시만으로 충분
