---
name: cch-pt-report
description: 테스트/워크플로우 결과 수집, 분석, Markdown 보고서 생성
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep
---

# PinchTab Test & Workflow Reporter

테스트 또는 워크플로우 실행 결과를 수집·분석하고, CLI 요약 출력 + Markdown 보고서를 생성한다.

## 입력

세션 디렉토리에서 다음 파일을 읽는다:
- `test-results.json` — pt-test 또는 워크플로우 실행기가 생성한 실행 결과
- `extracted-data.json` — 워크플로우 모드에서 추출한 데이터 (선택적)
- `screenshots/` — 캡처된 스크린샷
- `snapshots/` — 저장된 스냅샷 데이터

## CLI 요약 출력

### 테스트 모드

테스트 완료 직후 콘솔에 요약을 출력한다:

```
═══════════════════════════════════════════
  PinchTab Test Report: <scenario-name>
═══════════════════════════════════════════
  URL:      <url>
  Mode:     <mode>
  Duration: <duration>s
  Result:   N/M PASSED, X FAILED, Y SKIPPED
───────────────────────────────────────────
  ✅ [1] navigate → <url> (Ns)
  ✅ [2] snapshot interactive (Ns)
  ❌ [5] click e7 — ref not found (Ns)
  ⏭️ [6] snapshot (skipped)
───────────────────────────────────────────
  Report: tests/pinchtab/reports/<name>/<timestamp>/report.md
═══════════════════════════════════════════
```

### 워크플로우 모드

`extracted-data.json`이 존재하면 워크플로우 형식으로 출력한다:

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
| 1 | navigate | ✅ PASS | 2.1s | — |
| 5 | click e7 | ❌ FAIL | 0.3s | ref not found |

**합계:** N passed / X failed / Y skipped (총 M steps)

## 실패 상세

### Step N: <action>
- **원인:** <error message>
- **스크린샷:** ![fail](stepN-fail.png)
- **직전 스냅샷:** 마지막 성공 스냅샷의 interactive 요소 목록

## 추출 데이터

extracted-data.json이 존재하는 경우 이 섹션을 추가한다:

| 항목 | 값 |
|------|-----|
| 키워드 | <search keyword> |
| 결과 수 | <N>건 |

### 상세 데이터

1. **<title 1>** — <description> ...
2. **<title 2>** — <description> ...

> 원본 데이터: `extracted-data.json`

## 스크린샷

| 파일명 | 설명 |
|--------|------|
| page.png | Step N에서 촬영 |
| stepN-fail.png | 실패 시 자동 촬영 |

## 시나리오 정보

- 파일: <scenario-path>
- on_failure: <policy>
- screenshot_on_fail: <bool>
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
└── <name>/
    └── <YYYYMMDD-HHMMSS>/
        ├── report.md
        ├── test-results.json
        ├── extracted-data.json    ← 워크플로우 모드 시 추가
        └── *.png (스크린샷)
```

스크린샷은 세션 디렉토리에서 보고서 디렉토리로 복사한다.

## 오케스트레이터 연동

보고서 생성 완료 후 오케스트레이터에 반환:

```json
{
  "reportPath": "tests/pinchtab/reports/<name>/<timestamp>/report.md",
  "summary": {"total": 6, "passed": 4, "failed": 1, "skipped": 1},
  "hasFailed": true,
  "hasExtractedData": true,
  "extractedDataPath": "<session_dir>/extracted-data.json"
}
```
