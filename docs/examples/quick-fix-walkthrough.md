# Quick-Fix 워크플로우 실행 예시

실제 사용자 세션을 시뮬레이션한 전체 흐름 예시.

## 시나리오

> 사용자: "getUserById 함수에서 null 체크가 빠져있어서 간단하게 수정해줘"

---

## Phase 0: 워크플로우 라우터 자동 제안

사용자 입력이 들어오면 오케스트레이터가 `workflow-router-rules.json`을 기반으로 분류합니다.

### 매칭 분석

```
입력: "getUserById 함수에서 null 체크가 빠져있어서 간단하게 수정해줘"

bugfix 신호:
  - "빠져있어서" → intentPattern "(수정|fix|고치).*" 부분 매칭 (2pt)
  - 매칭 없음 → 총 2pt

quick-fix 신호:
  - "간단하게" → keyword 매칭 (1pt)
  - "수정해줘" → keyword 매칭 (1pt)
  - "함수에서" → intentPattern "(하나|한 개|one|single).*?(함수|function)" 부분 매칭 (2pt)
  - simplicityIndicators "단일 파일" 암시 → bugfix 점수 -2pt
  - 총 4pt

결과: quick-fix (4pt) > bugfix (0pt)
```

### 사용자에게 표시

```
이 작업은 `quick-fix` 워크플로우가 적합해 보입니다.
`/workflow quick-fix`로 시작하시겠어요? (무시하고 진행해도 됩니다)
```

사용자: `/workflow quick-fix`

---

## Phase 1: 워크플로우 시작

오케스트레이터가 `quick-fix.yaml`을 읽고 초기 상태를 생성합니다.

### workflow-state.json (초기)

```json
{
  "workflow": "quick-fix",
  "name": "getUserById-null-check",
  "currentStep": 1,
  "startedAt": "2026-03-06T14:30:00Z",
  "steps": {}
}
```

### 오케스트레이터 출력

```
────────────────────────────────────
[workflow] quick-fix: "getUserById-null-check"
Step 1/3 (implementation) — Auto
────────────────────────────────────
```

---

## Phase 2: Step 1 — Implementation (Auto, enforce)

오케스트레이터가 `code-refactor-master` 에이전트를 dispatch합니다.

### Dispatch 프롬프트 구성

```markdown
# Task
getUserById 함수에서 null 체크가 빠져있어서 수정

# Agent Instructions
(code-refactor-master.md 전문)

## NON-NEGOTIABLE RULES (from tdd) [ENFORCED]
(tdd/SKILL.md의 Rules 섹션)

## NON-NEGOTIABLE RULES (from verification) [ENFORCED]
(verification/SKILL.md의 Rules 섹션)
```

### 에이전트 실행 — TDD 사이클

```
[Task 1/1] getUserById null check 추가

RED — 실패 테스트 작성:
  $ npm test -- --grep "getUserById"
  FAIL: getUserById should return null for non-existent id
  1 failed, 5 passed

GREEN — null 체크 코드 추가:
  $ npm test -- --grep "getUserById"
  6 passed, 0 failed

REFACTOR — 불필요한 변경 없음, skip

[Task 1] DONE
```

### Enforcement 검증 (오케스트레이터)

```
tdd enforce 검증:
  ✓ RED 증거 발견: "FAIL: getUserById should return null" + "1 failed"
  ✓ GREEN 증거 발견: "6 passed, 0 failed"
  → PASSED

verification enforce 검증:
  ✓ 테스트 실행 증거: "npm test" 명령어 + pass/fail 카운트
  → PASSED
```

### workflow-state.json (Step 1 완료)

```json
{
  "workflow": "quick-fix",
  "name": "getUserById-null-check",
  "currentStep": 2,
  "startedAt": "2026-03-06T14:30:00Z",
  "steps": {
    "implementation": {
      "status": "completed",
      "summary": "getUserById에 null 체크 추가. 존재하지 않는 ID 입력 시 null 반환하도록 수정",
      "decisions": [
        "early return 패턴으로 null 체크 (if (!user) return null)",
        "기존 테스트 5개 유지 + null 케이스 테스트 1개 추가"
      ],
      "issues": [],
      "enforcement": {
        "tdd": "passed",
        "verification": "passed"
      }
    }
  }
}
```

### 오케스트레이터 출력

```
[workflow] quick-fix: step 1/3 (implementation) ✓ completed
  enforcement: tdd ✓ | verification ✓
[workflow] Next: step 2/3 (review) — Auto
```

---

## Phase 3: Step 2 — Review (Auto, retry-on-fail)

오케스트레이터가 `code-architecture-reviewer` 에이전트를 dispatch합니다.

### 에이전트 실행 — 6차원 리뷰

```markdown
# Code Review Report

## Verdict: PASS_WITH_NOTES

## Executive Summary
getUserById 함수에 null 체크가 올바르게 추가됨. 단일 함수 수정으로 범위가 적절하고,
TDD 사이클을 준수함. advisory 1건 있음.

## Blocking Issues (must fix before completion)
(없음)

## Advisory Notes (non-blocking improvements)
| # | File | Suggestion |
|---|------|-----------|
| 1 | src/services/user.ts | getUserById의 반환 타입을 `User`에서 `User | null`로 명시적 변경 권장 |

## Architecture Assessment
단일 함수 수정으로 아키텍처 영향 없음.

## Verification Drift Assessment
| Changed File | Corresponding Test | Status |
|-------------|-------------------|--------|
| src/services/user.ts | tests/services/user.test.ts | ✓ 존재, null 케이스 테스트 추가됨 |

## Positive Observations
- TDD RED-GREEN 사이클 준수
- 기존 테스트 5개 모두 유지, 회귀 없음
```

### retry-on-fail 체크

```
Verdict: PASS_WITH_NOTES
trigger-status: "NEEDS_CHANGES" → 매칭 안 됨
→ retry 불필요, 다음 스텝으로 진행
```

### workflow-state.json (Step 2 완료)

```json
{
  "workflow": "quick-fix",
  "name": "getUserById-null-check",
  "currentStep": 3,
  "startedAt": "2026-03-06T14:30:00Z",
  "steps": {
    "implementation": {
      "status": "completed",
      "summary": "getUserById에 null 체크 추가. 존재하지 않는 ID 입력 시 null 반환하도록 수정",
      "decisions": [
        "early return 패턴으로 null 체크 (if (!user) return null)",
        "기존 테스트 5개 유지 + null 케이스 테스트 1개 추가"
      ],
      "issues": [],
      "enforcement": {
        "tdd": "passed",
        "verification": "passed"
      }
    },
    "review": {
      "status": "completed",
      "summary": "PASS_WITH_NOTES. 반환 타입 명시적 변경 권장 (advisory). 아키텍처 영향 없음",
      "decisions": [],
      "issues": ["반환 타입 User → User | null 명시적 변경 권장 (non-blocking)"],
      "finalVerdict": "PASS_WITH_NOTES",
      "retries": 0
    }
  }
}
```

### 오케스트레이터 출력

```
[workflow] quick-fix: step 2/3 (review) ✓ completed
  verdict: PASS_WITH_NOTES (advisory 1건)
[workflow] Next: step 3/3 (completion) — Gate
```

---

## Phase 4: Step 3 — Completion (Gate)

```
────────────────────────────────────
[Gate] Step 3/3: completion
테스트 통과 확인 후 merge/PR/keep/discard 선택
────────────────────────────────────
Please run `/finishing-branch` to proceed.
```

사용자: `/finishing-branch`

→ 사용자가 "merge locally" 선택

### workflow-state.json (최종)

```json
{
  "workflow": "quick-fix",
  "name": "getUserById-null-check",
  "currentStep": 3,
  "startedAt": "2026-03-06T14:30:00Z",
  "completedAt": "2026-03-06T14:38:00Z",
  "steps": {
    "implementation": {
      "status": "completed",
      "summary": "getUserById에 null 체크 추가. 존재하지 않는 ID 입력 시 null 반환하도록 수정",
      "decisions": [
        "early return 패턴으로 null 체크 (if (!user) return null)",
        "기존 테스트 5개 유지 + null 케이스 테스트 1개 추가"
      ],
      "issues": [],
      "enforcement": {
        "tdd": "passed",
        "verification": "passed"
      }
    },
    "review": {
      "status": "completed",
      "summary": "PASS_WITH_NOTES. 반환 타입 명시적 변경 권장 (advisory). 아키텍처 영향 없음",
      "decisions": [],
      "issues": ["반환 타입 User → User | null 명시적 변경 권장 (non-blocking)"],
      "finalVerdict": "PASS_WITH_NOTES",
      "retries": 0
    },
    "completion": {
      "status": "completed",
      "summary": "merge locally 선택. main 브랜치에 머지 완료",
      "decisions": ["merge locally"],
      "issues": [],
      "userFeedback": "머지"
    }
  }
}
```

---

## Phase 5: 세션 끊김 후 Resume (보너스 시나리오)

만약 Step 2 (review) 도중 세션이 끊겼다면:

사용자: `/workflow quick-fix resume`

### 오케스트레이터 출력

```
────────────────────────────────────
[Resume] quick-fix: "getUserById-null-check"
Started: 2026-03-06T14:30:00Z

Completed steps:
  1. implementation ✓ — getUserById에 null 체크 추가
     enforcement: tdd ✓ | verification ✓
     decisions: early return 패턴, 테스트 1개 추가

Resuming from: step 2/3 (review)
────────────────────────────────────
```

오케스트레이터가 이전 스텝의 `summary`와 `decisions`를 출력하고, implementation 스텝의 변경 파일을 다시 읽어서 review 에이전트에 컨텍스트로 주입합니다.

---

## Enforcement 실패 시나리오 (참고)

만약 Step 1에서 에이전트가 테스트를 실행하지 않았다면:

```
verification enforce 검증:
  ✗ 테스트 실행 증거 없음 — 명령어 출력에 test 결과 없음
  → FAILED

오케스트레이터: 에이전트 재dispatch (1/2)
  추가 지시: "verification 규칙 미준수. 테스트를 실행하고 결과를 포함하여 재보고하세요."

(에이전트 재실행 후)

verification enforce 검증:
  ✓ 테스트 실행 증거: "npm test" + "6 passed, 0 failed"
  → PASSED (after retry)

enforcement 기록: { "verification": "passed_after_retry" }
```

---

## 타임라인 요약

```
14:30:00  사용자 입력 → 라우터가 quick-fix 제안
14:30:05  /workflow quick-fix 시작
14:30:10  Step 1: code-refactor-master dispatch (TDD enforce)
14:33:00  Step 1: 완료, enforcement 검증 통과
14:33:05  Step 2: code-architecture-reviewer dispatch
14:35:00  Step 2: PASS_WITH_NOTES, retry 불필요
14:35:05  Step 3: Gate — /finishing-branch 안내
14:38:00  사용자: merge locally → 워크플로우 완료
```

총 소요: ~8분. 사용자 입력: 2회 (`/workflow quick-fix`, `/finishing-branch`)
