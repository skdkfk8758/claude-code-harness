# Brainstorming Skill 구조적 결함 분석 및 개선 설계

> **대상:** `superpowers/4.3.1/skills/brainstorming/SKILL.md`
> **작성일:** 2026-03-04
> **상태:** TODO (분석 완료, 구현 대기)

---

## 1. 현상

brainstorming 스킬 실행 시 6개 task 중 Step 3("2-3가지 접근법 제안")에서 중단됨:

```
✔ 1. 프로젝트 컨텍스트 탐색       ← completed
✔ 2. 명확화 질문 진행              ← completed
◼ 3. 2-3가지 접근법 제안           ← in_progress (여기서 멈춤)
◻ 4. 설계 제시 및 승인
◻ 5. 설계 문서 작성
◻ 6. 구현 플랜으로 전환
```

---

## 2. 단계별 정밀 분석

### Step 1: 프로젝트 컨텍스트 탐색 — OK (경미한 문제)

**현재 동작:** 파일, 문서, 최근 커밋을 확인한 후 task를 completed로 마킹.

**문제점:**
- **(P3) 탐색 범위 미정의:** "check files, docs, recent commits"만 명시. 어떤 파일을 우선 확인할지, 얼마나 깊이 탐색할지 기준 없음. 에이전트마다 탐색 깊이가 다를 수 있음.
- **(P3) 완료 기준 없음:** 언제 "충분히 탐색했다"고 판단할지 정의되지 않음.

**영향:** 낮음. 실제 동작에는 큰 문제 없음.

---

### Step 2: 명확화 질문 — OK (경미한 문제)

**현재 동작:** `AskUserQuestion`으로 한 번에 하나씩 질문. 사용자 응답 후 task completed.

**문제점:**
- **(P3) 종료 조건 미정의:** 몇 개의 질문을 할지, 어떤 주제를 반드시 커버해야 하는지 기준 없음. "purpose/constraints/success criteria"를 언급하지만, 이 3가지를 모두 확인했는지 검증하는 메커니즘 없음.
- **(P3) 단일 질문 강제 미보장:** "one at a time"이라고 하지만, 에이전트가 한 메시지에 여러 질문을 섞을 수 있음. AskUserQuestion 도구 자체가 최대 4개 질문을 허용.

**영향:** 낮음. 실제 동작에는 큰 문제 없음.

---

### Step 3: 2-3가지 접근법 제안 — CRITICAL (중단 원인)

**현재 동작:** 접근법을 대화형으로 제시하고... 그 다음이 없음.

**근본 원인 3가지:**

#### (P0) AskUserQuestion 호출 누락
스킬 텍스트가 "Present options conversationally with your recommendation"이라고만 되어 있음. 접근법을 제시한 후 사용자에게 선택을 요청하는 명시적 `AskUserQuestion` 호출 패턴이 없음.

```
있어야 할 흐름:
  접근법 A/B/C 제시
  → AskUserQuestion("어떤 접근법을 선택하시겠습니까?")
  → 사용자 응답 수신
  → TaskUpdate(task3, completed)
  → TaskUpdate(task4, in_progress)

실제 흐름:
  접근법 A/B/C 제시
  → (끝. 다음 행동 지시 없음)
  → 🔴 STALL
```

#### (P0) Task 전환 트리거 미정의
Step 1→2, Step 2→3 전환은 도구 기반(탐색 완료/질문 응답)이라 자연스럽지만, Step 3→4는 "사용자가 접근법을 선택했다"는 이벤트를 감지하고 전환해야 함. 이 전환 로직이 스킬에 명시되지 않음.

#### (P1) 대화형 vs 도구 기반 패턴 혼용
Step 1-2는 도구 기반(Glob/Read → AskUserQuestion)이라 자동 전환되지만, Step 3은 순수 대화형이라 전환 트리거가 없음. 스킬 내에서 두 패턴이 일관성 없이 혼용됨.

---

### Step 4: 설계 제시 및 승인 — HIGH (잠재적 중단)

**현재 동작:** Step 3을 통과한다고 가정하면, 설계를 섹션별로 제시하고 승인을 받아야 함.

**문제점:**

#### (P0) 섹션별 승인 루프 미정의
"get user approval after each section"이라고 하지만:
- 몇 개의 섹션으로 나눌지 기준 없음
- 각 섹션 제시 후 AskUserQuestion 호출 패턴 없음
- 사용자가 "no"라고 하면 어떤 동작을 해야 하는지 (수정 후 재제시? 같은 task 내에서?) 불명확
- graphviz에서 "User approves design?" → "no, revise" 루프가 있지만, task 상태 관리와 어떻게 연동되는지 미정의

#### (P1) 커버리지 체크리스트 비강제
"Cover: architecture, components, data flow, error handling, testing"이라고 하지만, 이 항목들을 모두 커버했는지 검증하는 메커니즘 없음. 에이전트가 일부만 다루고 넘어갈 수 있음.

#### (P2) 단일 task로 복잡한 루프 관리
섹션별 제시 → 승인 → 수정 → 재승인 루프가 하나의 task(Task 4) 안에서 관리되어야 함. task 상태만으로는 "현재 어느 섹션까지 승인받았는지" 추적 불가.

---

### Step 5: 설계 문서 작성 — MEDIUM (동작 가능하나 문제 있음)

**현재 동작:** 승인된 설계를 `docs/plans/YYYY-MM-DD-<topic>-design.md`에 저장하고 커밋.

**문제점:**

#### (P1) 커밋 강제 메커니즘 부재
"Commit the design document to git"이라고 하지만, 에이전트가 커밋을 빼먹을 수 있음. 커밋 완료 여부를 검증하는 단계 없음.

#### (P2) writing-clearly-and-concisely 스킬 참조 불확실
"Use elements-of-style:writing-clearly-and-concisely skill if available"이라고 하지만, 해당 스킬 존재 여부를 확인하는 방법이 없고, 없으면 어떻게 하는지도 미정의.

#### (P2) 파일명 생성 규칙 모호
`<topic>` 부분을 어떻게 생성할지 (사용자 입력? 자동 추출? kebab-case 강제?) 미정의.

---

### Step 6: 구현 플랜으로 전환 — MEDIUM (잠재적 실패)

**현재 동작:** `writing-plans` 스킬을 호출하여 구현 계획을 생성.

**문제점:**

#### (P1) 스킬 호출 컨텍스트 전달 미정의
`writing-plans` 스킬을 Skill 도구로 호출할 때, 이전 단계의 설계 문서 경로를 어떻게 전달하는지 미정의. writing-plans 스킬은 "Read plan file"을 첫 단계로 하지만, 어떤 파일을 읽어야 하는지 모를 수 있음.

#### (P1) worktree 컨텍스트 누락
writing-plans 스킬이 "This should be run in a dedicated worktree"라고 요구하지만, brainstorming 스킬에서 worktree 생성을 트리거하는 시점이 없음. Step 5에서 커밋한 후? Step 6 진입 시?

#### (P2) 실행 옵션 사전 안내 부재
writing-plans → executing-plans 또는 subagent-driven-development로 이어지는 전체 파이프라인을 사용자가 인지하지 못한 상태에서 진행될 수 있음.

---

## 3. 교차 분석: 구조적 결함

### (P0) Task 의존성 관계 미설정

현재: 6개 task가 독립적으로 생성됨 (blockedBy 없음)
필요: 순차 의존성 체인 설정

```
Task 1 (없음)
Task 2 (blockedBy: [1])
Task 3 (blockedBy: [2])
Task 4 (blockedBy: [3])
Task 5 (blockedBy: [4])
Task 6 (blockedBy: [5])
```

### (P0) 절차적(Procedural) 지시 부재

다른 잘 동작하는 스킬(executing-plans, subagent-driven-development)과 비교:

| 특성 | executing-plans | brainstorming |
|------|----------------|---------------|
| 단계별 도구 호출 명시 | ✅ "Mark as in_progress" → "Run verifications" → "Mark as completed" | ❌ 없음 |
| 전환 조건 명시 | ✅ "When batch complete" → Report → Wait | ❌ 없음 |
| 에러/거부 처리 | ✅ "STOP executing immediately when..." | ❌ 없음 |
| 상태 머신 정의 | ✅ 암묵적이지만 명확한 상태 흐름 | ❌ 선언적 체크리스트만 |

### (P1) 선언적 vs 절차적 불일치

스킬의 Checklist 섹션은 **선언적** ("what to do"):
> "Propose 2-3 approaches — with trade-offs and your recommendation"

The Process 섹션은 **설명적** ("how to think about it"):
> "Present options conversationally with your recommendation and reasoning"

하지만 **절차적** 지시 ("exactly what tools to call and when")가 없음:
> ❌ "AskUserQuestion으로 선택을 요청하고, 응답 후 TaskUpdate로 completed 처리"

---

## 4. 개선 방향 (TODO)

### P0 — 즉시 수정 필요

- [ ] **Step 3에 명시적 AskUserQuestion 패턴 추가**: 접근법 제시 후 반드시 사용자 선택을 도구로 요청
- [ ] **Step 4에 섹션별 승인 루프 정의**: 각 섹션 후 AskUserQuestion → 승인/수정 판단 → TaskUpdate 흐름 명시
- [ ] **Task 의존성 체인 강제**: 6개 task 생성 시 blockedBy 관계를 반드시 설정하도록 지시
- [ ] **각 Step에 TaskUpdate 호출 시점 명시**: in_progress 진입, completed 전환, 다음 task in_progress 전환을 명시적으로 기술

### P1 — 안정성 개선

- [ ] **Step 2 종료 조건 정의**: purpose/constraints/success criteria 3가지를 모두 확인한 후에만 completed 처리
- [ ] **Step 4 커버리지 강제**: architecture, components, data flow, error handling, testing 항목 중 해당 사항을 모두 다뤘는지 자체 검증
- [ ] **Step 5 커밋 검증 추가**: `git status`로 clean 상태 확인 후 completed 처리
- [ ] **Step 6 worktree 생성 시점 정의**: writing-plans 호출 전 worktree 생성 여부를 사용자에게 확인
- [ ] **Step 6 컨텍스트 전달 명시**: 설계 문서 경로를 writing-plans에 전달하는 방법 정의

### P2 — 품질 개선

- [ ] **Step 1 탐색 우선순위 가이드 추가**: README → docs/ → 최근 커밋 → 관련 소스 순서
- [ ] **Step 5 파일명 규칙 명확화**: kebab-case, 영문, 핵심 키워드 2-3개
- [ ] **Step 4 섹션 진행 상태 추적**: task description에 현재 섹션 정보를 업데이트
- [ ] **전체 프로세스 예시 추가**: executing-plans의 Example Workflow처럼 도구 호출을 포함한 구체적 실행 예시

### P3 — 선택적 개선

- [ ] **Step 2 질문 수 제한**: 최대 5개 이내 권장, 3개 미만이면 충분한지 자체 점검
- [ ] **"simple project" 단축 경로**: 명백히 단순한 작업에 대해 Step 3-4를 축약하는 경로 정의
- [ ] **중단/재개 메커니즘**: 세션이 끊겼을 때 TaskList에서 현재 상태를 복원하는 방법 정의

---

## 5. 비교 참조

### executing-plans가 중단되지 않는 이유

```
Step 2: Execute Batch
  For each task:
    1. Mark as in_progress        ← 명시적 TaskUpdate
    2. Follow each step exactly   ← 절차적 지시
    3. Run verifications          ← 검증 단계
    4. Mark as completed          ← 명시적 TaskUpdate

Step 3: Report
  When batch complete:
    - Show what was implemented   ← 출력 지시
    - Say: "Ready for feedback."  ← 사용자 응답 트리거
```

모든 전환이 **명시적 도구 호출 + 사용자 응답 트리거**로 정의되어 있어 중단되지 않음.

### brainstorming에 적용해야 할 패턴

```
Step 3: Propose 2-3 approaches
  1. TaskUpdate(task3, in_progress)
  2. 접근법 A/B/C를 대화형으로 제시
  3. AskUserQuestion("어떤 접근법이 좋겠습니까?", options=[A, B, C])
  4. 사용자 응답 수신
  5. TaskUpdate(task3, completed)
  6. TaskUpdate(task4, in_progress)
  7. Step 4 진행
```

---

## 6. 영향 범위

이 수정은 `brainstorming/SKILL.md` **단일 파일**만 변경하면 됨. 다른 스킬(writing-plans, executing-plans 등)은 변경 불필요. 다만 brainstorming이 superpowers 스킬 체인의 진입점이므로, 이 수정이 전체 파이프라인의 안정성에 직접적 영향을 미침.
