# Claude Code Harness (CCH)

Claude Code에서 동작하는 통합 오케스트레이션 프레임워크.

다중 capability source를 정책(manifest/rules) 기반으로 통합하고, 4가지 운영 모드와 49개 스킬을 제공합니다.

## Quick Start

```bash
# 1. Claude Code 플러그인 설치
/plugin install claude-code-harness

# 2. 환경 초기화 (vendor 자동 다운로드 포함)
/cch-setup

# 3. 운영 모드 선택
/cch-mode code

# 4. 상태 확인
/cch-status
```

## 운영 모드

CCH는 작업 목적에 따라 4가지 모드를 제공합니다. 각 모드는 서로 다른 vendor를 primary/secondary로 사용합니다.

| 모드 | 설명 | Primary | Secondary |
|------|------|---------|-----------|
| `code` | 구현 및 개발 | omc, superpowers | gptaku_plugins, ruflo |
| `plan` | 아키텍처 설계 및 작업 분해 | ruflo, superpowers | gptaku_plugins |
| `tool` | 외부 도구 통합 및 오케스트레이션 | gptaku_plugins | omc |
| `swarm` | 멀티 에이전트 협업 | ruflo | omc |

```bash
/cch-mode <plan|code|tool|swarm>
```

## Vendor(Source) 관리

CCH의 기능은 5개 외부 vendor source에서 제공됩니다. Vendor는 **`cch setup` 실행 시 자동으로 로컬에 다운로드**되며, git에는 커밋되지 않습니다.

### Vendor 목록

| Vendor | 설치 방식 | 설명 | 제공 스킬 |
|--------|-----------|------|-----------|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | plugin | Claude Code 확장 레이어 | autopilot, ralph, ultrawork 등 |
| [superpowers](https://github.com/obra/superpowers) | plugin | 핵심 스킬 라이브러리 | TDD, debugging, brainstorming 등 |
| [gptaku_plugins](https://github.com/fivetaku/gptaku_plugins) | git clone | 도구 통합 플러그인 모음 | team, pumasi, prd, research 등 |
| [ruflo](https://github.com/ruvnet/ruflo) | npm | 워크플로우/스웜 오케스트레이션 | swarm, sparc, hive, memory 등 |
| [excalidraw](https://github.com/coleam00/excalidraw-diagram-skill) | npm | 다이어그램 생성 | excalidraw 다이어그램 |

### 설치 방식별 차이

**Plugin 타입** (`omc`, `superpowers`)
- Claude Code 마켓플레이스를 통해 설치
- `claude plugin install <plugin_id>` 명령 사용
- `cch setup` 실행 시 설치 안내 제공

**Git 타입** (`gptaku_plugins`)
- `git clone --depth 1`로 shallow clone
- 이후 `git submodule update --init --recursive` 자동 실행

**NPM 타입** (`ruflo`, `excalidraw`)
- git clone 후 `npm install --production` 또는 `uv sync` 자동 실행
- Node.js/Python 런타임 필요

### Vendor 관리 명령

```bash
# 전체 vendor 상태 확인
cch sources status

# 특정 vendor 설치
cch sources install <name>

# 설치된 vendor 업데이트
cch sources update [name]

# 릴리즈 잠금 (SHA 기록)
cch sources lock

# 잠금 해제
cch sources unlock

# 무결성 검증
cch sources integrity verify
```

### Fallback 시스템

Vendor 다운로드가 실패해도 CCH는 동작합니다:

1. **Primary**: `sources.json`에 정의된 target 경로 확인
2. **Fallback 1**: `.claude/cch/sources/<name>` 확인
3. **Fallback 2**: `overlays/<name>` 디렉토리 확인

모든 vendor는 optional이므로, 누락 시 해당 기능만 Degraded 상태로 전환됩니다(swarm 모드의 ruflo 제외 — Blocked).

## Health 시스템

CCH는 vendor 가용성에 따라 3단계 건강 상태를 자동 판정합니다.

| 상태 | 의미 |
|------|------|
| **Healthy** | 모든 필수 source 정상 |
| **Degraded** | optional source 누락, 대체 경로 적용 |
| **Blocked** | 필수 source 결손 또는 정책 위반 |

판정 규칙은 `manifests/health-rules.json`에 선언적으로 관리됩니다.

```bash
# 현재 상태 확인
/cch-status

# JSON 포맷으로 확인
/cch-status --json
```

## 스킬

CCH는 49개 스킬을 6개 카테고리로 제공합니다. 모두 `/` 명령으로 실행합니다.

### Core — 프레임워크 관리

| 명령 | 설명 |
|------|------|
| `/cch-setup` | 환경 초기화 및 vendor 설치 |
| `/cch-mode` | 운영 모드 전환 |
| `/cch-status` | 건강 상태 조회 |
| `/cch-update` | 무결성 검증 및 업데이트 |
| `/cch-sync` | 스킬/바이너리 캐시 동기화 |
| `/cch-hud` | 상태바 설정 |
| `/cch-dot` | DOT 실험 토글 (code 모드 전용) |

### SP — Superpowers 워크플로우

| 명령 | 설명 |
|------|------|
| `/cch-sp-brainstorm` | 구조화된 설계 대화 |
| `/cch-sp-write-plan` | 구현 계획 작성 |
| `/cch-sp-execute-plan` | 계획 실행 (리뷰 체크포인트 포함) |
| `/cch-sp-tdd` | Red-Green-Refactor TDD 사이클 |
| `/cch-sp-code-review` | 코드 리뷰 디스패치 |
| `/cch-sp-verify` | 완료 전 검증 |
| `/cch-sp-git-worktree` | 격리된 worktree 생성 |
| `/cch-sp-parallel-agents` | 병렬 에이전트 실행 |
| `/cch-sp-subagent-dev` | 서브에이전트 기반 개발 |
| `/cch-sp-finish-branch` | 브랜치 완료 및 정리 |
| `/cch-sp-receive-review` | 코드 리뷰 피드백 수신 |
| `/cch-sp-debug` | 체계적 디버깅 |

### GP — GPTaku 플러그인

| 명령 | 설명 |
|------|------|
| `/cch-gp-team` | AI 에이전트 팀 구성 |
| `/cch-gp-pumasi` | Claude PM + Codex 워커 병렬 코딩 |
| `/cch-gp-prd` | 인터뷰 기반 PRD 생성 |
| `/cch-gp-research` | 멀티 에이전트 딥 리서치 |
| `/cch-gp-docs` | 68+ 라이브러리 문서 조회 |
| `/cch-gp-skill-builder` | 4-페르소나 스킬 빌더 |
| `/cch-gp-mentor` | AI 멘토 |
| `/cch-gp-git-learn` | Git/GitHub 온보딩 |
| `/cch-gp-playground` | 스킬 프로토타이핑 환경 |

### RF — Ruflo 오케스트레이션

| 명령 | 설명 |
|------|------|
| `/cch-rf-swarm` | 멀티 에이전트 스웜 |
| `/cch-rf-sparc` | SPARC 방법론 |
| `/cch-rf-hive` | 비잔틴 내결함성 합의 |
| `/cch-rf-memory` | 에이전트 공유 메모리 |
| `/cch-rf-security` | 보안 스캐닝/CVE 수정 |
| `/cch-rf-doctor` | 시스템 진단 |

### PT — PinchTab 웹 테스팅

| 명령 | 설명 |
|------|------|
| `/cch-pinchtab` | 웹 UI 오케스트레이터 |
| `/cch-pt-infra` | 서버 생명주기 관리 |
| `/cch-pt-test` | 웹 UI 테스트 실행 |
| `/cch-pt-report` | 테스트 보고서 생성 |

### Utility — 공통 도구

| 명령 | 설명 |
|------|------|
| `/cch-commit` | 구조화된 커밋 생성 |
| `/cch-pr` | PR 생성 (Beads 연동) |
| `/cch-todo` | 전체 작업 현황 조회 |
| `/cch-init` | 프로젝트 분석 및 문서 생성 |
| `/cch-release` | 버전 릴리즈 번들 생성 |
| `/cch-team` | dev→test→verify 파이프라인 |
| `/cch-full-pipeline` | PRD→구현→검증 E2E 파이프라인 |
| `/cch-excalidraw` | Excalidraw 다이어그램 생성 |

## 프로젝트 구조

```
claude-code-harness/
├── bin/                    # 실행 파일
│   ├── cch                 # 메인 CLI
│   ├── cch-pt              # PinchTab CLI
│   └── lib/                # 공유 라이브러리 (sources.sh 등)
├── manifests/              # 정책 선언 파일
│   ├── sources.json        # vendor 정의 (SSOT)
│   ├── capabilities.json   # vendor별 기능/심각도 매핑
│   └── health-rules.json   # 건강 판정 규칙
├── profiles/               # 모드별 설정
│   ├── code.json
│   ├── plan.json
│   ├── tool.json
│   └── swarm.json
├── skills/                 # 49개 스킬 정의
│   ├── cch-sp-*/           # Superpowers 계열
│   ├── cch-gp-*/           # GPTaku 계열
│   ├── cch-rf-*/           # Ruflo 계열
│   ├── cch-pt-*/           # PinchTab 계열
│   └── cch-*/              # Core/Utility
├── overlays/               # vendor fallback 디렉토리
├── scripts/                # 빌드/테스트/유틸리티 스크립트
├── tests/                  # 6-layer 테스트
├── docs/                   # PRD, Architecture, Roadmap, TODO
│   └── plans/              # 설계/실행 계획 문서
└── dot/                    # DOT 실험 source (code 모드 전용)
```

### 런타임 디렉토리 (자동 생성, git 미추적)

```
.claude/cch/
├── state/                  # mode, health, dot_enabled
├── sources/                # 다운로드된 vendor source
├── work-items/             # 작업 상태 (Beads JSONL 기반)
├── runs/                   # 실행 로그 (JSONL)
├── metrics/                # KPI 로그
└── updates/rollbacks/      # 롤백 히스토리
```

## 새 프로젝트에 CCH 도입하기

기존 프로젝트에 CCH를 설치하고 마이그레이션하는 가이드입니다.

### 1. 플러그인 설치

```bash
# CCH 메인 플러그인
/plugin install claude-code-harness

# (선택) 추가 vendor 플러그인
/plugin install superpowers@superpowers-marketplace
/plugin install oh-my-claudecode@omc
```

### 2. 초기화 모드 선택

| 모드 | 목적 | 생성물 |
|------|------|--------|
| `onboard` | 프로젝트 문서만 역산 생성 | `docs/Architecture.md`, `PRD.md`, `Roadmap.md`, `TODO.md` |
| `migrate` | 문서 + CCH 디렉터리 스캐폴딩 | 위 문서 + `manifests/`, `profiles/`, `bin/`, `skills/` 등 |

### 3. 초기화 실행

대상 프로젝트 디렉토리에서:

```bash
# 대화형 (모드 선택 프롬프트)
/cch-init

# 직접 지정
/cch-init onboard    # 문서만
/cch-init migrate    # 문서 + 스캐폴딩
```

내부 파이프라인: `Scan (프로젝트 분석) → Docs (문서 생성) → Scaffold (migrate만)`

중단 시 `.claude/cch/init/progress`에 진행 상태가 기록되어, 재실행하면 이어서 진행합니다.

### 4. CCH 환경 초기화 (migrate 모드)

```bash
/cch-setup
```

vendor 자동 다운로드, 상태 디렉토리 생성, 건강 상태 판정이 수행됩니다.

### 5. 운영 시작

```bash
/cch-mode code       # 운영 모드 선택
/cch-status          # 상태 확인
```

### 전체 플로우 요약

```
/plugin install claude-code-harness
         ↓
/cch-init migrate       ← 프로젝트 스캔 + 문서 + 스캐폴딩
         ↓
/cch-setup              ← vendor 다운로드 + 환경 초기화
         ↓
/cch-mode code          ← 운영 모드 선택
         ↓
/cch-status             ← 상태 확인, 바로 사용 가능
```

## 전제 조건

- [Claude Code](https://claude.ai/claude-code) CLI
- Git
- Node.js (ruflo vendor 사용 시)
- Python + uv (excalidraw vendor 사용 시, 선택사항)

## 테스트

```bash
# 전체 6-layer 테스트 실행
bash scripts/test.sh all

# 개별 레이어 실행
bash scripts/test.sh contract
bash scripts/test.sh agent
bash scripts/test.sh skill
bash scripts/test.sh workflow
bash scripts/test.sh resilience
bash scripts/test.sh dot_gate
```

## 업데이트 및 복구

```bash
# 무결성 검증
/cch-update check

# 업데이트 적용 (자동 rollback point 생성)
/cch-update apply

# 롤백
/cch-update rollback <id>

# 롤백 히스토리 조회
/cch-update history
```

## License

MIT
