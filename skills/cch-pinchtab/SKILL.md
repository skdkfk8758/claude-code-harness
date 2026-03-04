---
name: cch-pinchtab
description: PinchTab 기반 웹 UI 디버깅/테스트/워크플로우 오케스트레이터
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskList, AskUserQuestion
---

# PinchTab Web UI Orchestrator

PinchTab을 활용한 웹 UI 디버깅/테스트/워크플로우의 진입점.
사용자의 자연어 요청, YAML 시나리오 파일, 또는 자연어 워크플로우를 받아
자동으로 파이프라인을 실행한다.

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
# 테스트 모드
/cch-pinchtab https://naver.com 로그인 폼이 정상 렌더링되는지 확인해줘
/cch-pinchtab tests/pinchtab/scenarios/naver-login.yaml

# 인프라 관리
/cch-pinchtab --infra status

# 워크플로우 모드
/cch-pinchtab https://naver.com 부동산 검색해서 래미안 아파트 찾아줘
/cch-pinchtab 구글에서 claude code 검색해서 첫 번째 결과 제목 알려줘
```

## 파이프라인 흐름

### 테스트 모드 (모드 2, 3)
```
입력 분석 → 세션 초기화 → pt-infra → pt-test → pt-report → 결과 전달
```

### 워크플로우 모드 (모드 4)
```
입력 분석 → PLAN(계획 생성/승인) → 세션 초기화 → pt-infra → EXECUTE(적응형 루프) → REPORT → 결과 전달
```

---

## Step 0: 입력 분석

인자(ARGUMENTS)를 분석하여 모드를 결정한다:

1. **--infra 모드**: `--infra` 플래그 감지 → 인프라 관리만 수행
2. **시나리오 파일 모드**: `.yaml` 경로를 감지하면 시나리오 로드
3. **자연어 테스트 모드**: URL + "확인/테스트/검증" 키워드 → 정형 테스트 계획 생성 후 실행
4. **워크플로우 모드**: URL + "찾아줘/해줘/검색/알려줘" 키워드, 또는 자연어만 (URL 추론) → 적응형 실행

모드 3과 4의 판별이 애매한 경우, LLM이 의도를 분석하여 결정한다:
- 테스트/검증 의도 → 모드 3 (정형 테스트)
- 탐색/조작/데이터 수집 의도 → 모드 4 (워크플로우)

---

## 테스트 모드 (모드 1, 2, 3)

### Step 1: 세션 초기화

```bash
SESSION_DIR=$(bash bin/cch-pt session-init)
```

세션 디렉토리를 생성하고, 이후 모든 에이전트가 이 경로를 공유한다.

### Step 2: pt-infra — 인프라 준비

Agent 도구로 서브에이전트를 실행한다:

```
Agent(subagent_type="general-purpose")
프롬프트: "PinchTab 인프라를 준비하라.
  skills/cch-pt-infra/SKILL.md 의 지침을 따른다.
  1. bash bin/cch-pt ensure <headless여부> 실행 (bridge 모드로 서버 시작)
  2. bash bin/cch-pt tabs 로 현재 탭 목록 확인
  3. 필요 시 bash bin/cch-pt new-tab '<url>' 로 새 탭 생성
  4. 결과를 <SESSION_DIR>/infra-result.json 에 저장:
     {status, port, tabId, mode}"
```

### Step 3: pt-test — 테스트 실행

Agent 도구로 서브에이전트를 실행한다:

```
Agent(subagent_type="oh-my-claudecode:qa-tester")
프롬프트: "<SESSION_DIR>/infra-result.json 에서 tabId를 읽고,
  skills/cch-pt-test/SKILL.md 의 지침에 따라 테스트를 실행하라.

  시나리오 파일 모드: <scenario-path>를 읽고 steps를 순차 실행
  자연어 모드: 아래 테스트 계획을 실행
  <generated-steps>

  각 스텝을 bin/cch-pt 명령으로 실행하고 결과를 CLI에 실시간 출력.
  완료 후 <SESSION_DIR>/test-results.json 에 결과 저장."
```

### Step 4: pt-report — 결과 보고

Agent 도구로 서브에이전트를 실행한다:

```
Agent(subagent_type="oh-my-claudecode:scientist")
프롬프트: "<SESSION_DIR>/test-results.json 을 읽고,
  skills/cch-pt-report/SKILL.md 의 지침에 따라:
  1. CLI 요약을 출력하라
  2. Markdown 보고서를 tests/pinchtab/reports/<name>/<timestamp>/report.md 에 생성하라
  3. 스크린샷을 보고서 디렉토리로 복사하라
  4. 보고서 경로를 반환하라"
```

### Step 5: 결과 전달

pt-report의 반환값을 사용자에게 전달한다:
- CLI 요약 출력 결과
- 보고서 파일 경로
- 실패 항목이 있으면 실패 상세 요약

## 자연어 → 테스트 계획 변환

사용자가 자연어로 요청할 경우, URL과 요청을 분석하여 테스트 스텝을 자동 생성한다.

변환 예시:
```
입력: "구글에서 'claude code' 검색해서 첫 번째 결과 제목 확인해줘"

→ 계획:
  1. navigate → https://google.com (wait: 3)
  2. snapshot (filter: interactive)
  3. fill 검색창 ref → "claude code"
  4. press Enter
  5. snapshot (wait: 3)
  6. assert: 검색 결과 존재 확인
  7. text → 첫 번째 결과 제목 추출
  8. screenshot → 결과 저장
```

생성한 계획을 사용자에게 먼저 보여주고 승인을 받은 후 실행한다.
단, ref 값은 실행 시 snapshot 결과에서 동적으로 결정한다.

---

## 워크플로우 모드 (모드 4)

워크플로우 모드가 선택되면 다음 흐름으로 실행한다.

### Step W1: PLAN — 자연어 → 실행 계획 변환

오케스트레이터가 직접 수행한다 (서브에이전트 불필요).

**입력 파싱:**
- `<URL> <자연어>` → URL 명시 모드
- `<자연어만>` → URL 추론 모드 (문맥에서 사이트 추출: "네이버" → naver.com)

**계획 생성 규칙:**
1. 목표를 1~2문장으로 요약
2. 필요한 스텝을 순서대로 나열 (navigate, snapshot, fill, click, press 등)
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

  2. THINK — Adaptive Ref Resolution
     snapshot 결과를 분석하여 다음 동작에 필요한 요소를 찾는다.

     전략 우선순위:
     a) role 기반 매칭
        - 검색창: role=search 또는 role=searchbox
        - 버튼: role=button + 텍스트 매칭
        - 링크: role=link + 텍스트 매칭
        - 입력: role=textbox 또는 role=combobox
     b) label/placeholder 매칭
        - aria-label, placeholder, title 속성에서 키워드 검색
     c) 텍스트 기반 매칭
        - 버튼/링크의 visible text에서 키워드 검색
     d) 전체 snapshot LLM 분석
        - 위 방법으로 결정 불가 시, 전체 snapshot 분석
        - 선택 이유를 RECORD에 기록
     e) 사용자 문의 (최후 수단)
        - 스크린샷 촬영 후 AskUserQuestion

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

  ## 종료 조건
  1. 모든 계획된 스텝이 성공적으로 완료됨
  2. 사용자가 '작업 중단' 선택
  3. 최대 스텝 수(PT_MAX_STEPS=30) 도달
  4. 최대 실행 시간(PT_WORKFLOW_TIMEOUT=300초) 초과
  5. 연속 3회 동일 스텝 실패 (무한 루프 감지)

  종료 시 항상:
  - 현재까지의 결과를 <SESSION_DIR>/test-results.json에 저장
  - 추출한 데이터를 <SESSION_DIR>/extracted-data.json에 저장
  - 마지막 스크린샷 촬영

  ## 예외 처리
  아래 '워크플로우 예외 처리' 섹션의 지침을 따른다."
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

---

## 워크플로우 예외 처리

### 1. 요소 찾기 실패

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

### 2. 예상 외 팝업/모달

```
감지: OBSERVE에서 이전과 다른 오버레이/모달 요소 감지
대응:
  1. 스크린샷 촬영
  2. AskUserQuestion:
     question: "예상 외 팝업이 나타났습니다."
     options: ["팝업 닫기 시도", "팝업 내용 확인 후 진행", "작업 중단"]
  3. "닫기 시도" → ESC 또는 닫기 버튼 클릭
```

### 3. 로그인/인증 필요

```
감지: OBSERVE에서 로그인 폼 (input[type=password]) 감지
대응:
  1. AskUserQuestion:
     question: "로그인이 필요한 페이지입니다."
     options: ["headed 모드로 전환 (수동 로그인)", "로그인 없이 접근 가능한 경로 탐색", "작업 중단"]
  2. headed 모드 전환 시 → bash bin/cch-pt cleanup + bash bin/cch-pt ensure false
```

### 4. 캡챠/봇 차단

```
감지: OBSERVE에서 "captcha", "robot", "자동화" 등 키워드 감지
대응:
  1. AskUserQuestion:
     question: "봇 차단/캡챠가 감지되었습니다."
     options: ["headed 모드로 전환 (수동 해결)", "다른 접근 방법 시도", "작업 중단"]
```

### 5. 타임아웃/네트워크 오류

```
감지: ACT 명령의 exit code != 0 또는 응답 없음
대응:
  1. 2초 대기 후 1회 재시도
  2. 재실패 시 → AskUserQuestion:
     question: "네트워크 오류 또는 타임아웃이 발생했습니다."
     options: ["재시도", "다른 URL 시도", "작업 중단"]
```

---

## 에러 처리

| 단계 | 실패 | 대응 |
|------|------|------|
| 입력 분석 | URL/파일 없음 | 사용법 안내 |
| pt-infra | 서버 시작 실패 | 에러 메시지 전달, 수동 조치 안내 |
| pt-test | 시나리오 파싱 실패 | YAML 오류 위치 안내 |
| pt-test | 테스트 실패 | on_failure 정책에 따라 계속/중단 |
| pt-report | 보고서 생성 실패 | CLI 출력으로 폴백 |
| 워크플로우 | 계획 생성 실패 | URL/의도 불명확 → 사용자에게 명확화 요청 |
| 워크플로우 | ref 결정 실패 | 재 snapshot → 전체 분석 → 사용자 문의 |
| 워크플로우 | 예상 외 팝업 | 스크린샷 + AskUserQuestion |
| 워크플로우 | 로그인/캡챠 | headed 모드 전환 제안 |
| 워크플로우 | 최대 스텝 초과 | 현재까지 결과 저장 후 중단 |

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| PT_PORT | 9867 | PinchTab 서버 포트 |
| PT_TIMEOUT | 30 | 요청 타임아웃 (초) |
| PT_MODE | headless | headed 또는 headless |
| PT_WORKFLOW_TIMEOUT | 300 | 워크플로우 전체 타임아웃 (초) |
| PT_MAX_STEPS | 30 | 워크플로우 최대 스텝 수 |
| PT_MAX_RETRIES | 3 | 단일 스텝 최대 재시도 수 |
