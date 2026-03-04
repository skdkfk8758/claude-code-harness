---
name: cch-hud
description: View and configure CCH HUD statusline. Show status, toggle elements, switch presets.
user-invocable: true
allowed-tools: Bash, Read, Glob, Write, Edit
argument-hint: [status|config|reset|element <name> on|off]
---

# CCH HUD - Statusline 설정 관리

CCH 프레임워크 통합 HUD 상태 확인 및 설정을 관리합니다.

## Quick Reference

| 명령 | 설명 |
|------|------|
| `/cch-hud` | 현재 HUD 상태 표시 |
| `/cch-hud status` | 상세 상태 + 설정값 표시 |
| `/cch-hud config` | 현재 설정 JSON 출력 |
| `/cch-hud element <name> on\|off` | 개별 요소 토글 |
| `/cch-hud reset` | 기본 설정으로 초기화 |

## 아키텍처

```
settings.json (statusLine.command)
    → cch-hud.mjs (진입점)
        ├─ CCH State Layer (.claude/cch/*)
        │   ├─ mode (plan/code/tool/swarm)
        │   ├─ health (Healthy/Degraded/Blocked)
        │   ├─ .beads/ (Beads SSOT)
        │   └─ dot_enabled (DOT 실험 상태)
        │
        ├─ Token Usage Layer (OMC usage-api)
        │   ├─ 5h: 5시간 롤링 윈도우 사용량 (바 차트)
        │   └─ wk: 주간 사용량 (바 차트 + 리셋 시간)
        │
        └─ OMC HUD Layer (chain)
            └─ context, agents, bg tasks, etc.
```

## Steps

### 인자 없음 또는 `status` — 상태 표시

1. `~/.claude/hud/cch-hud-config.json` 읽기
2. `~/.claude/.omc/hud-config.json` 읽기
3. `~/.claude/settings.json`에서 `statusLine` 설정 확인
4. `~/.claude/hud/cch-hud.mjs` 존재 확인
5. `~/.claude/hud/omc-hud.mjs` 존재 확인

아래 형식으로 출력:

```
## CCH HUD 상태

| 항목 | 상태 |
|------|------|
| cch-hud.mjs | OK / MISSING |
| omc-hud.mjs | OK / MISSING |
| statusLine 설정 | OK (cch-hud.mjs) / 미설정 |
| CCH 설정 파일 | OK / MISSING |
| OMC 설정 파일 | OK / MISSING |

### CCH 표시 요소
| 요소 | 상태 |
|------|------|
| showMode | on/off |
| showHealth | on/off |
| showWorkItem | on/off |
| showDot | on/off |
| showPhase | on/off |
| showTokenUsage | on/off |
| chainOmcHud | on/off |

### OMC HUD 프리셋
현재: dense (contextWarning: 65%, contextCritical: 85%)
```

### `config` — 설정 JSON 출력

1. `~/.claude/hud/cch-hud-config.json` 전체 내용 출력
2. `~/.claude/.omc/hud-config.json` 전체 내용 출력

### `element <name> on|off` — 개별 요소 토글

설정 가능한 CCH 요소:

| 요소명 | 설명 | 기본값 |
|--------|------|--------|
| `showMode` | CCH 모드 표시 (plan/code/tool/swarm) | on |
| `showHealth` | 헬스 상태 표시 | on |
| `showBead` | 활성 bead 표시 | on |
| `showDot` | DOT 실험 상태 표시 | on |
| `showPhase` | Phase 진행률 표시 | off |
| `showTokenUsage` | 5h/주간 토큰 사용량 바 차트 | on |
| `chainOmcHud` | OMC HUD 체이닝 | on |

1. `~/.claude/hud/cch-hud-config.json` 읽기
2. 해당 요소의 값을 `true`/`false`로 변경
3. 파일 저장
4. 변경 결과 보고 (재시작 필요 안내)

### `reset` — 기본 설정 초기화

1. `~/.claude/hud/cch-hud-config.json`을 기본값으로 덮어쓰기:

```json
{
  "showMode": true,
  "showHealth": true,
  "showWorkItem": true,
  "showDot": true,
  "showPhase": false,
  "showTokenUsage": true,
  "chainOmcHud": true,
  "cchStateDir": ".claude/cch"
}
```

2. 초기화 완료 보고

## 파일 경로

| 파일 | 설명 |
|------|------|
| `~/.claude/hud/cch-hud.mjs` | CCH HUD 메인 스크립트 |
| `~/.claude/hud/omc-hud.mjs` | OMC HUD 래퍼 스크립트 |
| `~/.claude/hud/cch-hud-config.json` | CCH HUD 설정 |
| `~/.claude/.omc/hud-config.json` | OMC HUD 설정 |
| `~/.claude/settings.json` | statusLine 등록 |

## 색상 가이드

| 상태 | 색상 |
|------|------|
| mode=code | cyan |
| mode=plan | magenta |
| mode=tool | yellow |
| mode=swarm | green |
| Healthy | green |
| Degraded | yellow |
| Blocked | red |
| DOT:on | green |
| DOT:off | dim |
| 토큰 0-69% | green |
| 토큰 70-89% | yellow |
| 토큰 90%+ | red |
