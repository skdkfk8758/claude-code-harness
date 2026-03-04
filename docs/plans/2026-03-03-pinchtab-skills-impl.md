# PinchTab Skills Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** PinchTab을 활용한 웹 UI 디버깅/테스트를 위한 4개 스킬과 헬퍼 스크립트, 시나리오 템플릿을 구현한다.

**Architecture:** 오케스트레이터 스킬(cch-pinchtab)이 3개 역할별 에이전트(pt-infra, pt-test, pt-report)를 서브에이전트로 순차 실행한다. 에이전트 간 상태는 /tmp 세션 디렉토리의 JSON 파일로 전달한다. PinchTab CLI/HTTP API를 bin/cch-pt 헬퍼 스크립트로 래핑하여 공통 사용한다.

**Tech Stack:** Bash (헬퍼 스크립트), YAML (시나리오), Markdown (스킬/보고서), PinchTab HTTP API, Claude Code Agent tool

**Design doc:** `docs/plans/2026-03-03-pinchtab-skills-design.md`

**Workflow rule:** 구현 시작 전 반드시 `docs/TODO.md`에 작업 항목을 등록한다. TODO 항목 번호를 커밋 메시지에 참조한다.

**TODO mapping:** #61~#69 (Phase PT)

---

### Task 0: TODO.md에 Phase PT 작업 항목 등록 (TODO #61~#69)

**Files:**
- Modify: `docs/TODO.md`

**Step 1: Phase PT 섹션 추가**

`docs/TODO.md`의 Phase 5 섹션 뒤에 Phase PT 섹션을 추가한다.
항목 #61~#69를 등록하고, 전체 항목 수와 Critical Path를 갱신한다.

**Step 2: 확인**

Run: `grep -c "Phase PT" docs/TODO.md`
Expected: 3 이상 (섹션 헤더, 의존성 요약, Critical Path)

**Step 3: Commit**

```bash
git add docs/TODO.md
git commit -m "docs: add Phase PT (PinchTab skills) to TODO #61~#69"
```

---

### Task 1: 디렉토리 구조 생성 (TODO #61)

**Files:**
- Create: `tests/pinchtab/scenarios/examples/.gitkeep`
- Create: `tests/pinchtab/reports/.gitkeep`
- Modify: `.gitignore` (reports 디렉토리 제외)

**Step 1: 디렉토리 생성**

```bash
mkdir -p tests/pinchtab/scenarios/examples
mkdir -p tests/pinchtab/reports
touch tests/pinchtab/scenarios/examples/.gitkeep
touch tests/pinchtab/reports/.gitkeep
```

**Step 2: .gitignore에 reports 추가**

`.gitignore` 파일에 다음을 추가:
```
# PinchTab test reports (generated)
tests/pinchtab/reports/*
!tests/pinchtab/reports/.gitkeep
```

**Step 3: 확인**

Run: `ls -la tests/pinchtab/scenarios/examples/ && ls -la tests/pinchtab/reports/`
Expected: 두 디렉토리에 .gitkeep 파일 존재

**Step 4: Commit**

```bash
git add tests/pinchtab/ .gitignore
git commit -m "chore: create pinchtab test directory structure"
```

---

### Task 2: bin/cch-pt 헬퍼 스크립트 작성 (TODO #62)

**Files:**
- Create: `bin/cch-pt`

**Step 1: 헬퍼 스크립트 작성**

```bash
#!/usr/bin/env bash
# bin/cch-pt — PinchTab 헬퍼 스크립트
# 스킬/에이전트가 공통으로 사용하는 PinchTab 래퍼
set -euo pipefail

PT_PORT="${PT_PORT:-9867}"
PT_HOST="http://localhost:${PT_PORT}"
PT_TIMEOUT="${PT_TIMEOUT:-30}"

_log() { echo "[cch-pt] $*" >&2; }

cmd_ensure() {
  local mode="${1:-true}"
  # 1. 설치 확인
  if ! command -v pinchtab &>/dev/null; then
    _log "pinchtab not found, installing via npm..."
    npm install -g pinchtab
  fi
  # 2. 서버 동작 확인
  if curl -sf "${PT_HOST}/health" &>/dev/null; then
    _log "PinchTab already running on port ${PT_PORT}"
    curl -sf "${PT_HOST}/health"
    return 0
  fi
  # 3. 서버 시작
  _log "Starting PinchTab (headless=${mode}, port=${PT_PORT})..."
  BRIDGE_HEADLESS="${mode}" BRIDGE_PORT="${PT_PORT}" pinchtab &
  local pid=$!
  # 4. 대기
  local retries=0
  while [ $retries -lt 10 ]; do
    sleep 1
    if curl -sf "${PT_HOST}/health" &>/dev/null; then
      _log "PinchTab ready (pid=${pid}, port=${PT_PORT})"
      curl -sf "${PT_HOST}/health"
      return 0
    fi
    retries=$((retries + 1))
  done
  _log "ERROR: PinchTab failed to start within 10 seconds"
  return 1
}

cmd_health() {
  if curl -sf "${PT_HOST}/health" 2>/dev/null; then
    return 0
  else
    _log "PinchTab is not running on port ${PT_PORT}"
    return 1
  fi
}

cmd_instances() {
  curl -sf "${PT_HOST}/instances" 2>/dev/null || echo "[]"
}

cmd_profiles() {
  curl -sf "${PT_HOST}/profiles" 2>/dev/null || echo "[]"
}

cmd_nav() {
  local tab_id="$1"
  local url="$2"
  local wait="${3:-3}"
  curl -sf -X POST "${PT_HOST}/tabs/${tab_id}/navigate" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"${url}\", \"timeout\": ${PT_TIMEOUT}}"
  [ "$wait" -gt 0 ] && sleep "$wait"
}

cmd_snap() {
  local tab_id="$1"
  local filter="${2:-}"
  local url="${PT_HOST}/tabs/${tab_id}/snapshot"
  [ -n "$filter" ] && url="${url}?filter=${filter}&format=compact"
  curl -sf "$url" 2>/dev/null
}

cmd_action() {
  local tab_id="$1"
  local payload="$2"
  curl -sf -X POST "${PT_HOST}/tabs/${tab_id}/action" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

cmd_text() {
  local tab_id="$1"
  curl -sf "${PT_HOST}/tabs/${tab_id}/text" 2>/dev/null
}

cmd_screenshot() {
  local tab_id="$1"
  local output="${2:-screenshot.png}"
  curl -sf "${PT_HOST}/tabs/${tab_id}/screenshot" -o "$output"
  echo "{\"saved\": \"${output}\"}"
}

cmd_new_tab() {
  local instance_id="$1"
  local url="${2:-}"
  local payload="{\"instanceId\": \"${instance_id}\""
  [ -n "$url" ] && payload="${payload}, \"url\": \"${url}\""
  payload="${payload}}"
  curl -sf -X POST "${PT_HOST}/tabs/new" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

cmd_start_instance() {
  local profile="${1:-}"
  local mode="${2:-headless}"
  local payload="{\"mode\": \"${mode}\""
  [ -n "$profile" ] && payload="${payload}, \"profileId\": \"${profile}\""
  payload="${payload}}"
  curl -sf -X POST "${PT_HOST}/instances/start" \
    -H "Content-Type: application/json" \
    -d "$payload"
}

cmd_stop_instance() {
  local instance_id="$1"
  curl -sf -X POST "${PT_HOST}/instances/${instance_id}/stop"
}

cmd_cleanup() {
  _log "Stopping all instances..."
  local instances
  instances=$(curl -sf "${PT_HOST}/instances" 2>/dev/null || echo "[]")
  echo "$instances" | jq -r '.[].id // empty' 2>/dev/null | while read -r id; do
    curl -sf -X POST "${PT_HOST}/instances/${id}/stop" &>/dev/null && _log "Stopped instance ${id}"
  done
  _log "Killing PinchTab server..."
  pkill -f "pinchtab" 2>/dev/null || true
  _log "Cleanup complete"
}

cmd_session_init() {
  local session_dir="/tmp/cch-pt-session-$(date +%s)"
  mkdir -p "${session_dir}/screenshots" "${session_dir}/snapshots"
  echo "$session_dir"
}

# --- Main ---
case "${1:-help}" in
  ensure)         cmd_ensure "${2:-true}" ;;
  health)         cmd_health ;;
  instances)      cmd_instances ;;
  profiles)       cmd_profiles ;;
  nav)            cmd_nav "$2" "$3" "${4:-3}" ;;
  snap)           cmd_snap "$2" "${3:-}" ;;
  action)         cmd_action "$2" "$3" ;;
  text)           cmd_text "$2" ;;
  screenshot)     cmd_screenshot "$2" "${3:-screenshot.png}" ;;
  new-tab)        cmd_new_tab "$2" "${3:-}" ;;
  start-instance) cmd_start_instance "${2:-}" "${3:-headless}" ;;
  stop-instance)  cmd_stop_instance "$2" ;;
  cleanup)        cmd_cleanup ;;
  session-init)   cmd_session_init ;;
  help|*)
    cat <<'USAGE'
Usage: cch-pt <command> [args...]

Lifecycle:
  ensure [headless]      Ensure PinchTab is installed and running
  health                 Check server health
  cleanup                Stop all instances and server

Instances:
  instances              List running instances
  start-instance [profile] [mode]  Start new instance
  stop-instance <id>     Stop an instance

Tabs:
  new-tab <instanceId> [url]  Create new tab
  nav <tabId> <url> [wait]    Navigate to URL
  snap <tabId> [filter]       Get page snapshot
  action <tabId> <json>       Execute action
  text <tabId>                Extract page text
  screenshot <tabId> [path]   Take screenshot

Session:
  session-init           Create temp session directory

Environment:
  PT_PORT    Server port (default: 9867)
  PT_TIMEOUT Request timeout in seconds (default: 30)
USAGE
    ;;
esac
```

**Step 2: 실행 권한 부여**

Run: `chmod +x bin/cch-pt`

**Step 3: 헬퍼 스크립트 테스트 — help 출력 확인**

Run: `bash bin/cch-pt help`
Expected: Usage 문서가 정상 출력됨

**Step 4: 헬퍼 스크립트 테스트 — health 체크**

Run: `bash bin/cch-pt health`
Expected: PinchTab이 실행 중이면 health JSON, 아니면 "not running" 메시지

**Step 5: Commit**

```bash
git add bin/cch-pt
git commit -m "feat: add cch-pt helper script for PinchTab operations"
```

---

### Task 3: cch-pt-infra 스킬 작성 (TODO #63)

**Files:**
- Create: `skills/cch-pt-infra/SKILL.md`

**Step 1: 스킬 파일 작성**

`skills/cch-pt-infra/SKILL.md` 내용:

````markdown
---
name: cch-pt-infra
description: PinchTab 서버 생명주기 및 인스턴스/프로필 관리
user-invocable: true
allowed-tools: Bash, Read, Write
---

# PinchTab Infrastructure Manager

PinchTab 서버의 설치, 시작, 상태 확인, 인스턴스/프로필 관리, 정리를 담당한다.

## 사전 조건

- Node.js/npm이 설치되어 있어야 한다
- Chrome 또는 Chromium이 시스템에 설치되어 있어야 한다

## 헬퍼 스크립트

모든 PinchTab 조작은 `bin/cch-pt` 래퍼를 통해 수행한다.

## 명령별 동작

### setup / ensure — 설치 및 서버 보장

```bash
# headless 모드 (기본)
bash bin/cch-pt ensure true

# headed 모드 (눈에 보이는 Chrome)
bash bin/cch-pt ensure false
```

1. `pinchtab` 설치 여부 확인, 미설치 시 `npm install -g pinchtab`
2. 서버 동작 여부 확인 (`/health`), 미실행 시 백그라운드로 시작
3. 최대 10초 대기 후 health check로 정상 확인
4. 실패 시 포트 충돌 가능성 안내

### status — 상태 확인

```bash
# health check
bash bin/cch-pt health

# 인스턴스 목록
bash bin/cch-pt instances

# 프로필 목록
bash bin/cch-pt profiles
```

사용자에게 다음을 보고한다:
- 서버 실행 여부 및 포트
- 활성 인스턴스 수 및 상태
- 등록된 프로필 목록

### instance — 인스턴스 관리

```bash
# 새 인스턴스 시작
bash bin/cch-pt start-instance "profile-name" "headed"

# 인스턴스 중지
bash bin/cch-pt stop-instance "instance-id"
```

### cleanup — 전체 정리

```bash
bash bin/cch-pt cleanup
```

모든 인스턴스 중지 후 서버 프로세스 종료.

## 오케스트레이터 연동

`cch-pinchtab` 오케스트레이터에서 호출될 때의 출력 형식:

```json
{
  "status": "ready",
  "port": 9867,
  "instanceId": "inst_abc123",
  "tabId": "tab_xyz789",
  "mode": "headed"
}
```

이 결과를 세션 디렉토리의 `infra-result.json`에 저장한다.

## 에러 처리

| 상황 | 대응 |
|------|------|
| pinchtab 미설치 | npm install -g pinchtab 자동 실행 |
| 서버 시작 실패 | 포트 충돌 확인 (`lsof -i :9867`), 대체 포트 안내 |
| health check 실패 | 3회 재시도 (2초 간격), 실패 시 로그 확인 안내 |
| Chrome 미설치 | 설치 가이드 안내 (brew install --cask chromium) |
````

**Step 2: 디렉토리 확인**

Run: `ls skills/cch-pt-infra/SKILL.md`
Expected: 파일 존재 확인

**Step 3: Commit**

```bash
git add skills/cch-pt-infra/
git commit -m "feat: add cch-pt-infra skill for PinchTab server management"
```

---

### Task 4: cch-pt-test 스킬 작성 (TODO #64)

**Files:**
- Create: `skills/cch-pt-test/SKILL.md`

**Step 1: 스킬 파일 작성**

`skills/cch-pt-test/SKILL.md` 내용:

````markdown
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
| navigate | `bash bin/cch-pt nav <tabId> <url> <wait>` |
| snapshot | `bash bin/cch-pt snap <tabId> <filter>` |
| click | `bash bin/cch-pt action <tabId> '{"kind":"click","ref":"<ref>"}'` |
| fill | `bash bin/cch-pt action <tabId> '{"kind":"type","ref":"<ref>","text":"<text>"}'` |
| press | `bash bin/cch-pt action <tabId> '{"kind":"press","key":"<key>"}'` |
| text | `bash bin/cch-pt text <tabId>` |
| screenshot | `bash bin/cch-pt screenshot <tabId> <output>` |
| evaluate | `curl -X POST .../tabs/<tabId>/evaluate -d '{"expression":"..."}'` |
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
````

**Step 2: 확인**

Run: `ls skills/cch-pt-test/SKILL.md`
Expected: 파일 존재 확인

**Step 3: Commit**

```bash
git add skills/cch-pt-test/
git commit -m "feat: add cch-pt-test skill for web UI test execution"
```

---

### Task 5: cch-pt-report 스킬 작성 (TODO #65)

**Files:**
- Create: `skills/cch-pt-report/SKILL.md`

**Step 1: 스킬 파일 작성**

`skills/cch-pt-report/SKILL.md` 내용:

````markdown
---
name: cch-pt-report
description: 테스트 결과 수집, 분석, Markdown 보고서 생성
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep
---

# PinchTab Test Reporter

테스트 실행 결과를 수집·분석하고, CLI 요약 출력 + Markdown 보고서를 생성한다.

## 입력

세션 디렉토리에서 다음 파일을 읽는다:
- `test-results.json` — pt-test가 생성한 실행 결과
- `screenshots/` — 캡처된 스크린샷
- `snapshots/` — 저장된 스냅샷 데이터

## CLI 요약 출력

테스트 완료 직후 콘솔에 요약을 출력한다:

```
═══════════════════════════════════════════
  PinchTab Test Report: naver-login-test
═══════════════════════════════════════════
  URL:      https://nid.naver.com
  Mode:     headed
  Duration: 12.3s
  Result:   4/6 PASSED, 1 FAILED, 1 SKIPPED
───────────────────────────────────────────
  ✅ [1] navigate → nid.naver.com (2.1s)
  ✅ [2] snapshot interactive (0.8s)
  ✅ [3] screenshot (0.5s)
  ✅ [4] fill e3 "test_user" (0.2s)
  ❌ [5] click e7 — ref e7 not found (0.3s)
  ⏭️ [6] snapshot (skipped)
───────────────────────────────────────────
  Report: tests/pinchtab/reports/naver-login-test/20260303-153000/report.md
═══════════════════════════════════════════
```

## Markdown 보고서 생성

`tests/pinchtab/reports/<scenario-name>/<timestamp>/report.md` 에 저장:

```markdown
# Test Report: <scenario-name>

- 실행일시: YYYY-MM-DD HH:MM:SS
- 대상 URL: <url>
- 모드: <mode>
- 총 소요시간: <duration>s

## 결과 요약

| # | 동작 | 결과 | 소요시간 | 비고 |
|---|------|------|---------|------|
| 1 | navigate → url | ✅ PASS | 2.1s | — |
| 2 | snapshot (interactive) | ✅ PASS | 0.8s | — |
| 5 | click e7 | ❌ FAIL | 0.3s | ref e7 not found |

**합계:** 4 passed / 1 failed / 1 skipped (총 6 steps)

## 실패 상세

### Step 5: click e7
- **원인:** ref e7 not found — 페이지 구조 변경 가능성
- **스크린샷:** ![step5-fail](step5-fail.png)
- **직전 스냅샷:** 마지막 성공 스냅샷의 interactive 요소 목록

## 스크린샷

| 파일명 | 설명 |
|--------|------|
| login-page.png | Step 3에서 촬영 |
| step5-fail.png | Step 5 실패 시 자동 촬영 |

## 시나리오 정보

- 파일: tests/pinchtab/scenarios/naver-login.yaml
- on_failure: continue
- screenshot_on_fail: true
```

## 실패 원인 분석

실패한 스텝에 대해 가능한 원인을 자동 분석:

| 실패 유형 | 분석 방법 |
|----------|----------|
| ref not found | 직전 snapshot의 ref 목록과 비교, 유사 ref 제안 |
| assert contains 실패 | 실제 텍스트에서 가장 유사한 문자열 표시 |
| navigate 타임아웃 | DNS/네트워크 문제 또는 서버 응답 지연 안내 |
| 빈 텍스트 | 페이지 로딩 미완료 가능성, wait 시간 증가 제안 |

## 보고서 저장 경로

```
tests/pinchtab/reports/
└── <scenario-name>/
    └── <YYYYMMDD-HHMMSS>/
        ├── report.md
        ├── test-results.json
        ├── login-page.png
        └── step5-fail.png
```

스크린샷은 세션 디렉토리에서 보고서 디렉토리로 복사한다.

## 오케스트레이터 연동

보고서 생성 완료 후 오케스트레이터에 반환:

```json
{
  "reportPath": "tests/pinchtab/reports/naver-login-test/20260303-153000/report.md",
  "summary": {"total": 6, "passed": 4, "failed": 1, "skipped": 1},
  "hasFailed": true
}
```
````

**Step 2: 확인**

Run: `ls skills/cch-pt-report/SKILL.md`
Expected: 파일 존재 확인

**Step 3: Commit**

```bash
git add skills/cch-pt-report/
git commit -m "feat: add cch-pt-report skill for test result analysis and reporting"
```

---

### Task 6: cch-pinchtab 오케스트레이터 스킬 작성 (TODO #66)

**Files:**
- Create: `skills/cch-pinchtab/SKILL.md`

**Step 1: 스킬 파일 작성**

`skills/cch-pinchtab/SKILL.md` 내용:

````markdown
---
name: cch-pinchtab
description: PinchTab 기반 웹 UI 디버깅/테스트 오케스트레이터
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit, TaskCreate, TaskUpdate, TaskList
---

# PinchTab Web UI Test Orchestrator

PinchTab을 활용한 웹 UI 디버깅/테스트의 진입점.
사용자의 자연어 요청 또는 YAML 시나리오 파일을 받아
인프라 준비 → 테스트 실행 → 결과 분석/보고를 자동으로 파이프라인 실행한다.

## 사용법

```
/cch-pinchtab <url> <자연어 테스트 요청>
/cch-pinchtab <scenario-file-path>
/cch-pinchtab --infra <status|start|stop|cleanup>
```

### 예시

```
/cch-pinchtab https://naver.com 로그인 폼이 정상 렌더링되는지 확인해줘
/cch-pinchtab tests/pinchtab/scenarios/naver-login.yaml
/cch-pinchtab --infra status
```

## 파이프라인 흐름

```
입력 분석 → 세션 초기화 → pt-infra → pt-test → pt-report → 결과 전달
```

### Step 0: 입력 분석

인자(ARGUMENTS)를 분석하여 모드를 결정한다:

1. **--infra 모드**: 인프라 관리만 수행 (status, start, stop, cleanup)
2. **시나리오 파일 모드**: `.yaml` 경로를 감지하면 시나리오 로드
3. **자연어 모드**: URL + 자연어 요청을 테스트 계획으로 변환

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
  1. bash bin/cch-pt ensure <headless여부> 실행
  2. 인스턴스 시작: bash bin/cch-pt start-instance '<profile>' '<mode>'
  3. 탭 생성: bash bin/cch-pt new-tab '<instanceId>' '<url>'
  4. 결과를 <SESSION_DIR>/infra-result.json 에 저장:
     {status, port, instanceId, tabId, mode}"
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

## 에러 처리

| 단계 | 실패 | 대응 |
|------|------|------|
| 입력 분석 | URL/파일 없음 | 사용법 안내 |
| pt-infra | 서버 시작 실패 | 에러 메시지 전달, 수동 조치 안내 |
| pt-test | 시나리오 파싱 실패 | YAML 오류 위치 안내 |
| pt-test | 테스트 실패 | on_failure 정책에 따라 계속/중단 |
| pt-report | 보고서 생성 실패 | CLI 출력으로 폴백 |

## 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| PT_PORT | 9867 | PinchTab 서버 포트 |
| PT_TIMEOUT | 30 | 요청 타임아웃 (초) |
| PT_MODE | headless | headed 또는 headless |
````

**Step 2: 확인**

Run: `ls skills/cch-pinchtab/SKILL.md`
Expected: 파일 존재 확인

**Step 3: Commit**

```bash
git add skills/cch-pinchtab/
git commit -m "feat: add cch-pinchtab orchestrator skill for web UI testing pipeline"
```

---

### Task 7: 시나리오 템플릿 및 예제 작성 (TODO #67)

**Files:**
- Create: `tests/pinchtab/scenarios/_template.yaml`
- Create: `tests/pinchtab/scenarios/examples/health-check.yaml`
- Create: `tests/pinchtab/scenarios/examples/form-test.yaml`

**Step 1: 템플릿 작성**

`tests/pinchtab/scenarios/_template.yaml`:

```yaml
# PinchTab 테스트 시나리오 템플릿
# 복사하여 새 시나리오를 작성하세요.

name: my-scenario
description: 시나리오 설명을 입력하세요
url: "https://target-url.com"

# 선택적 설정
# profile: profile-name       # PinchTab 프로필
# mode: headless               # headed | headless (기본: headless)
# on_failure: continue         # continue | stop | retry
# max_retries: 1
# retry_delay: 2               # 초
# screenshot_on_fail: true

# 변수 (steps에서 ${VAR_NAME}으로 참조)
# vars:
#   USERNAME: "testuser"
#   PASSWORD: "testpass"

steps:
  # 1. 페이지 이동
  - action: navigate
    url: "https://target-url.com"
    wait: 3

  # 2. 페이지 구조 확인
  - action: snapshot
    filter: interactive
    # assert:
    #   contains: ["기대하는 요소"]

  # 3. 스크린샷 촬영
  - action: screenshot
    output: page.png

  # 4. 텍스트 추출
  # - action: text
  #   assert:
  #     not_empty: true

  # 5. 요소 클릭
  # - action: click
  #   ref: e5

  # 6. 입력 필드 채우기
  # - action: fill
  #   ref: e3
  #   text: "입력값"

  # 7. 키 입력
  # - action: press
  #   key: Enter

  # 8. JavaScript 실행
  # - action: evaluate
  #   expression: "document.title"
  #   assert:
  #     equals: "기대하는 제목"

  # 9. 대기
  # - action: wait
  #   seconds: 3
```

**Step 2: health-check 예제 작성**

`tests/pinchtab/scenarios/examples/health-check.yaml`:

```yaml
name: health-check
description: 대상 URL 접근 가능 여부 및 기본 렌더링 확인
url: "${TARGET_URL}"
mode: headless
on_failure: stop
screenshot_on_fail: true

vars:
  TARGET_URL: "https://example.com"

steps:
  - action: navigate
    url: "${TARGET_URL}"
    wait: 3

  - action: text
    assert:
      not_empty: true

  - action: snapshot
    filter: interactive
    save: health-snapshot.json

  - action: screenshot
    output: health-check.png

  - action: evaluate
    expression: "document.readyState"
    assert:
      equals: "complete"
```

**Step 3: form-test 예제 작성**

`tests/pinchtab/scenarios/examples/form-test.yaml`:

```yaml
name: form-test
description: 폼 요소 탐색 및 입력/제출 테스트
url: "${TARGET_URL}"
mode: headed
on_failure: continue
screenshot_on_fail: true

vars:
  TARGET_URL: "https://httpbin.org/forms/post"

steps:
  - action: navigate
    url: "${TARGET_URL}"
    wait: 3

  - action: snapshot
    filter: interactive
    save: form-elements.json
    assert:
      contains: ["input", "submit"]

  - action: screenshot
    output: before-fill.png

  - action: text
    assert:
      not_empty: true

  - action: screenshot
    output: after-interaction.png
```

**Step 4: 확인**

Run: `ls tests/pinchtab/scenarios/_template.yaml tests/pinchtab/scenarios/examples/`
Expected: 3개 파일 존재 확인

**Step 5: Commit**

```bash
git add tests/pinchtab/scenarios/
git commit -m "feat: add pinchtab scenario template and examples"
```

---

### Task 8: 통합 확인 — PinchTab 서버 기동 및 헬퍼 테스트 (TODO #68, #69)

**Step 1: PinchTab 설치 및 버전 확인**

Run: `pinchtab version`
Expected: 버전 번호 출력 (0.7.6 이상)

**Step 2: 헬퍼로 서버 보장**

Run: `bash bin/cch-pt ensure true`
Expected: PinchTab 서버가 시작되고 health JSON 응답 출력

**Step 3: 인스턴스 목록 확인**

Run: `bash bin/cch-pt instances`
Expected: 빈 배열 `[]` 또는 실행 중인 인스턴스 목록

**Step 4: 정리**

Run: `bash bin/cch-pt cleanup`
Expected: "Cleanup complete" 메시지

**Step 5: 전체 스킬 목록 확인**

Run: `ls skills/cch-pinchtab/ skills/cch-pt-infra/ skills/cch-pt-test/ skills/cch-pt-report/`
Expected: 4개 디렉토리에 각각 SKILL.md 존재

**Step 6: 최종 Commit**

```bash
git add -A
git commit -m "test: verify pinchtab skill integration"
```
