---
name: cch-pt-test
description: PinchTab API를 활용한 웹 UI 테스트 실행
user-invocable: true
allowed-tools: Bash, Read, Write, Glob
---

# PinchTab Test Runner

PinchTab HTTP API를 활용하여 웹 UI 테스트를 실행하는 에이전트.
YAML 시나리오 파일 또는 오케스트레이터가 생성한 테스트 계획을 받아 순차 실행한다.

## 사전 조건

- PinchTab 서버가 실행 중이어야 한다 (pt-infra가 보장)
- `infra-result.json`에서 tabId/instanceId를 읽는다

## 실행 방식

### A. YAML 시나리오 실행

```bash
# 시나리오 파일 경로를 받아 실행
# 파일 위치: tests/pinchtab/scenarios/*.yaml
```

시나리오 파일을 읽고, steps를 순차적으로 PinchTab API 호출로 변환하여 실행한다.

### B. 자연어 테스트 계획 실행

오케스트레이터가 자연어를 파싱하여 생성한 steps 배열을 JSON으로 전달받아 실행한다.

## 시나리오 YAML 형식

```yaml
name: scenario-name
description: 시나리오 설명
url: "https://target-url.com"
profile: profile-name        # 선택적
mode: headed                 # headed | headless (기본: headless)
on_failure: continue         # continue | stop | retry
max_retries: 1
retry_delay: 2               # 초
screenshot_on_fail: true

steps:
  - action: navigate
    url: "https://target-url.com/path"
    wait: 3                  # 네비게이션 후 대기 시간 (초)

  - action: snapshot
    filter: interactive      # interactive | 생략 시 전체
    save: snapshot.json      # 세션 디렉토리에 저장 (선택적)
    assert:
      contains: ["요소1", "요소2"]
      not_contains: ["오류"]

  - action: screenshot
    output: step-name.png

  - action: fill
    ref: e3
    text: "입력값"

  - action: click
    ref: e7

  - action: press
    key: Enter

  - action: text
    assert:
      not_empty: true
      contains: ["기대하는 텍스트"]

  - action: evaluate
    expression: "document.title"
    assert:
      equals: "기대하는 제목"

  - action: wait
    seconds: 3
```

변수 치환: `${VAR_NAME}` 형식으로 환경 변수 또는 시나리오 vars 섹션에서 치환

```yaml
vars:
  TARGET_URL: "https://example.com"
  USERNAME: "testuser"

steps:
  - action: navigate
    url: "${TARGET_URL}"
```

## 스텝 실행 로직

각 스텝을 다음과 같이 PinchTab API 호출로 변환:

| action | cch-pt 명령 |
|--------|------------|
| navigate | `bash bin/cch-pt nav <url> <wait> [tabId]` |
| snapshot | `bash bin/cch-pt snap <filter> [tabId]` |
| click | `bash bin/cch-pt click <ref> [tabId]` |
| fill | `bash bin/cch-pt fill <ref> <text> [tabId]` |
| type | `bash bin/cch-pt type <ref> <text> [tabId]` |
| press | `bash bin/cch-pt press <key> [tabId]` |
| text | `bash bin/cch-pt text [tabId]` |
| screenshot | `bash bin/cch-pt screenshot <output> [tabId]` |
| evaluate | `bash bin/cch-pt eval <expression> [tabId]` |
| wait | `sleep <seconds>` |

## Assert 로직

스냅샷/텍스트 결과에 대해 다음 검증을 수행:

- `contains: [...]` — 결과에 모든 문자열이 포함되어야 함
- `not_contains: [...]` — 결과에 어떤 문자열도 포함되지 않아야 함
- `not_empty: true` — 결과가 비어있지 않아야 함
- `equals: "..."` — 결과가 정확히 일치해야 함

검증은 `jq` 또는 `grep`으로 수행한다.

## 결과 출력

각 스텝 실행 후 결과를 CLI에 실시간 출력:

```
[1/6] navigate → https://example.com ... ✅ PASS (2.1s)
[2/6] snapshot (interactive) ... ✅ PASS (0.8s)
[3/6] screenshot → login-page.png ... ✅ PASS (0.5s)
[4/6] fill e3 "test_user" ... ✅ PASS (0.2s)
[5/6] click e7 ... ❌ FAIL (0.3s) — ref e7 not found
[6/6] snapshot (assert) ... ⏭️ SKIP (depends on step 5)
```

## 오케스트레이터 연동

실행 완료 후 세션 디렉토리에 `test-results.json` 저장:

```json
{
  "scenario": "scenario-name",
  "url": "https://example.com",
  "startedAt": "2026-03-03T15:30:00Z",
  "completedAt": "2026-03-03T15:30:12Z",
  "duration": 12.3,
  "steps": [
    {"index": 1, "action": "navigate", "status": "pass", "duration": 2.1},
    {"index": 2, "action": "snapshot", "status": "pass", "duration": 0.8},
    {"index": 5, "action": "click", "status": "fail", "error": "ref e7 not found", "screenshot": "step5-fail.png"}
  ],
  "summary": {"total": 6, "passed": 4, "failed": 1, "skipped": 1}
}
```

## 에러 처리

| 상황 | 대응 |
|------|------|
| navigate 타임아웃 | 30초 대기 후 실패 기록, on_failure 정책에 따라 진행 |
| ref 못 찾음 | 재 snapshot 후 1회 재시도, 실패 시 스크린샷 촬영 |
| assert 실패 | 기대값 vs 실제값 기록, 스크린샷 첨부 |
| 시나리오 파싱 오류 | YAML 문법 오류 위치와 내용 안내 |
| 변수 미정의 | 미치환 변수 목록 안내 후 중단 |
