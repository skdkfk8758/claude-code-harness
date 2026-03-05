# cch-plan 스킬 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 설계(인터뷰) → 플래닝 → TODO 작성을 하나로 잇는 `cch-plan` 통합 스킬 생성

**Architecture:** 단일 SKILL.md 파일로 구성. Phase-Gated Smart Entry 패턴으로 입력 상태에 따라 적절한 단계부터 시작. superpowers:brainstorming과 superpowers:writing-plans를 체이닝하고, TODO Sync 로직을 추가.

**Tech Stack:** Claude Code Skill (SKILL.md YAML frontmatter + Markdown prompt)

---

### Task 1: SKILL.md 기본 골격 생성

**Files:**
- Create: `skills/cch-plan/SKILL.md`

**Step 1: SKILL.md 파일 생성**

```yaml
---
name: cch-plan
description: "설계(인터뷰) → 플래닝 → TODO 작성 통합 워크플로우. Smart Entry로 입력 상태에 따라 적절한 Phase부터 시작."
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
argument-hint: <아이디어, 설계문서 경로, 또는 플랜문서 경로>
---
```

frontmatter 뒤에 빈 스킬 본문을 둔다.

**Step 2: 파일 존재 확인**

Run: `ls -la skills/cch-plan/SKILL.md`
Expected: 파일이 존재하고 frontmatter가 올바른 YAML

**Step 3: 커밋**

```bash
git add skills/cch-plan/SKILL.md
git commit -m "feat(cch-plan): add skill skeleton with frontmatter"
```

---

### Task 2: Step 0 — 입력 분석 로직 작성

**Files:**
- Modify: `skills/cch-plan/SKILL.md`

**Step 1: Step 0 섹션 작성**

frontmatter 아래에 스킬 제목과 Step 0을 작성한다. 핵심 로직:

1. ARGUMENTS 변수에서 인자를 받는다
2. 인자가 파일 경로인지 판별:
   - `*-design.md` → `START_PHASE=2`, 해당 파일을 설계문서로 사용
   - `*-impl.md` → `START_PHASE=3`, 해당 파일을 플랜문서로 사용
   - 기타 `.md` → `START_PHASE=1`, 해당 파일을 컨텍스트 문서로 활용
3. 인자가 텍스트인 경우 → `START_PHASE=1`, 아이디어로 간주
4. 인자 없음 → `AskUserQuestion`으로 목적 질문 후 `START_PHASE=1`
5. 감지 결과 출력: "Phase N부터 시작합니다"

**Step 2: 검증**

스킬 파일을 읽어서 Step 0이 위 5가지 분기를 모두 다루는지 확인.

**Step 3: 커밋**

```bash
git add skills/cch-plan/SKILL.md
git commit -m "feat(cch-plan): add Step 0 input analysis with smart entry"
```

---

### Task 3: Phase 1 — Design (brainstorming 위임) 작성

**Files:**
- Modify: `skills/cch-plan/SKILL.md`

**Step 1: Phase 1 섹션 작성**

Step 0 뒤에 Phase 1을 추가한다. 핵심:

1. `START_PHASE > 1`이면 이 Phase를 건너뛴다
2. `superpowers:brainstorming` 스킬의 핵심 프로세스를 인라인으로 지시:
   - 프로젝트 컨텍스트 탐색 (파일, 문서, 최근 커밋)
   - 명확화 질문 (AskUserQuestion, 1회 1개)
   - 2-3가지 접근법 제안 (장단점 + 추천)
   - 설계 섹션별 제시 + 사용자 승인
   - 설계 문서 저장: `docs/plans/YYYY-MM-DD-<topic>-design.md`
3. 저장된 설계 문서 경로를 `DESIGN_DOC` 변수로 다음 Phase에 전달
4. **HARD-GATE:** 사용자 승인 없이 Phase 2로 진행 금지

brainstorming 스킬의 마지막 단계("writing-plans 호출")는 포함하지 않는다 — cch-plan이 직접 Phase 2로 이어준다.

**Step 2: 검증**

스킬 파일을 읽어서 Phase 1이 brainstorming의 핵심 요소(컨텍스트 탐색, 질문, 접근법, 설계 제시, 승인, 저장)를 모두 포함하는지 확인.

**Step 3: 커밋**

```bash
git add skills/cch-plan/SKILL.md
git commit -m "feat(cch-plan): add Phase 1 design interview via brainstorming"
```

---

### Task 4: Phase 2 — Plan (writing-plans 위임) 작성

**Files:**
- Modify: `skills/cch-plan/SKILL.md`

**Step 1: Phase 2 섹션 작성**

Phase 1 뒤에 Phase 2를 추가한다. 핵심:

1. `START_PHASE > 2`이면 이 Phase를 건너뛴다
2. 입력 결정:
   - Phase 1에서 이어온 경우: `DESIGN_DOC` 사용
   - Step 0에서 직접 진입한 경우: 인자로 받은 `*-design.md` 경로 사용
3. `superpowers:writing-plans` 스킬의 핵심 프로세스를 인라인으로 지시:
   - 설계 문서 읽기
   - 코드베이스 탐색 (관련 파일, 패턴 파악)
   - Task 분해 (2-5분 단위 bite-sized)
   - 각 Task: Files, Step 1-5 (TDD: 실패 테스트 → 실행 → 구현 → 통과 → 커밋)
   - 구현 플랜 문서 저장: `docs/plans/YYYY-MM-DD-<topic>-impl.md`
4. 저장된 플랜 문서 경로를 `PLAN_DOC` 변수로 다음 Phase에 전달
5. writing-plans의 "실행 옵션 선택" 단계는 생략 — Phase 3으로 자동 진행

**Step 2: 검증**

스킬 파일을 읽어서 Phase 2가 writing-plans의 핵심 요소(설계 읽기, 코드베이스 탐색, Task 분해, TDD, 저장)를 모두 포함하는지 확인.

**Step 3: 커밋**

```bash
git add skills/cch-plan/SKILL.md
git commit -m "feat(cch-plan): add Phase 2 implementation planning via writing-plans"
```

---

### Task 5: Phase 3 — TODO Sync 로직 작성

**Files:**
- Modify: `skills/cch-plan/SKILL.md`

**Step 1: Phase 3 섹션 작성**

Phase 2 뒤에 Phase 3을 추가한다. 이 Phase는 항상 실행된다. 핵심:

1. 입력 결정:
   - Phase 2에서 이어온 경우: `PLAN_DOC` 사용
   - Step 0에서 직접 진입한 경우: 인자로 받은 `*-impl.md` 경로 사용
2. **플랜 파싱:** 구현 플랜 문서에서 `### Task N: <제목>` 패턴으로 Task 목록 추출
3. **TODO.md 업데이트:**
   a. `docs/TODO.md` 읽기
   b. 마지막 항목 ID 파싱 (예: `#133` → 다음은 `#134`부터)
   c. 기존 Phase 이름들 확인하여 새 Phase 코드 결정
   d. Critical Path 섹션에 새 Phase 라인 추가
   e. 파일 하단(마지막 Phase 뒤)에 새 Phase 블록 추가:
   ```markdown
   ## Phase PL: <topic> 구현

   - [ ] **#134** <Task 1 제목>
     - 세부 요구사항 1
     - 세부 요구사항 2
     - 의존: 없음

   - [ ] **#135** <Task 2 제목>
     - 세부 요구사항
     - 의존: #134
   ```
   f. 상태 헤더의 전체 항목 수와 미완료 수 갱신
4. **TaskCreate 생성:**
   각 Task에 대해 TaskCreate 호출:
   - subject: `[PL] <Task 제목>`
   - description: 플랜 문서의 해당 Task 내용
   - 의존성이 있는 Task는 blockedBy 설정
5. 결과 요약 출력: 추가된 항목 수, ID 범위, TaskList 현황

**Step 2: 검증**

스킬 파일을 읽어서 Phase 3이 다음을 모두 포함하는지 확인:
- 플랜 파싱 지시
- TODO.md 마지막 ID 파싱
- Critical Path 업데이트
- 새 Phase 블록 형식 (기존 TODO.md 패턴과 일치)
- 상태 헤더 갱신
- TaskCreate + blockedBy 설정

**Step 3: 커밋**

```bash
git add skills/cch-plan/SKILL.md
git commit -m "feat(cch-plan): add Phase 3 TODO sync (docs/TODO.md + TaskCreate)"
```

---

### Task 6: Step 4 — 완료 보고 + 전체 검증

**Files:**
- Modify: `skills/cch-plan/SKILL.md`

**Step 1: 완료 보고 섹션 작성**

Phase 3 뒤에 최종 Step을 추가한다:

1. 생성된 산출물 경로 목록 출력:
   - 설계 문서 (Phase 1 수행 시)
   - 구현 플랜 (Phase 2 수행 시)
   - TODO.md 추가 항목 범위
2. 다음 단계 안내:
   - "구현을 시작하려면 Subagent-Driven 또는 Parallel Session 중 선택하세요"
   - Subagent-Driven: `superpowers:subagent-driven-development` 사용
   - Parallel Session: 별도 세션에서 `superpowers:executing-plans` 사용

**Step 2: 전체 스킬 파일 검증**

스킬 파일 전체를 읽어서 다음 체크리스트 확인:
- [ ] YAML frontmatter 유효 (name, description, user-invocable, allowed-tools, argument-hint)
- [ ] Step 0: 5가지 입력 분기 모두 존재
- [ ] Phase 1: brainstorming 핵심 요소 + skip 조건 + HARD-GATE
- [ ] Phase 2: writing-plans 핵심 요소 + skip 조건
- [ ] Phase 3: TODO.md 업데이트 + TaskCreate + 항상 실행
- [ ] Step 4: 산출물 요약 + 다음 단계 안내
- [ ] 전체 흐름이 끊김 없이 이어지는지

**Step 3: 커밋**

```bash
git add skills/cch-plan/SKILL.md
git commit -m "feat(cch-plan): add completion report and finalize skill"
```

---

### Task 7: cch-sync로 스킬 동기화 및 동작 확인

**Files:**
- None (기존 파일만 사용)

**Step 1: 스킬 동기화**

Run: `/cch-sync`
Expected: cch-plan 스킬이 플러그인 캐시에 동기화됨

**Step 2: 스킬 목록 확인**

스킬이 등록되었는지 확인. `/cch-plan` 이 사용 가능한 스킬 목록에 나타나야 한다.

**Step 3: 최종 커밋 (변경사항 있을 경우)**

```bash
git add -A
git commit -m "chore(cch-plan): sync skill to plugin cache"
```
