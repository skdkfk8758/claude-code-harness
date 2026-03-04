# Architecture: Claude Code Harness v2

- 문서 버전: v2.1
- 작성일: 2026-03-04
- 상태: Active

## 1. 아키텍처 목표

CCH를 경량 오케스트레이션 플러그인으로 운영한다.

핵심 원칙:

1. 사용자 진입점은 slash command, 실행은 `bin/cch` + `scripts/`
2. 단일 프롬프트 + Tier 조건부 강화 (별도 lite/full 분기 없음)
3. 매니페스트 1개 (`capabilities.json`), 프로필 2개 (`plan.json`, `code.json`)
4. 모든 상태 판정은 `reason_code`를 포함
5. Beads가 태스크 유일한 SSOT

## 2. 아키텍처 결정

v1의 Policy-Driven Orchestrator에서 **v2 Lightweight Harness**로 전환:

1. 별도 엔진(Context/Policy/Lifecycle) → 기존 함수로 흡수
2. 4-Phase HRP → 1-Phase check-env.mjs
3. 7개 매니페스트 → 1개 capabilities.json
4. 4-mode(plan/code/tool/swarm) → 2-mode(plan/code)
5. DOT 실험 트랙 제거
6. Bash/Node.js 하이브리드 (JSON은 Node.js, 나머지는 bash)

## 3. 레이어와 컴포넌트

### 3.1 레이어

```
┌─────────────────────────────────────┐
│  Interface Layer                    │
│  /cch-* slash commands (18 skills)  │
├─────────────────────────────────────┤
│  Execution Layer                    │
│  bin/cch (bash) + scripts/ (Node.js)│
├─────────────────────────────────────┤
│  Configuration Layer                │
│  profiles/*.json                    │
│  manifests/capabilities.json        │
├─────────────────────────────────────┤
│  State Layer                        │
│  .claude/cch/ (runtime state)       │
│  .beads/ (task SSOT)                │
├─────────────────────────────────────┤
│  Hook Layer                         │
│  hooks/hooks.json → scripts/*.mjs   │
└─────────────────────────────────────┘
```

### 3.2 컴포넌트 책임

| 컴포넌트 | 파일 | 책임 |
| --- | --- | --- |
| CLI Engine | `bin/cch` | 명령 파싱/디스패치, 모드 전환, 상태 관리, 헬스 판정, Tier 감지, 마이그레이션 |
| Core Module | `scripts/lib/core.mjs` | JSON 파싱, 상태 R/W, 매니페스트 읽기, Tier 계산, status-json 생성 |
| Env Scanner | `scripts/check-env.mjs` | 환경 스캔 (플러그인, MCP, Tier), Hook/CLI 이중 모드 |
| Activity Tracker | `scripts/activity-tracker.mjs` | UserPromptSubmit/TaskCreate/TaskUpdate 활동 추적 |
| Summary Writer | `scripts/summary-writer.mjs` | Stop 이벤트 시 세션 요약 생성 |
| Mode Detector | `scripts/mode-detector.sh` | UserPromptSubmit 시 plan/code 모드 추천 |
| Plan Bridge | `scripts/plan-bridge.mjs` | ExitPlanMode 시 플랜 문서 연결 |
| Beads Engine | `bin/lib/beads.sh` | 태스크 CRUD/전환/의존성/조회 |
| Branch Manager | `bin/lib/branch.sh` | 브랜치 워크플로우 (생성/전환/정리) |
| Log Manager | `bin/lib/log.sh` | 실행 로그 기록/조회 |
| Lock Manager | `bin/lib/lock.sh` | 동시성 제어 |

## 4. 명령 계약

### 4.1 종료코드

- `0`: success
- `1`: validation/runtime failure

### 4.2 명령 매핑

| Slash Command | bin/cch 명령 |
| --- | --- |
| `/cch-setup` | `cch setup` |
| `/cch-mode` | `cch mode [plan\|code]` |
| `/cch-status` | `cch status [--json]` |
| `/cch-todo` | Beads + TaskList 통합 조회 (스킬 내부) |
| `/cch-commit` | 스킬 내부 (git 워크플로우) |
| `/cch-verify` | 스킬 내부 (테스트/검증) |
| `/cch-review` | 스킬 내부 (코드 리뷰) |
| `/cch-pr` | 스킬 내부 (PR 생성) |

## 5. Tier 시스템

```
Tier 0: CCH Core
  └── bin/cch + 스킬 기본 동작

Tier 1: + Superpowers
  └── Enhancement 섹션 활성화
      (brainstorming, TDD, verify, code-review, etc.)

Tier 2: + MCP Servers
  └── MCP 도구 활용 강화
      (Serena, Context7, Slack, etc.)
```

감지 로직: `_calculate_tier()` (bin/cch) + `calculateTier()` (core.mjs)

## 6. 스킬 아키텍처

### 6.1 스킬 템플릿

```markdown
---
name: <skill-name>
description: <description>
user-invocable: true
allowed-tools: <tool list>
---

# <Skill Title>

## Steps
### Step 1 - ...
### Step 2 - ...

## Enhancement (Tier 1+)
> superpowers 플러그인이 설치되어 있으면 다음 강화 기능을 활용합니다.
- **Tier 1+**: <superpowers 스킬 활용>
- **Tier 2+**: <MCP 도구 활용>
```

### 6.2 스킬 목록 (18개)

**코어 (8)**: cch-setup, cch-plan, cch-commit, cch-todo, cch-verify, cch-review, cch-status, cch-pr

**유틸리티 (10)**: cch-init, cch-init-scan, cch-init-docs, cch-init-scaffold, cch-arch-guide, cch-excalidraw, cch-lsp, cch-pinchtab, cch-full-pipeline, cch-team

## 7. 상태 저장소

```
.claude/cch/
├── mode              # 현재 모드 (plan|code)
├── health            # 헬스 상태 (Healthy|Degraded|Blocked)
├── health_reason     # reason_code (쉼표 구분)
├── tier              # Tier 레벨 (0|1|2)
├── last_activity     # 마지막 활동
├── init/             # cch-init 스캔 결과
├── state/logs/       # 실행 로그
├── branches/         # 브랜치별 상태 (YAML)
├── sessions/         # 세션별 상태
├── locks/            # 동시성 제어
└── execution-plan.json
```

`.beads/` — 프로젝트 수준 태스크 SSOT (git 추적)

## 8. Hook 파이프라인

```
SessionStart ──→ check-env.mjs (Tier 감지)
UserPromptSubmit ──→ mode-detector.sh (모드 추천)
                 ──→ activity-tracker.mjs (활동 추적)
PreToolUse ──→ activity-tracker.mjs (TaskCreate/Update)
PostToolUse ──→ plan-bridge.mjs (ExitPlanMode)
Stop ──→ summary-writer.mjs (세션 요약)
```

## 9. 테스트 아키텍처

7개 테스트 파일, 201 테스트:

| 레이어 | 파일 | 검증 대상 |
| --- | --- | --- |
| Contract | test_contract.sh | bin/cch 명령 계약 (20) |
| Skill | test_skill.sh | SKILL.md frontmatter + Enhancement (52) |
| Beads | test_beads.sh | 태스크 CRUD/전환/의존성 (29) |
| Branch | test_branch.sh | 브랜치 워크플로우 (35) |
| Workflow | test_workflow.sh | E2E 워크플로우 (9) |
| Resilience | test_resilience.sh | 복구력/결함 허용 (6) |
| Integration | test_phase5.sh | Tier/환경스캔/통합 (13) |
| Init | test_cch_init.sh | 초기화 스킬 구조 (37) |

실행: `bash tests/harness.sh`

## 10. 참조 문서

1. `docs/plans/2026-03-04-cch-v2-harness-renewal.md` — v2 리뉴얼 설계
2. `docs/plans/2026-03-04-cch-v2-lightweight-review.md` — 경량화 검토
3. `docs/plans/2026-03-04-superpowers-integration.md` — Superpowers 통합
4. `.beads/issues.jsonl` — 전체 작업 항목 추적 (`bash bin/cch beads list`)
