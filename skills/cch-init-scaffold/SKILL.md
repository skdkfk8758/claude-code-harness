---
name: cch-init-scaffold
description: "CCH 구조 스캐폴딩 — 디렉터리/매니페스트/프로필/훅 자동 생성"
user-invocable: false
allowed-tools: [Read, Write, Bash, Glob, Grep, AskUserQuestion]
---

# CCH Init Scaffold

scan-result.json을 기반으로 CCH 디렉터리 구조, 매니페스트, 프로필, TODO를 자동 생성합니다.

## Prerequisites

1. `.claude/cch/init/scan-result.json` 존재 확인:

```bash
test -f ".claude/cch/init/scan-result.json" || { echo "ERROR: scan-result.json not found. Run cch-init-scan first."; exit 1; }
```

2. 기존 CCH 구조 충돌 확인 — `.claude-plugin/plugin.json` 또는 `manifests/` 또는 `profiles/` 가 이미 존재하면 사용자에게 덮어쓰기 여부 확인:

```
기존 CCH 구조가 감지되었습니다:
  - .claude-plugin/plugin.json (존재)
  - manifests/ (존재)
  - profiles/ (존재)

계속하면 위 파일이 덮어쓰여집니다. 진행하시겠습니까? (yes/no)
```

`no` 응답 시 중단하고 사용자에게 수동 백업 후 재시도 안내.

## Step 1: CCH 디렉터리 구조 생성

scan-result.json을 읽어 `project_name`, `tech_stack`, `capabilities`, `install_type` 필드를 추출한다.

다음 디렉터리 및 파일을 생성한다:

| 경로 | 설명 |
|------|------|
| `.claude-plugin/plugin.json` | 플러그인 매니페스트 |
| `skills/` | 스킬 디렉터리 (없으면 생성) |
| `hooks/hooks.json` | 훅 설정 |
| `manifests/` | 매니페스트 디렉터리 |
| `profiles/` | 모드 프로필 디렉터리 |
| `bin/cch` | CLI 엔트리포인트 (없으면 플레이스홀더 생성) |
| `.claude/cch/` | CCH 상태 디렉터리 |

### `.claude-plugin/plugin.json` 생성

```json
{
  "name": "<project_name>",
  "version": "0.1.0",
  "description": "CCH plugin scaffolded by cch-init",
  "skillsDir": "skills",
  "hooksFile": "hooks/hooks.json",
  "manifestsDir": "manifests",
  "profilesDir": "profiles",
  "binPath": "bin/cch"
}
```

### `hooks/hooks.json` 생성

기본 훅 스켈레톤:

```json
{
  "hooks": {
    "PreToolUse": [],
    "PostToolUse": [],
    "SubagentStart": [],
    "Stop": []
  }
}
```

## Step 2: Manifests 생성

scan-result.json의 `capabilities` 및 `tech_stack`을 반영하여 3개 매니페스트를 생성한다.

### `manifests/capabilities.json`

scan에서 발견된 capabilities 목록을 그대로 기록:

```json
{
  "version": "1.0",
  "detected_from": ".claude/cch/init/scan-result.json",
  "capabilities": [
    "<capability-1>",
    "<capability-2>"
  ],
  "tech_stack": {
    "languages": ["<lang-1>"],
    "frameworks": ["<framework-1>"],
    "tools": ["<tool-1>"]
  }
}
```

### `manifests/sources.json`

`install_type` 스키마 준수 (Phase 3S #56 호환):

```json
{
  "version": "1.0",
  "sources": [
    {
      "id": "local",
      "type": "local",
      "path": ".",
      "enabled": true
    }
  ]
}
```

`install_type`이 `git`이면 sources에 git 엔트리 추가:

```json
{
  "id": "origin",
  "type": "git",
  "url": "<git_remote_url>",
  "branch": "main",
  "enabled": true
}
```

### `manifests/health-rules.json`

프로젝트 소스 특성에 맞는 기본 규칙:

```json
{
  "version": "1.0",
  "rules": [
    {
      "id": "scan-result-exists",
      "description": "CCH scan result must exist",
      "check": "file_exists",
      "path": ".claude/cch/init/scan-result.json",
      "severity": "warning"
    },
    {
      "id": "plugin-manifest-valid",
      "description": "Plugin manifest must be valid JSON",
      "check": "json_valid",
      "path": ".claude-plugin/plugin.json",
      "severity": "error"
    }
  ]
}
```

tech_stack에 `node` 또는 `javascript`/`typescript`가 포함되면 추가:

```json
{
  "id": "node-modules-present",
  "description": "node_modules must be installed",
  "check": "dir_exists",
  "path": "node_modules",
  "severity": "warning"
}
```

## Step 3: Profiles 생성

scan-result.json의 `tech_stack`을 기반으로 4개 모드 프로필을 생성한다.

각 프로필의 `primary_sources`와 `secondary_sources`는 스캔에서 발견된 기술 스택에 맞게 조정한다.

### `profiles/plan.json` — 계획 모드

문서/분석 도구 중심. `capabilities`에 `documentation`이 있으면 docs 소스를 primary로:

```json
{
  "mode": "plan",
  "description": "계획 및 분석 모드 — 문서화/아키텍처 결정 중심",
  "allowed_tools": ["Read", "Glob", "Grep", "Write", "WebSearch", "WebFetch"],
  "primary_sources": ["local", "docs"],
  "secondary_sources": [],
  "agent_budget": {
    "max_tokens": 8000,
    "max_turns": 20
  }
}
```

### `profiles/code.json` — 코딩 모드

편집/테스트 도구 중심. `tech_stack`에서 발견된 언어를 `context.languages`에 기록:

```json
{
  "mode": "code",
  "description": "코딩 모드 — 구현 및 테스트 중심",
  "allowed_tools": ["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
  "primary_sources": ["local"],
  "secondary_sources": [],
  "context": {
    "languages": ["<detected-language-1>"],
    "frameworks": ["<detected-framework-1>"]
  },
  "agent_budget": {
    "max_tokens": 12000,
    "max_turns": 30
  }
}
```

## Step 4: Roadmap → TODO 분해

`Roadmap.md`가 프로젝트 루트에 존재하는 경우 실행한다. 없으면 스킵하고 사용자에게 안내.

### 처리 절차

1. `Roadmap.md`를 읽어 마일스톤 목록 추출 (## 또는 ### 헤딩 기준)
2. 각 마일스톤을 Beads 항목으로 생성:
   - `bd init --prefix cch` (아직 초기화되지 않은 경우)
   - 각 마일스톤 하위 항목 → `bash bin/cch beads create "<항목>" --type task --labels "phase:<N>"`
   - 순차적 마일스톤 → `bash bin/cch beads dep <bead-id> <depends-on-bead-id>` 의존성 추가
3. `bd ready`로 의존성 해결된 작업 확인

## Output

완료 후 아래 형식으로 보고:

```
## CCH Init Scaffold 완료

### 생성된 파일

| 파일 | 설명 |
|------|------|
| .claude-plugin/plugin.json | 플러그인 매니페스트 |
| hooks/hooks.json | 훅 설정 스켈레톤 |
| manifests/capabilities.json | 프로젝트 capabilities |
| manifests/sources.json | 소스 구성 (install_type: <type>) |
| manifests/health-rules.json | 헬스 체크 규칙 |
| profiles/plan.json | 계획 모드 프로필 |
| profiles/code.json | 코딩 모드 프로필 |
| .beads/ | Roadmap 분해 → Beads 항목 생성 (또는 스킵) |

### 프로젝트 특성 반영 내역

- 기술 스택: <detected tech_stack>
- 조정된 프로필: <어떤 프로필이 어떻게 조정되었는지>
- TODO 분해: <Phase 수> Phases, Critical Path: <경로>

다음 단계: `/cch-setup` 실행 후 `/cch-mode` 로 모드 선택
```
