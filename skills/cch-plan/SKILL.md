---
name: cch-plan
description: "설계(인터뷰) → 플래닝 → TODO 작성 통합 워크플로우. Smart Entry로 입력 상태에 따라 적절한 Phase부터 시작."
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
argument-hint: <아이디어, 설계문서 경로, 또는 플랜문서 경로>
---

# cch-plan

설계(인터뷰) → 플래닝 → TODO 작성을 하나의 스킬로 이어주는 통합 워크플로우.
아이디어 한 문장부터 실행 가능한 TaskList까지 자동으로 연결한다.

```
입력 분석 → [Phase 1: Design] → [Phase 2: Plan] → [Phase 3: TODO] → 완료 보고
              ↑ skip 가능         ↑ skip 가능        ↑ 항상 실행
```

---

## Guidelines

### Notepad Wisdom
- 작업 시작 전 `notepad_read`로 이전 세션의 컨텍스트를 확인한다.
- 중요한 설계 결정이나 발견사항은 `notepad_write_working`으로 기록한다.
- 반복적으로 사용되는 패턴이나 규칙은 `notepad_write_manual`로 영구 저장한다.

---

## Step 0: 입력 분석 (Smart Entry)

ARGUMENTS를 파싱하여 시작 Phase를 결정한다.

**분기 로직:**

1. **인자가 파일 경로이고 `*-design.md`로 끝나는 경우**
   - `START_PHASE=2`
   - `DESIGN_DOC=<해당 경로>`
   - "설계 문서를 감지했습니다. Phase 2 (플래닝)부터 시작합니다."

2. **인자가 파일 경로이고 `*-impl.md`로 끝나는 경우**
   - `START_PHASE=3`
   - `PLAN_DOC=<해당 경로>`
   - "구현 플랜을 감지했습니다. Phase 3 (TODO Sync)부터 시작합니다."

3. **인자가 기타 `.md` 파일 경로인 경우**
   - `START_PHASE=1`
   - 해당 문서를 Phase 1 컨텍스트로 활용
   - "Markdown 문서를 컨텍스트로 활용합니다. Phase 1 (설계)부터 시작합니다."

4. **인자가 텍스트인 경우**
   - `START_PHASE=1`
   - 해당 텍스트를 아이디어로 간주
   - "Phase 1 (설계)부터 시작합니다."

5. **인자 없음**
   - AskUserQuestion: "어떤 기능/시스템을 설계하고 싶으신가요? 아이디어나 목적을 한 문장으로 설명해 주세요."
   - 응답을 받은 후 `START_PHASE=1`
   - "Phase 1 (설계)부터 시작합니다."

**검증:** 파일 경로가 감지된 경우, Read로 해당 파일의 존재 여부를 확인한다.
파일이 존재하지 않으면 사용자에게 알리고 AskUserQuestion으로 올바른 경로를 재질문한다.

감지 결과를 출력한다: "**Phase N부터 시작합니다** (감지된 입력: <요약>)"

---

## Phase 1: Design (설계 인터뷰)

> **SKIP 조건:** `START_PHASE > 1`이면 이 Phase를 건너뛰고 Phase 2로 이동한다.

구조화된 설계 인터뷰를 수행한다.

### 1-1. 프로젝트 컨텍스트 탐색

다음을 **병렬로** 읽는다:
- `docs/Architecture.md` (있는 경우)
- `docs/PRD.md` (있는 경우)
- `docs/plans/` 디렉터리 목록 — 기존 설계 문서 및 진행 상황 파악
- 최근 커밋 5개: `git log --oneline -5`

탐색 결과를 바탕으로 현재 프로젝트 상태와 새 기능이 미치는 영향을 파악한다.

### 1-2. 명확화 질문

AskUserQuestion으로 1회 1개씩 질문하여 다음을 파악한다:
- 핵심 사용 사례 (누가, 무엇을, 왜)
- 기술적 제약 또는 선호사항
- 기존 시스템과의 통합 방식
- 완료 기준 (Definition of Done)

질문은 맥락에 따라 최소 1회~최대 4회로 조절한다. 이미 명확한 내용은 재질문하지 않는다.

### 1-3. 접근법 제안

2~3가지 접근법을 제안한다. 각 접근법:
- 핵심 아이디어 (1~2문장)
- 장점 / 단점
- 적합한 상황

마지막에 **추천 접근법**과 이유를 명시한다.

AskUserQuestion: "위 접근법 중 어떤 것을 선택하시겠습니까? 또는 수정할 사항이 있으면 말씀해 주세요."

### 1-4. 설계 문서 작성 및 승인

선택된 접근법을 바탕으로 설계 문서를 섹션별로 작성하고, 각 섹션마다 사용자 승인을 받는다.

섹션 순서 (주제에 맞게 조정 가능):
1. 개요 및 목표
2. 아키텍처 / 구조
3. 핵심 컴포넌트 / 인터페이스
4. 데이터 흐름 / 처리 방식
5. 고려 사항 (에러 처리, 성능, 보안 등)
6. 산출물 맵 (파일, 경로, 형식)

각 섹션 제시 후: AskUserQuestion: "이 섹션을 승인하시겠습니까? 수정할 내용이 있으면 알려주세요."

> **HARD-GATE:** 모든 섹션 승인 없이 Phase 2로 진행하지 않는다.

### 1-5. 설계 문서 저장

오늘 날짜와 주제로 파일명을 결정한다:
```
docs/plans/YYYY-MM-DD-<topic>-design.md
```

`<topic>`은 영문 소문자 + 하이픈 (예: `branch-workflow`, `cch-plan`).

파일을 Write 도구로 저장하고 경로를 출력한다.

`DESIGN_DOC=<저장된 경로>`

---

## Phase 2: Plan (구현 계획)

> **SKIP 조건:** `START_PHASE > 2`이면 이 Phase를 건너뛰고 Phase 3으로 이동한다.

구조화된 구현 계획을 작성한다.

### 2-1. 입력 결정

- Phase 1에서 이어온 경우: `DESIGN_DOC` 사용
- Step 0에서 직접 진입한 경우: ARGUMENTS의 `*-design.md` 경로 사용

설계 문서를 Read로 읽는다.

### 2-2. 코드베이스 탐색

설계 문서의 관련 파일/디렉터리를 Glob과 Read로 탐색한다:
- 수정할 기존 파일 파악
- 새로 생성할 파일 경로 결정
- 기존 패턴 및 컨벤션 확인

### 2-3. Task 분해

구현을 2~5분 단위 bite-sized Task로 분해한다.

**각 Task 형식:**

```markdown
### Task N: <제목>

**Files:**
- Create/Modify: `<파일 경로>`

**Step 1: <TDD - 실패 테스트 작성>**
<구체적인 테스트 코드 또는 명령>

**Step 2: <테스트 실행 확인 (실패)>**
Run: `<테스트 명령>`
Expected: <실패 메시지>

**Step 3: <구현>**
<구체적인 구현 지시>

**Step 4: <테스트 통과 확인>**
Run: `<테스트 명령>`
Expected: <성공 메시지>

**Step 5: <커밋>**
```bash
git add <파일>
git commit -m "<type>(<scope>): <메시지>"
```

**의존:** Task M (없으면 "없음")
```

Task 간 의존성을 명시한다.

### 2-4. 구현 플랜 저장

설계 문서와 동일한 날짜 + 주제로 파일명 결정:
```
docs/plans/YYYY-MM-DD-<topic>-impl.md
```

파일을 Write 도구로 저장하고 경로를 출력한다.

`PLAN_DOC=<저장된 경로>`

> Phase 3으로 자동 진행한다. writing-plans의 "실행 옵션 선택" 단계는 생략한다.

---

## Phase 3: TODO Sync

> **항상 실행.** START_PHASE에 관계없이 이 Phase는 건너뛰지 않는다.

### 3-1. 입력 결정

- Phase 2에서 이어온 경우: `PLAN_DOC` 사용
- Step 0에서 직접 진입한 경우: ARGUMENTS의 `*-impl.md` 경로 사용

구현 플랜 문서를 Read로 읽는다.

### 3-2. 플랜 파싱

구현 플랜 문서에서 `### Task N: <제목>` 패턴으로 Task 목록을 추출한다.
각 Task의 제목, 세부 Steps, 의존성(Task M)을 파악한다.

### 3-3. TaskList 생성

각 Task에 대해 TaskCreate로 세션 작업 목록을 생성한다:

```
TaskCreate(
  subject: "[XX] <Task 제목>",
  description: "<Task 상세 + 플랜 문서 경로 참조>"
)
```

- 의존성이 있는 Task는 addBlockedBy로 연결
- 플랜 문서(`docs/plans/*-impl.md`)가 태스크의 SSOT 역할을 한다

### 3-5. 결과 요약 출력

```
TODO Sync 완료:
- TaskList 생성: N개 항목 로드
- 플랜 문서: docs/plans/<topic>-impl.md
```

TaskList를 호출하여 현재 세션 작업 목록을 출력한다.

---

## Step 4: 완료 보고

생성된 산출물을 목록으로 출력한다:

```
## 완료 보고

### 생성된 산출물
```

- **설계 문서** (Phase 1 수행 시): `docs/plans/YYYY-MM-DD-<topic>-design.md`
- **구현 플랜** (Phase 2 수행 시): `docs/plans/YYYY-MM-DD-<topic>-impl.md`
- **TaskList 생성**: N개 항목

### 다음 단계

구현을 시작하려면 다음 중 하나를 선택하세요:

**옵션 A: Subagent-Driven (자동화)**
```
/cch-sp-subagent-dev 사용
— 각 Task를 서브에이전트가 순서대로 자동 실행
```

**옵션 B: Plan 실행 (수동 제어)**
```
/cch-sp-execute-plan 사용
— 직접 Task를 선택하여 단계적으로 실행
```
