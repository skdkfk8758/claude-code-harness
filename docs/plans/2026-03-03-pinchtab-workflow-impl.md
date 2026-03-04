# PinchTab Workflow Execution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** cch-pinchtab 오케스트레이터를 확장하여 자연어 워크플로우 요청을 적응형으로 자동 실행하는 기능을 추가한다.

**Architecture:** 기존 cch-pinchtab 스킬에 워크플로우 모드를 추가한다. PLAN → INFRA → EXECUTE(적응형 루프) → REPORT 4단계 파이프라인으로 동작하며, EXECUTE 단계에서 OBSERVE-THINK-ACT-VERIFY-RECORD 프로토콜을 사용한다. 예외 발생 시 AskUserQuestion으로 사용자에게 개입을 요청한다.

**Tech Stack:** Bash, PinchTab CLI (v0.7.x), SKILL.md (Claude Code skill format), YAML

**Workflow rule:** 구현 시작 전 반드시 `docs/TODO.md`에 작업 항목을 등록한다. (Phase PTW: #70~#76 등록 완료)

**설계 문서:** `docs/plans/2026-03-03-pinchtab-workflow-design.md`

**관련 파일:**
- `skills/cch-pinchtab/SKILL.md` — 오케스트레이터 (수정 대상)
- `skills/cch-pt-test/SKILL.md` — 테스트 실행 에이전트 (참조)
- `skills/cch-pt-report/SKILL.md` — 보고서 에이전트 (수정 대상)
- `bin/cch-pt` — PinchTab CLI 래퍼 (수정 불필요)

---

### Task 1: cch-pinchtab 오케스트레이터에 워크플로우 모드 추가 (TODO #70)

**Files:**
- Modify: `skills/cch-pinchtab/SKILL.md:1-144`

**Step 1: 현재 SKILL.md 읽기**

Run: `cat skills/cch-pinchtab/SKILL.md`
확인: 현재 3가지 모드 (--infra, 시나리오, 자연어 테스트)

**Step 2: SKILL.md에 워크플로우 모드 추가**

`skills/cch-pinchtab/SKILL.md` 의 `## 사용법` 섹션에 워크플로우 사용법 추가:

```markdown
## 사용법

```
/cch-pinchtab <url> <자연어 테스트 요청>
/cch-pinchtab <scenario-file-path>
/cch-pinchtab --infra <status|start|stop|cleanup>
/cch-pinchtab <url> <자연어 워크플로우 요청>
/cch-pinchtab <자연어 워크플로우 요청>
```

### 예시

```
# 테스트 모드 (기존)
/cch-pinchtab https://naver.com 로그인 폼이 정상 렌더링되는지 확인해줘

# 워크플로우 모드 (신규)
/cch-pinchtab https://naver.com 부동산 검색해서 래미안 아파트 찾아줘
/cch-pinchtab 구글에서 claude code 검색해서 첫 번째 결과 제목 알려줘
```
```

`## 파이프라인 흐름` 섹션 바로 앞에, `Step 0: 입력 분석`의 모드 판별 로직을 4가지로 확장:

```markdown
### Step 0: 입력 분석

인자(ARGUMENTS)를 분석하여 모드를 결정한다:

1. **--infra 모드**: `--infra` 플래그 감지 → 인프라 관리만 수행
2. **시나리오 파일 모드**: `.yaml` 경로를 감지하면 시나리오 로드
3. **자연어 테스트 모드**: URL + "확인/테스트/검증" 키워드 → 정형 테스트 계획 생성 후 실행
4. **워크플로우 모드**: URL + "찾아줘/해줘/검색/알려줘" 키워드, 또는 자연어만 (URL 추론) → 적응형 실행

모드 3과 4의 판별이 애매한 경우, LLM이 의도를 분석하여 결정한다.
- 테스트/검증 의도 → 모드 3 (정형 테스트)
- 탐색/조작/데이터 수집 의도 → 모드 4 (워크플로우)
```

`## 파이프라인 흐름` 에 워크플로우 파이프라인 추가:

```markdown
## 파이프라인 흐름

### 테스트 모드 (모드 2, 3)
```
입력 분석 → 세션 초기화 → pt-infra → pt-test → pt-report → 결과 전달
```

### 워크플로우 모드 (모드 4)
```
입력 분석 → PLAN(계획 생성/승인) → 세션 초기화 → pt-infra → EXECUTE(적응형 루프) → REPORT → 결과 전달
```
```

**Step 3: 워크플로우 파이프라인 Step W1~W5 섹션 추가**

SKILL.md 파일 하단(에러 처리 섹션 앞)에 워크플로우 전용 섹션을 추가한다:

```markdown
---

## 워크플로우 모드 상세

워크플로우 모드가 선택되면 다음 흐름으로 실행한다.

### Step W1: PLAN — 자연어 → 실행 계획 변환

오케스트레이터가 직접 수행한다 (서브에이전트 불필요).

**입력 파싱:**
- `<URL> <자연어>` → URL 명시 모드
- `<자연어만>` → URL 추론 모드 (문맥에서 사이트 추출: "네이버" → naver.com)

**계획 생성:**
1. 목표를 1~2문장으로 요약
2. 필요한 스텝을 순서대로 나열
3. 각 스텝에 예상 동작과 성공 기준 명시
4. ref 값은 `<dynamic>` 표기 — 실행 시 snapshot에서 동적 결정

**사용자에게 계획 제시 후 승인:**

```
## 실행 계획

목표: 네이버에서 "부동산"을 검색하여 래미안 아파트 관련 결과를 찾는다

1. navigate → https://www.naver.com (wait: 3)
2. snapshot (interactive) → 검색창 ref 확인
3. fill <검색창 ref> "부동산"
4. press Enter
5. snapshot (wait: 3) → 결과 페이지 확인
6. text → "래미안" 포함 여부 확인
7. 결과가 없으면 → 추가 검색 또는 탐색
8. screenshot → 최종 결과 캡처

예상 소요: ~30초 | 스텝 수: 8

진행하시겠습니까?
```

AskUserQuestion으로 승인을 받은 후 Step W2로 진행한다.

### Step W2: 세션 초기화 + INFRA

```bash
SESSION_DIR=$(bash bin/cch-pt session-init)
```

기존 pt-infra 에이전트를 동일하게 호출하여 PinchTab 서버를 보장한다.
계획의 첫 번째 URL로 탭을 생성한다.

```
Agent(subagent_type="general-purpose")
프롬프트: "PinchTab 인프라를 준비하라.
  skills/cch-pt-infra/SKILL.md 의 지침을 따른다.
  1. bash bin/cch-pt ensure true
  2. bash bin/cch-pt new-tab '<url>'
  3. 결과를 <SESSION_DIR>/infra-result.json 에 저장"
```

### Step W3: EXECUTE — 적응형 실행 루프

Agent 도구로 서브에이전트를 실행한다:

```
Agent(subagent_type="oh-my-claudecode:deep-executor")
프롬프트: "<SESSION_DIR>/infra-result.json 에서 tabId를 읽고,
  아래 워크플로우 계획을 적응적으로 실행하라.

  ## 실행 계획
  <workflow-plan-steps>

  ## 실행 프로토콜: OBSERVE-THINK-ACT-VERIFY-RECORD

  각 스텝마다 다음 사이클을 수행한다:

  1. OBSERVE — 현재 페이지 상태 파악
     bash bin/cch-pt snap interactive [tabId]
     필요 시: bash bin/cch-pt text [tabId]

  2. THINK — 다음 동작에 필요한 요소 결정
     snapshot 결과에서 필요한 ref를 찾는다.
     우선순위: role 기반 → label 기반 → 전체 분석 → 사용자 문의

  3. ACT — 동작 실행
     bash bin/cch-pt fill <ref> '텍스트' [tabId]
     bash bin/cch-pt click <ref> [tabId]
     bash bin/cch-pt press Enter [tabId]
     bash bin/cch-pt nav <url> 3 [tabId]

  4. VERIFY — 결과 확인
     bash bin/cch-pt snap diff [tabId]  (또는 snap interactive)
     bash bin/cch-pt text [tabId]
     필요 시: bash bin/cch-pt screenshot <session_dir>/screenshots/step-N.png [tabId]

  5. RECORD — 결과 기록
     각 스텝의 action, target, status, duration, performance를 JSON으로 누적

  ## 예외 처리
  - 요소 못 찾음: 재 snapshot → 전체 분석 → AskUserQuestion (스크린샷 첨부)
  - 페이지 변화 없음: 1회 재시도 → 실패 시 사용자 문의
  - 예상 외 팝업/모달: 스크린샷 + 사용자 문의
  - 로그인/캡챠: headed 모드 전환 제안

  ## 제한
  - 단일 스텝 재시도: 최대 3회
  - 전체 스텝: 최대 30개
  - 총 실행 시간: 최대 5분

  완료 후 <SESSION_DIR>/test-results.json 에 결과 저장.
  추출한 데이터가 있으면 <SESSION_DIR>/extracted-data.json 에도 저장."
```

### Step W4: REPORT — 결과 보고

```
Agent(subagent_type="oh-my-claudecode:scientist")
프롬프트: "<SESSION_DIR>/test-results.json 을 읽고,
  <SESSION_DIR>/extracted-data.json 이 있으면 함께 읽고,
  skills/cch-pt-report/SKILL.md 의 지침에 따라:
  1. CLI 워크플로우 요약을 출력하라
  2. Markdown 보고서를 tests/pinchtab/reports/<name>/<timestamp>/report.md 에 생성하라
  3. extracted-data.json 이 있으면 보고서에 '추출 데이터' 섹션을 추가하라
  4. 스크린샷을 보고서 디렉토리로 복사하라
  5. 보고서 경로를 반환하라"
```

### Step W5: 결과 전달

사용자에게 다음을 보고한다:
- CLI 워크플로우 실행 요약
- 추출된 데이터 요약 (있는 경우)
- 보고서 파일 경로
- 실패/예외 항목 상세 (있는 경우)
```

**Step 4: 환경 변수 섹션 확장**

SKILL.md 하단 `## 환경 변수` 테이블에 워크플로우 관련 변수를 추가:

```markdown
## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| PT_PORT | 9867 | PinchTab 서버 포트 |
| PT_TIMEOUT | 30 | 요청 타임아웃 (초) |
| PT_MODE | headless | headed 또는 headless |
| PT_WORKFLOW_TIMEOUT | 300 | 워크플로우 전체 타임아웃 (초) |
| PT_MAX_STEPS | 30 | 워크플로우 최대 스텝 수 |
| PT_MAX_RETRIES | 3 | 단일 스텝 최대 재시도 수 |
```

**Step 5: 에러 처리 테이블 확장**

기존 에러 처리 테이블에 워크플로우 항목을 추가:

```markdown
| 워크플로우 | 계획 생성 실패 | URL/의도 불명확 → 사용자에게 명확화 요청 |
| 워크플로우 | ref 결정 실패 | 재 snapshot → 전체 분석 → 사용자 문의 |
| 워크플로우 | 예상 외 팝업 | 스크린샷 + AskUserQuestion |
| 워크플로우 | 로그인/캡챠 | headed 모드 전환 제안 |
| 워크플로우 | 최대 스텝 초과 | 현재까지 결과 저장 후 중단 |
```

**Step 6: SKILL.md 변경 검증**

Run: `head -5 skills/cch-pinchtab/SKILL.md`
확인: YAML frontmatter 정상 (name, description, user-invocable, allowed-tools)

Run: `grep -c "워크플로우" skills/cch-pinchtab/SKILL.md`
Expected: 20+ occurrences

Run: `grep "AskUserQuestion" skills/cch-pinchtab/SKILL.md`
Expected: 워크플로우 예외 처리에서 AskUserQuestion 참조 확인

**Step 7: Commit**

```bash
git add skills/cch-pinchtab/SKILL.md
git commit -m "feat(pt): cch-pinchtab에 워크플로우 모드 추가 (#70)

- 입력 분석에 워크플로우 모드 판별 로직 추가
- PLAN→INFRA→EXECUTE→REPORT 4단계 파이프라인 정의
- OBSERVE-THINK-ACT-VERIFY-RECORD 실행 프로토콜 기술
- 예외 처리 및 환경 변수 확장"
```

---

### Task 2: PLAN — 자연어 → 실행 계획 변환 검증 (TODO #71)

**Files:**
- Modify: `skills/cch-pinchtab/SKILL.md` (Task 1에서 추가한 Step W1)
- Create: `tests/pinchtab/scenarios/examples/workflow-naver-search.yaml`

이 Task의 핵심은 Task 1에서 작성한 PLAN 섹션이 올바르게 동작하는지를 예제 워크플로우로 검증하는 것이다.

**Step 1: 워크플로우 예제 시나리오 작성**

워크플로우 모드의 자연어 → 계획 변환 예시를 YAML 레퍼런스로 작성:

```yaml
# tests/pinchtab/scenarios/examples/workflow-naver-search.yaml
name: workflow-naver-search
description: 네이버에서 부동산 검색 → 래미안 아파트 찾기 (워크플로우 모드 레퍼런스)
url: "https://www.naver.com"
mode: headless
type: workflow

# 이 파일은 자연어 → 계획 변환의 기대 출력 레퍼런스
# 실제 워크플로우 실행 시에는 자연어 입력으로부터 자동 생성된다
natural_language_input: "네이버에서 부동산 검색해서 래미안 아파트 찾아줘"

expected_plan:
  goal: "네이버에서 '부동산'을 검색하여 래미안 아파트 관련 결과를 찾는다"
  steps:
    - action: navigate
      url: "https://www.naver.com"
      wait: 3

    - action: snapshot
      filter: interactive
      purpose: "검색창 ref 확인"

    - action: fill
      ref: "<dynamic>"
      text: "부동산"
      purpose: "검색창에 키워드 입력"

    - action: press
      key: Enter

    - action: snapshot
      wait: 3
      purpose: "검색 결과 로드 확인"

    - action: text
      assert:
        contains: ["래미안"]
      purpose: "래미안 관련 결과 존재 확인"

    - action: screenshot
      output: naver-search-result.png
```

**Step 2: SKILL.md의 계획 변환 예시 검증**

Run: `grep -A 15 "변환 예시" skills/cch-pinchtab/SKILL.md`
확인: 기존 자연어 → 테스트 계획 변환 예시가 있음

Run: `cat tests/pinchtab/scenarios/examples/workflow-naver-search.yaml`
확인: YAML 문법 정상, 모든 필드 존재

**Step 3: Commit**

```bash
git add tests/pinchtab/scenarios/examples/workflow-naver-search.yaml
git commit -m "feat(pt): 워크플로우 네이버 검색 예제 시나리오 추가 (#71)

- 자연어 → 계획 변환 레퍼런스 YAML 작성
- expected_plan으로 기대 출력 명시"
```

---

### Task 3: EXECUTE — 적응형 실행 루프 상세화 (TODO #72)

**Files:**
- Modify: `skills/cch-pinchtab/SKILL.md` (Step W3 보강)

Task 1에서 Step W3의 프롬프트 골격을 작성했다. 이 Task에서는 적응형 ref 결정 전략과 실행 루프의 구체적 로직을 보강한다.

**Step 1: SKILL.md의 Step W3에 Adaptive Ref Resolution 상세 추가**

Step W3 프롬프트 내의 THINK 섹션을 구체화한다:

```markdown
  2. THINK — Adaptive Ref Resolution

     snapshot 결과를 분석하여 다음 동작에 필요한 요소를 찾는다.

     **전략 우선순위:**

     a) role 기반 매칭
        - 검색창: role="search" 또는 role="searchbox"
        - 버튼: role="button" + 텍스트 매칭
        - 링크: role="link" + 텍스트 매칭
        - 입력: role="textbox" 또는 role="combobox"

     b) label/placeholder 매칭
        - aria-label, placeholder, title 속성에서 키워드 검색
        - 예: "검색" → placeholder="검색어를 입력하세요"

     c) 텍스트 기반 매칭
        - 버튼/링크의 visible text에서 키워드 검색
        - 예: "로그인" 버튼 → text content "로그인"

     d) 전체 snapshot LLM 분석
        - 위 방법으로 결정 불가 시, 전체 snapshot을 분석하여 가장 적합한 ref 선택
        - 선택 이유를 RECORD에 기록

     e) 사용자 문의 (최후 수단)
        - 스크린샷 촬영: bash bin/cch-pt screenshot <session_dir>/screenshots/ask-user.png [tabId]
        - AskUserQuestion으로 스크린샷과 함께 어떤 요소를 선택할지 문의
```

**Step 2: 실행 루프 종료 조건 명시**

Step W3 프롬프트에 종료 조건을 추가:

```markdown
  ## 종료 조건

  실행 루프는 다음 중 하나가 충족되면 종료한다:
  1. 모든 계획된 스텝이 성공적으로 완료됨
  2. 사용자가 "작업 중단" 선택
  3. 최대 스텝 수(PT_MAX_STEPS=30) 도달
  4. 최대 실행 시간(PT_WORKFLOW_TIMEOUT=300초) 초과
  5. 연속 3회 동일 스텝 실패 (무한 루프 감지)

  종료 시 항상:
  - 현재까지의 결과를 test-results.json에 저장
  - 추출한 데이터를 extracted-data.json에 저장
  - 마지막 스크린샷을 촬영
```

**Step 3: 검증**

Run: `grep -c "OBSERVE\|THINK\|ACT\|VERIFY\|RECORD" skills/cch-pinchtab/SKILL.md`
Expected: 10+ occurrences

Run: `grep "Adaptive Ref" skills/cch-pinchtab/SKILL.md`
Expected: Adaptive Ref Resolution 섹션 존재 확인

**Step 4: Commit**

```bash
git add skills/cch-pinchtab/SKILL.md
git commit -m "feat(pt): 적응형 실행 루프 상세화 (#72)

- Adaptive Ref Resolution 5단계 전략 추가
- 실행 루프 종료 조건 5가지 명시
- OBSERVE-THINK-ACT-VERIFY-RECORD 각 단계 구체화"
```

---

### Task 4: 예외 감지 및 사용자 개입 처리 (TODO #73)

**Files:**
- Modify: `skills/cch-pinchtab/SKILL.md` (에러 처리 섹션 보강)

**Step 1: 워크플로우 예외 처리 전용 섹션 추가**

SKILL.md의 에러 처리 테이블 아래에 워크플로우 전용 예외 처리 가이드를 추가:

```markdown
## 워크플로우 예외 처리

### 예외 유형별 대응

#### 1. 요소 찾기 실패
```
감지: THINK에서 ref 결정 불가
대응:
  1. bash bin/cch-pt snap interactive [tabId]  (재 snapshot)
  2. 전체 snapshot 분석하여 유사 요소 탐색
  3. 실패 시 → bash bin/cch-pt screenshot <path> [tabId]
  4. AskUserQuestion:
     question: "다음 요소를 찾지 못했습니다: <target>"
     options: ["스크린샷에서 직접 지정", "다른 방법 시도", "이 스텝 건너뛰기", "작업 중단"]
```

#### 2. 예상 외 팝업/모달
```
감지: OBSERVE에서 이전과 다른 오버레이/모달 요소 감지
대응:
  1. 스크린샷 촬영
  2. AskUserQuestion:
     question: "예상 외 팝업이 나타났습니다."
     options: ["팝업 닫기 시도", "팝업 내용 확인 후 진행", "작업 중단"]
  3. "닫기 시도" → ESC 또는 닫기 버튼 클릭
```

#### 3. 로그인/인증 필요
```
감지: OBSERVE에서 로그인 폼 (input[type=password]) 감지
대응:
  1. AskUserQuestion:
     question: "로그인이 필요한 페이지입니다."
     options: ["headed 모드로 전환 (수동 로그인)", "로그인 없이 접근 가능한 경로 탐색", "작업 중단"]
  2. headed 모드 전환 시 → bash bin/cch-pt cleanup + bash bin/cch-pt ensure false
```

#### 4. 캡챠/봇 차단
```
감지: OBSERVE에서 "captcha", "robot", "자동화" 등 키워드 감지
대응:
  1. AskUserQuestion:
     question: "봇 차단/캡챠가 감지되었습니다."
     options: ["headed 모드로 전환 (수동 해결)", "다른 접근 방법 시도", "작업 중단"]
```

#### 5. 타임아웃/네트워크 오류
```
감지: ACT 명령의 exit code != 0 또는 응답 없음
대응:
  1. 2초 대기 후 1회 재시도
  2. 재실패 시 → AskUserQuestion:
     question: "네트워크 오류 또는 타임아웃이 발생했습니다."
     options: ["재시도", "다른 URL 시도", "작업 중단"]
```
```

**Step 2: 검증**

Run: `grep -c "AskUserQuestion" skills/cch-pinchtab/SKILL.md`
Expected: 5+ occurrences (예외 유형별 각 1회)

**Step 3: Commit**

```bash
git add skills/cch-pinchtab/SKILL.md
git commit -m "feat(pt): 워크플로우 예외 처리 5유형 상세화 (#73)

- 요소 찾기 실패, 팝업, 로그인, 캡챠, 타임아웃 대응 추가
- 각 예외에 AskUserQuestion 기반 사용자 개입 흐름 정의"
```

---

### Task 5: 데이터 추출 및 결과 보고 확장 (TODO #74)

**Files:**
- Modify: `skills/cch-pt-report/SKILL.md:1-118`

**Step 1: pt-report SKILL.md에 워크플로우 보고 형식 추가**

`skills/cch-pt-report/SKILL.md` 의 `## CLI 요약 출력` 섹션 아래에 워크플로우 전용 출력 형식을 추가:

```markdown
## 워크플로우 CLI 요약 출력

워크플로우 모드 결과인 경우 (extracted-data.json이 존재하면) 다음 형식으로 출력:

```
═══════════════════════════════════════════
  PinchTab Workflow Report
═══════════════════════════════════════════
  목표:     <workflow goal>
  URL:      <url>
  Mode:     <mode>
  Duration: <duration>s
  Result:   N/M steps 완료
───────────────────────────────────────────
  ✅ [1] navigate → naver.com (2.1s)
  ✅ [2] snapshot → 검색창 발견 e5 (0.8s)
  ✅ [3] fill e5 "부동산" (0.3s)
  ✅ [4] press Enter (0.2s)
  ✅ [5] snapshot → 결과 로드 확인 (3.2s)
  ✅ [6] text → "래미안" 포함 확인 (0.5s)
  ✅ [7] 추가 탐색 (1.8s)
  ✅ [8] screenshot 저장 (0.4s)
───────────────────────────────────────────
  📊 추출 데이터:
    - 래미안 관련 검색 결과 5건 발견
    - 첫 번째 결과: "래미안 원펜타스 - 분양정보"
───────────────────────────────────────────
  📁 Report: tests/pinchtab/reports/<name>/<ts>/report.md
═══════════════════════════════════════════
```
```

**Step 2: Markdown 보고서에 워크플로우 섹션 추가**

`## Markdown 보고서 생성` 섹션의 보고서 템플릿에 추출 데이터 섹션을 추가:

```markdown
## 추출 데이터

extracted-data.json이 존재하는 경우 이 섹션을 추가한다:

```markdown
## 추출 데이터

| 항목 | 값 |
|------|-----|
| 키워드 | 부동산 |
| 결과 수 | 5건 |

### 상세 데이터

1. **래미안 원펜타스** — 분양정보 ...
2. **래미안 라클래시** — ...

> 원본 데이터: `extracted-data.json`
```
```

**Step 3: 보고서 저장 경로에 extracted-data.json 추가**

보고서 디렉토리 구조에 데이터 파일을 포함:

```markdown
## 보고서 저장 경로

```
tests/pinchtab/reports/
└── <name>/
    └── <YYYYMMDD-HHMMSS>/
        ├── report.md
        ├── test-results.json
        ├── extracted-data.json    ← 워크플로우 모드 시 추가
        └── *.png (스크린샷)
```
```

**Step 4: 오케스트레이터 연동 반환값 확장**

```markdown
## 오케스트레이터 연동

보고서 생성 완료 후 오케스트레이터에 반환:

```json
{
  "reportPath": "tests/pinchtab/reports/<name>/<timestamp>/report.md",
  "summary": {"total": 8, "passed": 8, "failed": 0, "skipped": 0},
  "hasFailed": false,
  "hasExtractedData": true,
  "extractedDataPath": "<session_dir>/extracted-data.json"
}
```
```

**Step 5: 검증**

Run: `grep "extracted-data" skills/cch-pt-report/SKILL.md`
Expected: 3+ occurrences

Run: `grep "워크플로우" skills/cch-pt-report/SKILL.md`
Expected: 3+ occurrences

**Step 6: Commit**

```bash
git add skills/cch-pt-report/SKILL.md
git commit -m "feat(pt): pt-report에 워크플로우 보고 형식 확장 (#74)

- 워크플로우 CLI 요약 출력 형식 추가
- Markdown 보고서에 추출 데이터 섹션 추가
- extracted-data.json 보고서 디렉토리 포함"
```

---

### Task 6: 워크플로우 통합 검증 (TODO #75)

**Files:**
- 검증 대상: `skills/cch-pinchtab/SKILL.md`, `skills/cch-pt-report/SKILL.md`, `bin/cch-pt`

이 Task는 코드 작성이 아닌 통합 검증이다.

**Step 1: PinchTab 서버 기동**

```bash
bash bin/cch-pt ensure true
```
Expected: `[cch-pt] PinchTab ready` 또는 `[cch-pt] PinchTab already running`

**Step 2: 세션 초기화**

```bash
SESSION_DIR=$(bash bin/cch-pt session-init)
echo $SESSION_DIR
```
Expected: `/tmp/cch-pt-session-XXXXXXXXXX` 경로 출력

**Step 3: 기본 워크플로우 시뮬레이션 — 네이버 검색**

수동으로 OBSERVE-THINK-ACT-VERIFY-RECORD 사이클을 1회 실행:

```bash
# 1. 탭 생성 + navigate
bash bin/cch-pt new-tab "https://www.naver.com"
# tabId 확인
bash bin/cch-pt tabs

# 2. OBSERVE — 스냅샷
bash bin/cch-pt snap interactive

# 3. THINK — 검색창 ref 확인 (출력에서 search/input 관련 ref 탐색)

# 4. ACT — 검색어 입력
bash bin/cch-pt fill <검색창ref> "부동산"
bash bin/cch-pt press Enter

# 5. VERIFY — 결과 확인
sleep 3
bash bin/cch-pt text

# 6. 스크린샷
bash bin/cch-pt screenshot "$SESSION_DIR/screenshots/naver-result.png"
```

각 명령의 exit code가 0인지 확인한다.

**Step 4: SKILL.md 형식 검증**

```bash
# cch-pinchtab SKILL.md frontmatter 확인
head -6 skills/cch-pinchtab/SKILL.md
# Expected: name, description, user-invocable, allowed-tools

# pt-report SKILL.md frontmatter 확인
head -6 skills/cch-pt-report/SKILL.md

# 워크플로우 관련 섹션 존재 확인
grep "워크플로우 모드" skills/cch-pinchtab/SKILL.md
grep "OBSERVE-THINK-ACT" skills/cch-pinchtab/SKILL.md
grep "extracted-data" skills/cch-pt-report/SKILL.md
```

**Step 5: 정리**

```bash
bash bin/cch-pt cleanup
```

**Step 6: 검증 결과 기록 (선택)**

검증 결과를 세션 디렉토리 또는 보고서 디렉토리에 기록.

---

### Task 7: Phase PTW Release Gate (TODO #76)

**Files:**
- 검증 대상: 모든 Phase PTW 관련 파일

이 Task는 Phase PTW의 모든 항목이 완료되었는지 최종 확인하는 게이트이다.

**Step 1: TODO.md 항목 완료 확인**

```bash
grep -E "#7[0-6]" docs/TODO.md
```
Expected: #70~#75가 모두 `[x]`로 마킹됨

**Step 2: 파일 존재 확인**

```bash
# 수정된 스킬 파일
ls -la skills/cch-pinchtab/SKILL.md
ls -la skills/cch-pt-report/SKILL.md

# 워크플로우 예제 시나리오
ls -la tests/pinchtab/scenarios/examples/workflow-naver-search.yaml

# 설계/구현 문서
ls -la docs/plans/2026-03-03-pinchtab-workflow-design.md
ls -la docs/plans/2026-03-03-pinchtab-workflow-impl.md
```

**Step 3: SKILL.md 핵심 섹션 확인**

```bash
# 오케스트레이터 — 워크플로우 모드 존재
grep -c "워크플로우" skills/cch-pinchtab/SKILL.md
# Expected: 20+

# 실행 프로토콜 존재
grep "OBSERVE-THINK-ACT-VERIFY-RECORD" skills/cch-pinchtab/SKILL.md
# Expected: 1+ match

# 예외 처리 존재
grep -c "AskUserQuestion" skills/cch-pinchtab/SKILL.md
# Expected: 5+

# 보고서 — 워크플로우 확장 존재
grep "extracted-data" skills/cch-pt-report/SKILL.md
# Expected: 3+
```

**Step 4: TODO.md #76 완료 마킹**

`docs/TODO.md` 에서 #76을 `[x]`로 변경.

**Step 5: 최종 Commit**

```bash
git add docs/TODO.md
git commit -m "feat(pt): Phase PTW 완료 — 워크플로우 실행 기능 (#76)

- #70~#75 완료 확인
- Phase PTW Release Gate 통과"
```
