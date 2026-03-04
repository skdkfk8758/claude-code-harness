# PinchTab Web UI 디버깅/테스트 스킬 설계

- 생성일: 2026-03-03
- 상태: approved

## 배경

PinchTab(브라우저 자동화 HTTP 서버)을 도구로 활용하여 임의의 웹사이트 UI를 디버깅/테스트하는
스킬 세트와 역할별 분리 에이전트를 claude-code-harness에 추가한다.

## 요구사항 요약

| 항목 | 결정 |
|------|------|
| 대상 | PinchTab을 도구로 활용한 임의 웹사이트 UI 테스트 |
| 테스트 유형 | E2E 시나리오 + 시각적 검증 + 데이터 추출/모니터링 (종합) |
| 사용 방식 | 자연어 대화형 + YAML 시나리오 파일 병행 |
| 에이전트 | 역할별 분리 (인프라 관리 / 테스트 실행 / 결과 분석) |
| 결과 형식 | CLI 실시간 출력 + Markdown 보고서 자동 생성 |
| 접근 방식 | 스킬 중심 설계 (방식 A) |

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│  사용자                                                  │
│  "네이버 로그인 테스트해줘" 또는 scenarios/naver-login.yaml│
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  /cch-pinchtab        │  ← 오케스트레이터 (진입점)
         │  · 자연어 파싱         │
         │  · 시나리오 파일 로드   │
         │  · 파이프라인 조율      │
         └───┬───────┬───────┬───┘
             │       │       │
     ┌───────▼──┐ ┌──▼─────┐ ┌▼──────────┐
     │ pt-infra │ │pt-test │ │ pt-report │
     │          │ │        │ │           │
     │·서버시작 │ │·nav    │ │·스크린샷  │
     │·health   │ │·snap   │ │·diff 분석 │
     │·인스턴스 │ │·click  │ │·MD 보고서 │
     │·프로필   │ │·fill   │ │·타임라인  │
     │·정리     │ │·assert │ │·요약 통계 │
     └──────────┘ └────────┘ └───────────┘
             │       │       │
         ┌───▼───────▼───────▼───┐
         │  PinchTab (port 9867) │
         │  CLI / HTTP API       │
         └───────────────────────┘
```

## 스킬 상세

### 1. cch-pinchtab — 오케스트레이터

```yaml
name: cch-pinchtab
description: PinchTab 기반 웹 UI 디버깅/테스트 오케스트레이터
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskList
```

동작 흐름:
1. 입력 분석 — 자연어 요청 vs 시나리오 파일 경로 판별
2. 시나리오 파일이면 `tests/pinchtab/scenarios/*.yaml` 로드
3. 자연어면 테스트 계획을 자동 생성 후 사용자 승인
4. pt-infra 에이전트 호출 → PinchTab 준비 확인
5. pt-test 에이전트 호출 → 테스트 실행
6. pt-report 에이전트 호출 → 결과 분석 및 보고서 생성

사용 예시:
```
/cch-pinchtab https://naver.com 로그인 폼이 정상 렌더링되는지 확인해줘
/cch-pinchtab tests/pinchtab/scenarios/naver-login.yaml
/cch-pinchtab --infra status
```

### 2. cch-pt-infra — 인프라 관리 에이전트

```yaml
name: cch-pt-infra
description: PinchTab 서버 생명주기 및 인스턴스/프로필 관리
user-invocable: true
allowed-tools: Bash, Read, Write
```

| 명령 | 동작 |
|------|------|
| setup | PinchTab 설치 여부 확인, 미설치 시 npm install -g pinchtab |
| start | 서버 시작 (pinchtab &), headed/headless 모드 선택 |
| stop | 서버 중지 |
| status | health check (/health), 인스턴스 목록, 포트 확인 |
| profile | 프로필 생성/목록/삭제 |
| cleanup | 모든 인스턴스 정리, 서버 중지 |

### 3. cch-pt-test — 테스트 실행 에이전트

```yaml
name: cch-pt-test
description: PinchTab API를 활용한 웹 UI 테스트 실행
user-invocable: true
allowed-tools: Bash, Read, Write, Glob
```

지원 테스트 유형:

| 유형 | PinchTab API |
|------|-------------|
| Navigate | /tabs/{id}/navigate |
| Snapshot | /tabs/{id}/snapshot |
| Action | /tabs/{id}/action |
| Assert | /tabs/{id}/text, /tabs/{id}/snapshot |
| Screenshot | /tabs/{id}/screenshot |
| Extract | /tabs/{id}/text, /tabs/{id}/evaluate |
| Monitor | 위 API 조합 반복 |

### 4. cch-pt-report — 결과 분석/보고 에이전트

```yaml
name: cch-pt-report
description: 테스트 결과 수집, 분석, 보고서 생성
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep
```

보고서 저장 경로: `tests/pinchtab/reports/<scenario-name>/<timestamp>/`

## 시나리오 YAML 형식

```yaml
name: scenario-name
description: 시나리오 설명
url: "https://target-url.com"
profile: profile-name        # 선택적
mode: headed                 # headed | headless
on_failure: continue         # continue | stop | retry
max_retries: 1
retry_delay: 2
screenshot_on_fail: true

steps:
  - action: navigate
    url: "https://target-url.com/path"
    wait: 3

  - action: snapshot
    filter: interactive
    assert:
      contains: ["요소1", "요소2"]

  - action: screenshot
    output: step-name.png

  - action: fill
    ref: e3
    text: "입력값"

  - action: click
    ref: e7

  - action: snapshot
    assert:
      not_contains: ["오류"]
```

변수 치환 지원: `${TARGET_URL}`, `${INPUT_REF}`, `${INPUT_VALUE}`

## 디렉토리 구조

```
claude-code-harness/
├── skills/
│   ├── cch-pinchtab/SKILL.md
│   ├── cch-pt-infra/SKILL.md
│   ├── cch-pt-test/SKILL.md
│   └── cch-pt-report/SKILL.md
├── tests/pinchtab/
│   ├── scenarios/
│   │   ├── _template.yaml
│   │   └── examples/
│   │       ├── health-check.yaml
│   │       └── form-test.yaml
│   └── reports/ (.gitignored)
├── bin/cch-pt                    # PinchTab 래퍼 스크립트
└── docs/plans/2026-03-03-pinchtab-skills-design.md
```

## 에이전트 연동

오케스트레이터가 서브에이전트를 순차 실행:

| 단계 | 서브에이전트 타입 | 역할 |
|------|------------------|------|
| 1 | general-purpose | pt-infra: PinchTab 설치/시작/상태확인 |
| 2 | oh-my-claudecode:qa-tester | pt-test: 시나리오 실행 |
| 3 | oh-my-claudecode:scientist | pt-report: 결과 분석/보고서 생성 |

상태 전달: `/tmp/cch-pt-session-<timestamp>/` 임시 디렉토리로 JSON 파일 교환

## 에러 처리

| 단계 | 실패 상황 | 대응 |
|------|----------|------|
| pt-infra | pinchtab 미설치 | npm install -g pinchtab 자동 설치 |
| pt-infra | 서버 시작 실패 | 포트 충돌 확인 → 대체 포트 시도 |
| pt-infra | health check 실패 | 3회 재시도 (2초 간격) |
| pt-test | navigate 타임아웃 | 30초 대기 후 실패 기록 |
| pt-test | ref 못 찾음 | 재 snapshot 후 재시도 1회 |
| pt-test | assert 실패 | 실패 상세 + 스크린샷 기록 |
| pt-report | 보고서 생성 실패 | CLI 출력으로 폴백 |

## 검증 체크리스트

### pt-infra
- [ ] pinchtab 미설치 상태에서 자동 설치
- [ ] 서버 시작/중지 정상 동작
- [ ] health check 정상 응답
- [ ] 포트 충돌 시 대체 포트

### pt-test
- [ ] YAML 시나리오 파일 정상 파싱
- [ ] 자연어 → 테스트 계획 변환
- [ ] navigate/snapshot/action/assert 각 스텝 동작
- [ ] 실패 시 스크린샷 자동 촬영
- [ ] 변수 치환 동작

### pt-report
- [ ] Markdown 보고서 정상 생성
- [ ] 스크린샷 경로 연결
- [ ] CLI 요약 출력
- [ ] 실패 원인 분석 포함

### cch-pinchtab (오케스트레이터)
- [ ] 자연어 요청 → 파이프라인 정상 실행
- [ ] 시나리오 파일 → 파이프라인 정상 실행
- [ ] --infra 서브커맨드 동작
- [ ] 에이전트 간 상태 전달 정상
