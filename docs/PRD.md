# PRD: Claude Code Harness v2

- 문서 버전: v2.1
- 작성일: 2026-03-04
- 상태: Active

## 1. 제품 정의

CCH는 Claude Code에서 동작하는 경량 오케스트레이션 플러그인이다.

핵심:

1. 사용자 UX는 `/plugin install` + slash command
2. 내부 실행 엔진은 `bin/cch` (bash) + `scripts/lib/core.mjs` (Node.js)
3. 스킬은 단일 프롬프트 + Tier 조건부 강화 (Enhancement 섹션)
4. 태스크 추적은 Beads (SSOT)

## 2. 해결할 문제

1. Claude Code 세션 간 컨텍스트 유실 → Beads + 실행 로그
2. 반복 워크플로우의 일관성 부족 → 스킬 기반 표준 프로세스
3. 환경 가용성에 따른 기능 저하 → Tier 시스템 + Enhancement 조건부 강화
4. 설계→구현→검증 파이프라인 단절 → cch-plan → cch-commit → cch-verify 통합

## 3. 제품 목표

1. 경량 아키텍처: bin/cch ~460줄, 매니페스트 1개, 프로필 2개
2. Tier 시스템: Tier 0(코어) / Tier 1(+superpowers) / Tier 2(+MCP)
3. 18개 스킬: 코어 8 + 유틸리티 10, Enhancement 섹션으로 Tier 조건부 강화
4. 201개 테스트 통과 (contract/skill/beads/branch/workflow/resilience/integration)
5. 자동 환경 스캔: check-env.mjs (SessionStart hook)

## 4. 기능 요구사항

### F1. 명령 표면

필수 slash commands (코어 8):

1. `/cch-setup` — 환경 초기화 + Tier 감지
2. `/cch-plan` — 설계→플래닝→TODO 통합 워크플로우
3. `/cch-commit` — 논리 단위 자동 분할 커밋
4. `/cch-todo` — Beads + TaskList 통합 조회
5. `/cch-verify` — 구현 검증 (debug + TDD 흡수)
6. `/cch-review` — 코드 리뷰 체크리스트
7. `/cch-status` — 건강 상태/Tier/모드 조회
8. `/cch-pr` — PR 생성 (Beads 연결)

### F2. 명령 계약

bin/cch 명령:

| 명령 | 설명 |
| --- | --- |
| `cch setup` | 환경 초기화 + v1→v2 마이그레이션 + Tier 감지 |
| `cch mode [plan\|code]` | 모드 조회/전환 |
| `cch status [--json]` | 건강 상태 조회 (JSON 출력 지원) |
| `cch branch [cmd]` | 브랜치 워크플로우 관리 |
| `cch beads [cmd]` | Beads 태스크 추적 |
| `cch log [show\|tail]` | 실행 로그 조회 |

### F3. 상태 조회 계약

`cch status --json` 필드:

- `version`, `mode`, `tier`, `health`, `reason_codes`
- `branch`, `work_id`, `work_items`, `plans`

### F4. Tier 시스템

| Tier | 조건 | 기능 |
| --- | --- | --- |
| 0 | CCH 코어만 | 기본 스킬 동작 |
| 1 | + superpowers 플러그인 | Enhancement 섹션 활성화 (brainstorming, TDD, verify 등) |
| 2 | + MCP 서버 | MCP 도구 활용 강화 |

### F5. 작업 기록 및 증적

1. 태스크 상태: `.beads/` (Beads SSOT, `bin/cch beads` CLI)
2. 실행 로그: `bin/lib/log.sh` (JSONL)
3. 활동 추적: `scripts/activity-tracker.mjs` (UserPromptSubmit hook)
4. 세션 요약: `scripts/summary-writer.mjs` (Stop hook)

### F6. 테스트 체계

7개 테스트 파일, 201 테스트:

1. Contract — bin/cch 명령 계약 검증
2. Skill — SKILL.md frontmatter + Enhancement 섹션
3. Beads — 태스크 CRUD/전환/의존성
4. Branch — 브랜치 워크플로우
5. Workflow — setup→mode→status→beads E2E
6. Resilience — 복구력/결함 허용
7. Phase5 — Tier/환경스캔/통합 검증

### F7. Hook 체계

| 이벤트 | 훅 스크립트 | 역할 |
| --- | --- | --- |
| SessionStart | check-env.mjs | 환경 스캔 + Tier 감지 |
| UserPromptSubmit | mode-detector.sh | 모드 추천 |
| UserPromptSubmit | activity-tracker.mjs | 활동 추적 |
| PreToolUse (TaskCreate/Update) | activity-tracker.mjs | 태스크 활동 추적 |
| PostToolUse (ExitPlanMode) | plan-bridge.mjs | 플랜 문서 연결 |
| Stop | summary-writer.mjs | 세션 요약 생성 |

## 5. 운영 요구사항

1. 태스크의 단일 진실원은 `.beads/` (Beads)
2. Beads → TaskList 단방향 hydrate (`bd ready` → `TaskCreate`)
3. docs/plans/는 설계/실행 근거 문서

## 6. 범위

### In Scope

1. 경량 오케스트레이션 (bin/cch + scripts/)
2. 18개 스킬 (단일 프롬프트 + Enhancement)
3. Tier 시스템 (0/1/2)
4. Beads 태스크 추적
5. Hook 기반 자동화

### Out of Scope

1. 독립 엔진 (Context/Policy/Lifecycle → 기존 코드로 흡수)
2. 멀티 매니페스트 (단일 capabilities.json)
3. DOT 실험 트랙 (v1에서 제거)
4. 별도 스킬 라우터 (Claude 자동 선택)
