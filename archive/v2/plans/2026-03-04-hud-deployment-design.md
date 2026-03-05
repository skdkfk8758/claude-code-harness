# Design: HUD Deployment Automation

> Created: 2026-03-04
> Status: draft

## Goal

CCH 플러그인 설치 시 statusline(HUD)이 자동으로 배포되도록 하여, 다른 시스템에서도 플러그인만 설치하면 HUD가 동작하게 한다.

## Context

### 현재 상태
- `cch-hud.mjs` (525줄) — `~/.claude/hud/`에만 존재, 레포에 없음
- `cch-hud-config.json` — 사용자 커스텀 설정
- `settings.json`의 `statusLine.command` — 절대경로 하드코딩
- `check-env.mjs` (SessionStart 훅) — 환경 체크만, HUD 관련 없음

### 문제
- HUD 파일이 전역 경로에만 있어 다른 시스템에서 CCH 설치 시 statusline 없음
- 버전 관리 불가, 업데이트 추적 불가

## Approach

### A+B 하이브리드: Setup 배포 + SessionStart 자동 업데이트

#### 1. 파일 구조 변경

```
claude-code-harness/
├── hud/                           # NEW: HUD 소스 디렉터리
│   ├── cch-hud.mjs               # HUD 스크립트 (소스 of truth)
│   └── cch-hud-config.default.json  # 기본 설정 템플릿
```

- `cch-hud.mjs`에 버전 상수 추가: `const CCH_HUD_VERSION = "0.2.0"`
- config는 `.default.json` 접미사로 — 설치 시에만 복사, 이후 사용자 소유

#### 2. `bin/cch` 변경

`cmd_setup()` 에 HUD 설치 단계 추가:

```
cmd_setup()
  ├── ... (기존 setup 단계)
  └── _install_hud()
       ├── mkdir -p ~/.claude/hud/
       ├── cp hud/cch-hud.mjs → ~/.claude/hud/cch-hud.mjs
       ├── if !exists config.json → cp default config
       └── _patch_settings_statusline()
            ├── 기존 statusLine 있으면 _statusLine_backup에 보존
            └── statusLine.command = "node $HOME/.claude/hud/cch-hud.mjs"
```

별도 서브커맨드 없이 `setup`에 통합 (YAGNI).

#### 3. Settings.json 패치 로직 (Node.js)

`bin/cch`가 bash이므로 JSON 조작은 `node -e` 인라인 사용:

```javascript
// 1. settings.json 읽기 (없으면 빈 객체)
// 2. 기존 statusLine이 CCH가 아니면 _statusLine_backup에 저장
// 3. statusLine 설정: { type: "command", command: "node <resolved-home>/.claude/hud/cch-hud.mjs", padding: 0 }
// 4. 저장
```

판별 기준: `command`에 `cch-hud.mjs`가 포함되어 있으면 CCH 설정으로 간주 → 백업 불필요.

#### 4. SessionStart 훅 변경 (`check-env.mjs`)

기존 `checkEnv()` 흐름에 HUD 버전 체크 추가:

```
checkEnv()
  ├── detectPlugins()
  ├── detectMcpServers()
  ├── checkHudVersion()          # NEW
  │    ├── 설치된 HUD 버전 추출 (CCH_HUD_VERSION)
  │    ├── 플러그인 소스 HUD 버전과 비교
  │    ├── 불일치 → 스크립트만 자동 복사 (config 건드리지 않음)
  │    └── 미설치 → 건너뜀 (setup 필요 안내)
  └── return { tier, plugins, mcpServers, hudStatus }
```

훅 출력에 HUD 상태 추가:
```
[CCH ENV] Tier 2 | Plugins: ... | HUD: updated (0.1.0 → 0.2.0)
```

#### 5. 버전 추적 메커니즘

HUD 스크립트 상단에:
```javascript
const CCH_HUD_VERSION = "0.2.0";  // bin/cch의 CCH_VERSION과 동기
```

버전 추출: 파일 내용에서 정규식으로 `CCH_HUD_VERSION\s*=\s*"([^"]+)"` 매치.
- Node.js에서 `readFileSync` + 정규식 (check-env.mjs)
- 별도 버전 파일 불필요 (YAGNI)

## Edge Cases

| 상황 | 동작 |
|------|------|
| 처음 설치 (statusLine 없음) | setup: HUD 복사 + statusLine 설정 |
| 다른 statusLine 이미 있음 | setup: `_statusLine_backup`에 백업 후 교체 |
| CCH HUD 이미 설치됨 | setup: 스크립트 덮어쓰기, config 보존 |
| 플러그인 업데이트 후 세션 | SessionStart: 버전 비교 → 스크립트만 자동 교체 |
| config 커스터마이징 | 절대 자동 덮어쓰지 않음 (setup도 미존재 시에만 복사) |
| HUD 미설치 상태로 세션 시작 | SessionStart: 경고만, 자동 설치 안 함 (`cch setup` 안내) |

## Risks

- **Settings.json 손상**: `node -e` JSON 처리로 안전하게. JSON.parse 실패 시 빈 객체로 시작하지 않고 에러 반환.
- **경로 문제**: `$HOME` 환경변수 의존. 훅에서는 `process.env.HOME` 사용.
- **훅 타임아웃**: check-env.mjs의 5s 타임아웃 내 파일 복사는 충분히 빠름.

## Acceptance Criteria

- [ ] `hud/` 디렉터리가 CCH 레포에 존재
- [ ] `cch setup` 실행 시 HUD 파일이 `~/.claude/hud/`에 배포됨
- [ ] `settings.json`에 statusLine이 자동 설정됨
- [ ] 기존 statusLine이 있으면 `_statusLine_backup`에 보존
- [ ] SessionStart 훅에서 HUD 버전 불일치 시 스크립트 자동 업데이트
- [ ] config.json은 자동으로 덮어쓰이지 않음
- [ ] 새 시스템에서 플러그인 설치 → `cch setup` → statusline 동작
