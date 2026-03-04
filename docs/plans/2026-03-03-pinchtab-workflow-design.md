# PinchTab 워크플로우 실행 스킬 설계

- 생성일: 2026-03-03
- 상태: approved
- 선행 설계: `docs/plans/2026-03-03-pinchtab-skills-design.md`

## 배경

기존 cch-pinchtab 스킬 세트(pt-infra, pt-test, pt-report)는 YAML 시나리오 또는
정형화된 테스트 계획 기반으로 동작한다. 사용자가 자연어로 워크플로우를 요청했을 때
(예: "네이버에서 부동산 검색해서 래미안 아파트 찾아줘") 이를 자동으로 계획하고
적응적으로 실행하는 기능을 cch-pinchtab 오케스트레이터에 확장한다.

## 요구사항 요약

| 항목 | 결정 |
|------|------|
| 실행 모드 | 하이브리드 (계획 승인 후 자동, 예외 시 사용자 개입) |
| 결과 활용 | 텍스트 + 스크린샷 + 데이터 추출 + UI 테스트 + 성능 확인 |
| 예외 처리 | 사용자에게 물어보기 (AskUserQuestion + 스크린샷) |
| 스킬 관계 | 기존 cch-pinchtab 확장 (별도 스킬 아님) |
| 접근 방식 | 방식 C: 계획 + 적응형 실행 하이브리드 |

## 아키텍처

### 4단계 파이프라인

```
┌─────────────────────────────────────────────────────┐
│  사용자 입력                                          │
│  "네이버에서 부동산 검색해서 래미안 아파트 찾아줘"       │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────▼────────────┐
          │  Phase 1: PLAN          │
          │  · 의도 분석             │
          │  · URL 추론              │
          │  · 대략적 스텝 생성       │
          │  · 사용자 승인            │
          └────────────┬────────────┘
                       │ 승인
          ┌────────────▼────────────┐
          │  Phase 2: INFRA         │
          │  · pt-infra 에이전트     │
          │  · PinchTab 서버 보장    │
          │  · 탭 생성               │
          └────────────┬────────────┘
                       │
          ┌────────────▼────────────┐
          │  Phase 3: EXECUTE       │
          │  · 적응형 실행 루프       │
          │  · OBSERVE-THINK-ACT    │
          │  · 예외 시 사용자 개입    │
          └────────────┬────────────┘
                       │
          ┌────────────▼────────────┐
          │  Phase 4: REPORT        │
          │  · pt-report 에이전트    │
          │  · CLI 요약 + MD 보고서  │
          │  · 데이터 파일 저장       │
          └─────────────────────────┘
```

### Phase 1: PLAN — 자연어 → 실행 계획 변환

오케스트레이터가 직접 수행한다 (서브에이전트 불필요).

**입력 파싱:**
- `<URL> <자연어>` → URL 명시 모드
- `<자연어만>` → URL 추론 모드 (문맥에서 사이트 추출)

**계획 생성 규칙:**
1. 목표를 1~2문장으로 요약
2. 필요한 스텝을 순서대로 나열 (navigate, snapshot, fill, click, press 등)
3. 각 스텝에 예상 동작과 성공 기준 명시
4. ref 값은 `<dynamic>` 표기 — 실행 시 snapshot에서 동적 결정

**사용자에게 계획 제시 → 승인/수정 후 실행:**

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
```

### Phase 2: INFRA — 인프라 준비

기존 pt-infra 에이전트를 그대로 활용한다.

```
Agent(subagent_type="general-purpose")
프롬프트: skills/cch-pt-infra/SKILL.md 지침에 따라:
  1. bash bin/cch-pt ensure true
  2. bash bin/cch-pt new-tab '<url>'
  3. 결과를 <SESSION_DIR>/infra-result.json 에 저장
```

### Phase 3: EXECUTE — 적응형 실행 루프

Phase 3의 핵심 차별점: 고정된 ref 값 대신 매 스텝마다 관찰 → 판단 → 행동 사이클을 수행한다.

### Phase 4: REPORT — 결과 보고

기존 pt-report 에이전트를 확장하여 데이터 추출 결과도 포함한다.

---

## 적응형 실행 루프 (OBSERVE-THINK-ACT-VERIFY-RECORD)

### 프로토콜

각 스텝은 5단계 사이클로 실행된다:

```
┌──────────┐
│ OBSERVE  │─── snapshot/text로 현재 상태 파악
└────┬─────┘
     │
┌────▼─────┐
│  THINK   │─── 계획의 다음 동작에 필요한 ref/요소 결정
└────┬─────┘
     │
┌────▼─────┐
│   ACT    │─── click, fill, press, nav 등 실행
└────┬─────┘
     │
┌────▼─────┐
│  VERIFY  │─── 기대 결과 확인 (snapshot/text/screenshot)
└────┬─────┘
     │
┌────▼─────┐
│  RECORD  │─── 결과 + 성능 메트릭 기록
└──────────┘
```

### OBSERVE: 상태 파악

```bash
# 인터랙티브 요소 스냅샷
bash bin/cch-pt snap interactive [tabId]

# 필요 시 전체 텍스트
bash bin/cch-pt text [tabId]
```

### THINK: Ref 결정 전략 (Adaptive Resolution)

LLM이 snapshot 결과를 분석하여 올바른 요소를 찾는다:

```
우선순위:
1. role 기반: role="search", role="button" 등
2. label 기반: "검색", "로그인" 등 텍스트 매칭
3. 전체 snap + LLM 판단: 위 방법으로 안 되면 전체 스냅샷 분석
4. 사용자 문의: 모든 방법 실패 시 스크린샷 + AskUserQuestion
```

### ACT: 동작 실행

```bash
bash bin/cch-pt fill <ref> "검색어" [tabId]
bash bin/cch-pt click <ref> [tabId]
bash bin/cch-pt press Enter [tabId]
bash bin/cch-pt nav <url> 3 [tabId]
```

### VERIFY: 결과 확인

```bash
# 페이지 변화 확인
bash bin/cch-pt snap diff [tabId]

# 텍스트 내용 확인
bash bin/cch-pt text [tabId]

# 시각적 증거 보존
bash bin/cch-pt screenshot <session_dir>/screenshots/step-N.png [tabId]
```

### RECORD: 결과 기록

각 스텝의 실행 결과를 JSON으로 기록:

```json
{
  "step": 3,
  "action": "fill",
  "target": "e5 (검색창)",
  "value": "부동산",
  "status": "pass",
  "duration": 0.3,
  "performance": {
    "observe_ms": 850,
    "think_ms": 200,
    "act_ms": 300,
    "verify_ms": 500
  }
}
```

### 예외 감지 및 처리

| 예외 유형 | 감지 방법 | 대응 |
|-----------|----------|------|
| 요소 못 찾음 | THINK에서 ref 결정 실패 | 재 snapshot → 전체 분석 → 사용자 문의 |
| 페이지 변화 없음 | VERIFY에서 diff가 empty | 재시도 1회 → 실패 시 사용자 문의 |
| 예상 외 팝업/모달 | OBSERVE에서 예상 외 요소 감지 | 스크린샷 + 사용자에게 처리 방법 문의 |
| 네비게이션 실패 | ACT 후 URL 미변경 | 재시도 → 대안 URL 시도 → 사용자 문의 |
| 로그인/인증 필요 | OBSERVE에서 로그인 폼 감지 | 사용자에게 로그인 필요 안내 + headed 모드 전환 제안 |
| 캡챠/봇 차단 | OBSERVE에서 캡챠 감지 | headed 모드 전환 + 사용자 수동 해결 요청 |

**사용자 문의 형식:**

```
AskUserQuestion:
  question: "검색 결과 페이지에서 '래미안' 관련 항목을 찾지 못했습니다.
             현재 페이지 상태를 확인해주세요."
  options:
    - "다른 키워드로 재검색"
    - "현재 결과에서 스크롤하여 탐색"
    - "작업 중단"
  첨부: screenshot (현재 페이지 캡처)
```

### 최대 반복 제한

- 단일 스텝 재시도: 최대 3회
- 전체 실행 루프: 최대 30 스텝 (무한 루프 방지)
- 총 실행 시간: 최대 5분 (PT_WORKFLOW_TIMEOUT 환경변수로 조정 가능)

---

## 결과 보고

### CLI 실시간 출력

```
[Workflow] 네이버에서 부동산 검색 → 래미안 아파트 찾기
──────────────────────────────────────────

[1/8] navigate → https://www.naver.com ... ✅ (2.1s)
[2/8] snapshot (interactive) → 검색창 발견 (e5) ... ✅ (0.8s)
[3/8] fill e5 "부동산" ... ✅ (0.3s)
[4/8] press Enter ... ✅ (0.2s)
[5/8] snapshot → 검색 결과 로드 확인 ... ✅ (3.2s)
[6/8] text → "래미안" 포함 확인 ... ✅ (0.5s)
[7/8] 추가 탐색 → 래미안 관련 링크 클릭 ... ✅ (1.8s)
[8/8] screenshot → 결과 저장 ... ✅ (0.4s)

──────────────────────────────────────────
✅ 완료 | 8/8 성공 | 총 9.3초

📊 추출 데이터:
  - 래미안 관련 검색 결과 5건 발견
  - 첫 번째 결과: "래미안 원펜타스 - 분양정보"

📁 보고서: tests/pinchtab/reports/naver-search/20260303-153012/report.md
📸 스크린샷: 8장 저장됨
```

### 데이터 추출 결과

워크플로우에서 추출한 데이터를 구조화하여 저장:

```json
// <SESSION_DIR>/extracted-data.json
{
  "workflow": "네이버에서 부동산 검색 → 래미안 아파트 찾기",
  "url": "https://www.naver.com",
  "extractedAt": "2026-03-03T15:30:12Z",
  "data": {
    "searchResults": [
      {"title": "래미안 원펜타스", "url": "...", "description": "..."},
      {"title": "래미안 라클래시", "url": "...", "description": "..."}
    ],
    "totalResults": 5,
    "keyword": "부동산"
  }
}
```

### Markdown 보고서

기존 pt-report 형식을 확장하여 워크플로우 컨텍스트 추가:

```markdown
# Workflow Report: 네이버 부동산 검색

## 요약
- 목표: 네이버에서 "부동산" 검색하여 래미안 아파트 찾기
- 결과: ✅ 성공
- 소요 시간: 9.3초
- 실행 스텝: 8/8 성공

## 실행 타임라인
| # | 동작 | 대상 | 결과 | 시간 |
|---|------|------|------|------|
| 1 | navigate | naver.com | ✅ | 2.1s |
| 2 | snapshot | interactive | ✅ | 0.8s |
| ... | ... | ... | ... | ... |

## 추출 데이터
[구조화된 검색 결과]

## 스크린샷
[각 스텝 스크린샷 임베드]

## 성능 메트릭
- 평균 스텝 시간: 1.16초
- 가장 느린 스텝: snapshot (3.2초)
- ref 결정 성공률: 100%
```

### 보고서 저장 경로

```
tests/pinchtab/reports/<workflow-name>/<timestamp>/
├── report.md
├── extracted-data.json
├── test-results.json
└── screenshots/
    ├── step-1-navigate.png
    ├── step-5-results.png
    └── step-8-final.png
```

---

## cch-pinchtab 확장 사항

### 추가되는 입력 모드

기존 3가지 모드에 워크플로우 모드를 추가:

| 모드 | 트리거 | 동작 |
|------|--------|------|
| --infra | `--infra` 플래그 | 인프라 관리만 |
| 시나리오 | `.yaml` 경로 | YAML 시나리오 실행 |
| 자연어 테스트 | URL + "확인/테스트/검증" | 정형 테스트 계획 → 실행 |
| **워크플로우** | URL + "찾아줘/해줘/검색" 또는 자연어만 | **적응형 실행 루프** |

### 모드 판별 로직

```
입력 분석:
1. --infra → 인프라 모드
2. .yaml 경로 → 시나리오 모드
3. "테스트/확인/검증" 키워드 → 자연어 테스트 모드 (기존)
4. "찾아줘/해줘/검색/알려줘" 키워드 → 워크플로우 모드 (신규)
5. 판별 불가 → LLM이 의도 분석하여 결정
```

### 워크플로우 모드의 에이전트 활용

```
Agent(subagent_type="oh-my-claudecode:deep-executor")
프롬프트: "<SESSION_DIR>/workflow-plan.json 을 읽고,
  skills/cch-pt-test/SKILL.md 의 명령 체계를 활용하되
  OBSERVE-THINK-ACT-VERIFY-RECORD 프로토콜에 따라
  적응적으로 실행하라.

  각 스텝에서:
  1. OBSERVE: bash bin/cch-pt snap interactive [tabId]
  2. THINK: snapshot에서 필요한 요소 ref 결정
  3. ACT: bash bin/cch-pt <action> <args> [tabId]
  4. VERIFY: bash bin/cch-pt snap diff [tabId] 또는 text
  5. RECORD: 결과를 JSON에 누적

  예외 발생 시 AskUserQuestion으로 사용자에게 문의.
  완료 후 <SESSION_DIR>/test-results.json 에 결과 저장."
```

---

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| PT_PORT | 9867 | PinchTab 서버 포트 |
| PT_TIMEOUT | 30 | 요청 타임아웃 (초) |
| PT_MODE | headless | headed 또는 headless |
| PT_WORKFLOW_TIMEOUT | 300 | 워크플로우 전체 타임아웃 (초) |
| PT_MAX_STEPS | 30 | 워크플로우 최대 스텝 수 |
| PT_MAX_RETRIES | 3 | 단일 스텝 최대 재시도 수 |

## 검증 체크리스트

- [ ] 자연어 → 워크플로우 계획 변환
- [ ] 사용자 계획 승인 흐름
- [ ] OBSERVE-THINK-ACT-VERIFY-RECORD 사이클 동작
- [ ] 적응형 ref 결정 (role → label → full snap → user)
- [ ] 예외 감지 및 사용자 문의
- [ ] 데이터 추출 결과 JSON 저장
- [ ] CLI 실시간 출력
- [ ] Markdown 보고서 생성
- [ ] 성능 메트릭 수집
- [ ] 최대 반복/시간 제한 동작
