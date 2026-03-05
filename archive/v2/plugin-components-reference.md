# Superpowers & CCH (Claude Code Harness) 플러그인 구성 요소 레퍼런스

> 작성일: 2026-03-05 | 대상 버전: superpowers v4.3.1 / CCH v0.2.0 (dist) / kkirikkiri v0.8.0

---

## 목차

1. [설치된 플러그인 요약](#1-설치된-플러그인-요약)
2. [Hooks (전체 목록)](#2-hooks-전체-목록)
3. [Agents](#3-agents)
4. [Skills — Superpowers](#4-skills--superpowers)
5. [Skills — CCH Core](#5-skills--cch-core)
6. [Skills — CCH Superpowers 위임 (cch-sp-*)](#6-skills--cch-superpowers-위임-cch-sp)
7. [Skills — Ruflo Framework (cch-rf-*)](#7-skills--ruflo-framework-cch-rf)
8. [Skills — GPTaku Plugins (cch-gp-*)](#8-skills--gptaku-plugins-cch-gp)
9. [Skills — PinchTab (cch-pt-*)](#9-skills--pinchtab-cch-pt)
10. [Skills — Dist-only 추가 스킬](#10-skills--dist-only-추가-스킬)
11. [CLI 명령어 (bin/cch)](#11-cli-명령어-bincch)
12. [Slash Commands](#12-slash-commands)
13. [CCH Tier 시스템](#13-cch-tier-시스템)
14. [상태 관리](#14-상태-관리)
15. [스킬 의존성 그래프](#15-스킬-의존성-그래프)

---

## 1. 설치된 플러그인 요약

| 플러그인 | 버전 | Marketplace | 저자 | 설명 |
|----------|------|-------------|------|------|
| **superpowers** | 4.3.1 | `superpowers-marketplace` (github:obra) | Jesse Vincent | TDD, 디버깅, 협업 패턴 등 핵심 스킬 라이브러리 |
| **claude-code-harness** | 0.1.0 (캐시) / 0.2.0 (dev) | `claude-code-harness-marketplace` | carpdm | 경량 오케스트레이션 — Tier 인식 스킬, Beads 태스크 추적, 훅 자동화 |
| **kkirikkiri** | 0.8.0 | `gptaku-plugins` | — | 자연어로 AI 에이전트 팀 구성 (CCH의 cch-gp-team이 래핑) |

---

## 2. Hooks (전체 목록)

### Hook 이벤트 흐름도

```
SessionStart ─┬─ superpowers: session-start (using-superpowers 스킬 주입)
              └─ CCH: check-env.mjs (환경 스캔, Tier 계산)

UserPromptSubmit ─┬─ CCH: mode-detector.sh (모드 전환 추천)
                  └─ CCH: activity-tracker.mjs (활동 기록)

PreToolUse ─┬─ ExitPlanMode → CCH: plan-doc-reminder.sh (플랜 저장 알림)
            ├─ TaskCreate   → CCH: activity-tracker.mjs (태스크 활동 기록)
            └─ TaskUpdate   → CCH: activity-tracker.mjs (진행/완료 상태 반영)

PostToolUse ─┬─ ExitPlanMode → CCH: plan-bridge.mjs (플랜→실행 브릿지)
             └─ Bash         → CCH: tdd-enforcer.sh (TDD 커버리지 경고)

Stop ── CCH: summary-writer.mjs (Q&A 요약 저장)
```

### 상세 Hook 목록

| # | 플러그인 | 이벤트 | Matcher | 스크립트 | Timeout | 목적 |
|---|----------|--------|---------|----------|---------|------|
| 1 | superpowers | `SessionStart` | `startup\|resume\|clear\|compact` | `run-hook.cmd session-start` | sync | `using-superpowers` 스킬을 세션 컨텍스트에 주입 |
| 2 | CCH | `SessionStart` | `*` | `check-env.mjs` | 5s | 플러그인/MCP 스캔, Tier 계산, 환경 컨텍스트 주입 |
| 3 | CCH | `UserPromptSubmit` | `*` | `mode-detector.sh` | 3s | 프롬프트의 키워드 기반 점수로 plan/code/tool/swarm 모드 전환 추천 |
| 4 | CCH | `UserPromptSubmit` | `*` | `activity-tracker.mjs` | 2s | 프롬프트 첫 줄을 `last_activity`/`last_question`에 기록 (HUD용) |
| 5 | CCH | `PreToolUse` | `ExitPlanMode` | `plan-doc-reminder.sh` | 2s | 플랜모드 종료 전 `docs/plans/`에 플랜 저장 알림 |
| 6 | CCH | `PreToolUse` | `TaskCreate` | `activity-tracker.mjs` | 2s | 새 태스크의 `activeForm`/`subject`를 활동으로 기록 |
| 7 | CCH | `PreToolUse` | `TaskUpdate` | `activity-tracker.mjs` | 2s | `in_progress` → 활동 갱신, `completed` → `"done: "` 접두사 |
| 8 | CCH | `PostToolUse` | `ExitPlanMode` | `plan-bridge.mjs` | 5s | 플랜 문서 파싱 → `execution-plan.json` 생성 → Bead 생성 → 브랜치 생성 → code 모드 전환 |
| 9 | CCH | `PostToolUse` | `Bash` | `tdd-enforcer.sh` | 5s | `git commit` 후 소스 파일별 테스트 존재 여부 확인 (차단 안 함, 경고만) |
| 10 | CCH | `Stop` | `*` | `summary-writer.mjs` | 2s | 질문+답변 2줄 요약을 `last_summary`에 저장 (HUD 표시용) |

### Hook 스크립트 상세

#### `session-start` (superpowers)
- **파일:** `hooks/session-start` + `hooks/run-hook.cmd` (cross-platform polyglot)
- **동작:** `skills/using-superpowers/SKILL.md` 읽기 → `~/.config/superpowers/skills` 레거시 디렉터리 체크 → `<EXTREMELY_IMPORTANT>` 태그로 감싸서 `additionalContext`로 출력

#### `check-env.mjs` (CCH)
- **파일:** `scripts/check-env.mjs`
- **동작:** `~/.claude/plugins/cache/` 스캔 → `~/.claude/mcp.json` 스캔 → Tier 계산(0/1/2) → `.claude/cch/tier` 기록 → 환경 요약 컨텍스트 주입

#### `mode-detector.sh` (CCH)
- **파일:** `scripts/mode-detector.sh`
- **동작:** stdin JSON에서 프롬프트 추출 → plan/swarm/tool 키워드 점수 매기기(점수 ≥ 2이면 추천) → `additionalContext`로 모드 전환 안내

#### `activity-tracker.mjs` (CCH)
- **파일:** `scripts/activity-tracker.mjs`
- **동작:** 이벤트 타입에 따라 프롬프트 첫 줄 또는 태스크 `activeForm`을 `.claude/cch/last_activity`에 기록

#### `plan-doc-reminder.sh` (CCH)
- **파일:** `scripts/plan-doc-reminder.sh`
- **동작:** ExitPlanMode 직전에 플랜 문서 저장을 리마인드하는 `additionalContext` 주입

#### `plan-bridge.mjs` (CCH)
- **파일:** `scripts/plan-bridge.mjs`
- **동작:** `docs/plans/` 최신 플랜 파싱 → `execution-plan.json` 저장 → `bin/cch beads create` → `bin/cch branch create` → `bin/cch mode code`

#### `tdd-enforcer.sh` (CCH)
- **파일:** `scripts/tdd-enforcer.sh`
- **동작:** `git commit` 감지 → `HEAD~1..HEAD` diff → 소스 파일별 `test_*`, `*.test.*`, `*.spec.*` 패턴 매칭 → 미커버 파일 경고 → `.claude/cch/metrics/tdd-enforcement.jsonl`에 메트릭 기록

#### `summary-writer.mjs` (CCH)
- **파일:** `scripts/summary-writer.mjs`
- **동작:** `last_question` + 마지막 어시스턴트 메시지 → 각 70자 잘라서 2줄 요약 → `.claude/cch/last_summary` 기록

---

## 3. Agents

### superpowers: code-reviewer
| 항목 | 값 |
|------|-----|
| **파일** | `agents/code-reviewer.md` |
| **모델** | inherit (호출자와 동일) |
| **트리거** | 주요 프로젝트 단계 완료 후 코드 리뷰 필요 시 |
| **이슈 등급** | Critical (반드시 수정) / Important (수정 권장) / Suggestions (개선 제안) |

**동작:** 구현물을 계획 문서와 대조하여 plan 정합성, 코드 품질, 아키텍처, 문서화, 테스트를 종합 리뷰. 파일:줄번호 레퍼런스 필수.

### CCH: skill-analyzer
| 항목 | 값 |
|------|-----|
| **파일** | `.claude/agents/skill-analyzer.md` |
| **도구** | Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion |
| **모드** | `lint` / `create` / `edit` / `deps` |

**동작:**
- **lint** — SM001~SM012 규칙으로 SKILL.md 검증 (프론트매터, name/description, 길이 제한, 중복 체크 등)
- **create** — 인터랙티브 인터뷰를 통해 새 SKILL.md 생성
- **edit** — 기존 스킬 읽기 → lint → 개선 적용
- **deps** — 전체 스킬의 상호 참조 분석, 의존성 맵 빌드, 순환 참조 탐지

**Lint 규칙:**

| 규칙 | 심각도 | 검증 내용 |
|------|--------|-----------|
| SM001 | error | 프론트매터 존재 여부 |
| SM002 | error | `name` 필드 존재 |
| SM003 | error | `description` 필드 존재 |
| SM004 | warn | description이 "Use when"으로 시작 |
| SM005 | warn | description 500자 미만 |
| SM006 | info | 본문 500단어 미만 |
| SM007 | warn | user-invocable면 `allowed-tools` 선언 |
| SM008 | info | `## Enhancement` 섹션 존재 |
| SM009 | warn | 다른 스킬과 80% 이상 유사하지 않음 |
| SM010 | error | name이 영문/숫자/하이픈만 포함 |
| SM011 | info | `## When to Use` 섹션 존재 |
| SM012 | warn | 인자 기대 시 `argument-hint` 존재 |

---

## 4. Skills — Superpowers

> 네임스페이스: `superpowers:<name>` | 총 14개

### 핵심 워크플로우 스킬

| # | 이름 | 설명 | 트리거 | 유형 |
|---|------|------|--------|------|
| 1 | **using-superpowers** | 스킬 사용법 자체를 가르치는 메타 스킬 | SessionStart 훅으로 자동 주입 | Rigid |
| 2 | **brainstorming** | 구현 전 구조화된 디자인 대화 (6단계) | 모든 창작/구현 작업 전 | Rigid |
| 3 | **writing-plans** | 바이트사이즈 TDD 구현 계획 작성 | brainstorming 완료 후 또는 스펙이 있을 때 | Rigid |
| 4 | **executing-plans** | 배치(3개씩) 실행 + 리뷰 체크포인트 | 별도 세션에서 계획 파일 실행 시 | Rigid |
| 5 | **subagent-driven-development** | 태스크당 서브에이전트 디스패치 (2단계 리뷰) | 같은 세션에서 독립 태스크 실행 시 | Rigid |

### 개발 규율 스킬

| # | 이름 | 설명 | 핵심 원칙 |
|---|------|------|-----------|
| 6 | **test-driven-development** | Red-Green-Refactor 사이클 강제 | 실패하는 테스트 없이 프로덕션 코드 금지 |
| 7 | **systematic-debugging** | 4단계 체계적 디버깅 | 근본 원인 조사 없이 수정 금지 |
| 8 | **verification-before-completion** | 완료 주장 전 검증 증거 필수 | 커맨드 실행 → 출력 확인 → 그 후에만 주장 |

### 협업 스킬

| # | 이름 | 설명 |
|---|------|------|
| 9 | **dispatching-parallel-agents** | 독립된 2+ 문제에 병렬 서브에이전트 디스패치 |
| 10 | **requesting-code-review** | 코드 리뷰어 서브에이전트 디스패치 (표준화된 컨텍스트 전달) |
| 11 | **receiving-code-review** | 리뷰 피드백의 기술적 검증 (맹목적 수용 금지) |

### 브랜치/스킬 관리

| # | 이름 | 설명 |
|---|------|------|
| 12 | **using-git-worktrees** | 격리된 git worktree 생성 (.gitignore 확인, 셋업 자동 실행, 테스트 베이스라인) |
| 13 | **finishing-a-development-branch** | 구현 완료 후 4가지 옵션(merge/PR/keep/discard) 제시 |
| 14 | **writing-skills** | 스킬 문서 작성에 TDD 적용 (실패 시나리오 먼저) |

---

## 5. Skills — CCH Core

> 네임스페이스: `claude-code-harness:<name>` | 소스 레포 19개

### 초기화/온보딩

| 이름 | 호출 | 설명 |
|------|------|------|
| **cch-setup** | `/cch-setup` | CCH 환경 초기화 — 경로/권한/상태 디렉터리 검증 |
| **cch-init** | `/cch-init [onboard\|migrate]` | 프로젝트 분석 + CCH 마이그레이션 통합 파이프라인 (scan → docs → scaffold) |
| **cch-init-scan** | 내부 호출 | 프로젝트 심층 분석 — 메타/구조/문서/git/아키텍처 스캔 → `scan-result.json` |
| **cch-init-docs** | 내부 호출 | 문서 역산 생성 — Architecture/PRD/Roadmap/TODO 4개 문서 자동 생성 |
| **cch-init-scaffold** | 내부 호출 | CCH 디렉터리/매니페스트/프로필/훅 구조 스캐폴딩 |
| **cch-lsp** | `/cch-lsp [scan\|add\|status\|remove]` | LSP 서버 탐지/설치 (15개 언어 지원) → `.serena/project.yml` 설정 |
| **cch-arch-guide** | `/cch-arch-guide` | 3문항 인터뷰로 아키텍처 레벨(1/2/3) 결정 + 스캐폴딩 |

### 계획/워크플로우

| 이름 | 호출 | 설명 |
|------|------|------|
| **cch-plan** | `/cch-plan <idea\|design\|plan>` | Smart Entry: 설계(인터뷰) → 플래닝 → TODO 작성 통합 워크플로우 |
| **cch-full-pipeline** | `/cch-full-pipeline <설명>` | PRD 인터뷰 → 팀 빌드 → 병렬 구현 → 컨센서스 검증 → 딜리버리 |
| **cch-team** | `/cch-team` | dev → test → verify 파이프라인 (3인 팀 에이전트) |

### 코드/검증

| 이름 | 호출 | 설명 |
|------|------|------|
| **cch-commit** | `/cch-commit` | 논리 단위 커밋 + `Bead:` 트레일러 + 코드 간소화 서브에이전트 |
| **cch-verify** | `/cch-verify <대상>` | 구현 완료 전 증거 기반 검증 (debug + TDD 워크플로우 흡수) |
| **cch-review** | `/cch-review <branch\|PR\|range>` | 코드 리뷰 체크리스트 (Tier 1+에서 서브에이전트 디스패치) |

### 상태/관리

| 이름 | 호출 | 설명 |
|------|------|------|
| **cch-status** | `/cch-status` | CCH 건강 상태 — 모드, Tier, 건강도, 브랜치/Bead 정보 |
| **cch-todo** | `/cch-todo` | Beads(SSOT) + 세션 TaskList 통합 표시 |
| **cch-pr** | `/cch-pr` | Beads 링크 + TODO 참조 + 구조화된 PR 생성 |
| **cch-excalidraw** | `/cch-excalidraw <주제>` | Excalidraw 다이어그램 생성 → `docs/diagrams/` |
| **cch-pinchtab** | `/cch-pinchtab` | PinchTab 기반 웹 UI 테스트/디버깅/워크플로우 오케스트레이터 |
| **cch-skill-manager** | `/cch-skill-manager <cmd>` | 스킬 관리 — list/info/lint/create/edit/deps/search |

---

## 6. Skills — CCH Superpowers 위임 (cch-sp-*)

> superpowers 스킬을 CCH 환경에서 래핑. `bin/cch sources ensure superpowers` 필수.

| # | 이름 | 위임 대상 | 설명 |
|---|------|-----------|------|
| 1 | **cch-sp-brainstorm** | `superpowers:brainstorming` | 코드 작성 전 구조화된 디자인 대화 |
| 2 | **cch-sp-write-plan** | `superpowers:writing-plans` | TDD 바이트사이즈 구현 계획 작성 |
| 3 | **cch-sp-execute-plan** | `superpowers:executing-plans` | 배치 3개씩 실행 + 아키텍트 리뷰 체크포인트 |
| 4 | **cch-sp-subagent-dev** | `superpowers:subagent-driven-development` | 태스크당 서브에이전트 + 2단계 리뷰(스펙 + 품질) |
| 5 | **cch-sp-tdd** | `superpowers:test-driven-development` | Red-Green-Refactor 강제 |
| 6 | **cch-sp-debug** | `superpowers:systematic-debugging` | 4단계 체계적 디버깅 |
| 7 | **cch-sp-verify** | `superpowers:verification-before-completion` | 증거 기반 완료 검증 |
| 8 | **cch-sp-code-review** | `superpowers:requesting-code-review` | 코드 리뷰어 서브에이전트 디스패치 |
| 9 | **cch-sp-receive-review** | `superpowers:receiving-code-review` | 리뷰 피드백의 기술적 검증 |
| 10 | **cch-sp-git-worktree** | `superpowers:using-git-worktrees` | 격리된 git worktree 생성 + 안전 검증 |
| 11 | **cch-sp-finish-branch** | `superpowers:finishing-a-development-branch` | 브랜치 완료 후 merge/PR/keep/discard 옵션 |
| 12 | **cch-sp-parallel-agents** | `superpowers:dispatching-parallel-agents` | 독립 문제별 병렬 에이전트 디스패치 |

---

## 7. Skills — Ruflo Framework (cch-rf-*)

> `bin/cch sources ensure ruflo` 필수.

| # | 이름 | 호출 | 설명 |
|---|------|------|------|
| 1 | **cch-rf-doctor** | `/cch-rf-doctor [--fix]` | Ruflo 시스템 진단 — Node.js/npm/메모리DB/MCP 건강 체크 |
| 2 | **cch-rf-hive** | `/cch-rf-hive <주제>` | Byzantine FT 컨센서스 — N개 워커 병렬 평가 → 2/3 다수결 |
| 3 | **cch-rf-memory** | `/cch-rf-memory <store\|search\|retrieve\|status>` | HNSW 벡터 기반 에이전트 공유 메모리 |
| 4 | **cch-rf-security** | `/cch-rf-security <scan\|audit\|report>` | 보안 스캔 + CVE 감사 + 보고서 생성 |
| 5 | **cch-rf-sparc** | `/cch-rf-sparc <태스크>` | SPARC 방법론 — Spec → Pseudocode → Architecture → Refine → Complete |
| 6 | **cch-rf-swarm** | `/cch-rf-swarm <init\|status\|stop>` | 멀티에이전트 스웜 (hierarchical/mesh/hybrid/adaptive 토폴로지) |

---

## 8. Skills — GPTaku Plugins (cch-gp-*)

> `bin/cch sources ensure gptaku_plugins` + 서브모듈 초기화 필수.

| # | 이름 | 호출 | 서브모듈 | 설명 |
|---|------|------|----------|------|
| 1 | **cch-gp-docs** | `/cch-gp-docs <라이브러리>` | `plugins/docs-guide` | 68+ 라이브러리 llms.txt 패턴 문서 조회 |
| 2 | **cch-gp-mentor** | `/cch-gp-mentor [analyze\|mentor\|report]` | `plugins/vibe-sunsang` | AI 멘토 — 개발자 성장 분석 + 멘토링 세션 |
| 3 | **cch-gp-prd** | `/cch-gp-prd <아이디어>` | `plugins/show-me-the-prd` | 한 문장으로 PRD/User Stories/Tech Spec/API Design 4문서 생성 |
| 4 | **cch-gp-research** | `/cch-gp-research <주제>` | `plugins/deep-research` | 7단계 딥 리서치 — 멀티에이전트 교차 검증 + 신뢰도 등급 |
| 5 | **cch-gp-pumasi** | `/cch-gp-pumasi <태스크>` | `plugins/pumasi` | Claude PM + Codex 워커 병렬 코딩 |
| 6 | **cch-gp-playground** | `/cch-gp-playground <이름>` | `plugins/test-playground` | 스킬/플러그인 프로토타이핑 실험 환경 |
| 7 | **cch-gp-git-learn** | `/cch-gp-git-learn [stage1-5\|status]` | `plugins/git-teacher` | Git/GitHub 5단계 온보딩 (클라우드 비유) |
| 8 | **cch-gp-skill-builder** | `/cch-gp-skill-builder <아이디어>` | `plugins/skillers-suda` | 4페르소나 인터뷰로 Claude Code 스킬 빌드 |
| 9 | **cch-gp-team** | `/cch-gp-team <설명>` | `plugins/kkirikkiri` | 자연어로 AI 에이전트 팀 구성 (Claude+Codex+Gemini) |

---

## 9. Skills — PinchTab (cch-pt-*)

> `cch-pinchtab` 오케스트레이터의 서브에이전트로 사용.

| # | 이름 | 호출 | 설명 |
|---|------|------|------|
| 1 | **cch-pt-infra** | `/cch-pt-infra <status\|start\|stop\|cleanup>` | PinchTab 서버 생명주기 + 인스턴스/프로필 관리 (기본 포트 9867) |
| 2 | **cch-pt-test** | `/cch-pt-test` | PinchTab API로 웹 UI 테스트 실행 (YAML 시나리오 또는 자연어) |
| 3 | **cch-pt-report** | `/cch-pt-report` | 테스트/워크플로우 결과 → Markdown 보고서 생성 |

**지원 액션:** navigate, snapshot, click, fill, type, press, text, screenshot, evaluate, wait
**Assert 패턴:** contains, not_contains, not_empty, equals

---

## 10. Skills — Dist-only 추가 스킬

> 소스 `skills/`에는 없고 `dist/` 번들에만 존재하는 스킬.

| 이름 | 호출 | 설명 |
|------|------|------|
| **cch-dot** | `/cch-dot <on\|off>` | DOT (Dance of Tal) 실험 토글 (code 모드 전용) |
| **cch-hud** | `/cch-hud [status\|config\|reset\|element]` | HUD 상태줄 설정 — 모드/건강/Bead/토큰 사용량 표시 |
| **cch-mode** | `/cch-mode <plan\|code>` | CCH 운영 모드 전환 |
| **cch-release** | `/cch-release <version>` | 버전 태그 릴리즈 번들 생성 |
| **cch-sync** | `/cch-sync` | CCH 바이너리/스킬을 플러그인 캐시에 동기화 |
| **cch-update** | `/cch-update` | CCH 업데이트 확인 및 적용 |

---

## 11. CLI 명령어 (bin/cch)

**바이너리:** `bin/cch` (bash 스크립트)

| 명령어 | 설명 |
|--------|------|
| `cch setup` | 환경 초기화, Tier 탐지, v1→v2 마이그레이션, 건강 상태 기록 |
| `cch mode [plan\|code]` | 운영 모드 조회/설정 |
| `cch status [--json]` | 건강 상태, 모드, Tier, 이유 코드, 브랜치 정보 |
| `cch branch [cmd]` | 브랜치 워크플로우 관리 (`lib/branch.sh`) |
| `cch beads [cmd]` | Beads 태스크 추적: create/list/show/ready/close/dep (`lib/beads.sh`) |
| `cch todo` | `cch beads list` 별칭 |
| `cch log [show\|tail]` | 실행 로그 뷰어 (`lib/log.sh`) |
| `cch skill list` | 모든 스킬 소스를 스캔하여 JSON 배열 반환 |
| `cch skill info <name>` | 특정 스킬의 상세 정보 |
| `cch skill search <query>` | 이름/설명 대소문자 무관 검색 |
| `cch skill sources` | 설정된 스킬 소스 경로 목록 |
| `cch skill validate <file>` | SM001/002/003/010 규칙으로 SKILL.md 검증 |
| `cch version` | 버전 표시 |
| `cch help` | 도움말 |

**lib 모듈:**
- `lib/skill.sh` — 스킬 파싱, 스캔, 검증, 검색
- `lib/beads.sh` — Beads/bd CLI 통합
- `lib/branch.sh` — git 브랜치 상태 관리
- `lib/lock.sh` — 파일 잠금
- `lib/log.sh` — 실행 로그 기록

---

## 12. Slash Commands

### superpowers 커맨드

| 커맨드 | 위임 스킬 | 설명 |
|--------|-----------|------|
| `/brainstorm` | `superpowers:brainstorming` | 구현 전 요구사항/디자인 탐색 |
| `/execute-plan` | `superpowers:executing-plans` | 리뷰 체크포인트 포함 배치 실행 |
| `/write-plan` | `superpowers:writing-plans` | 바이트사이즈 구현 계획 작성 |

### CCH 커맨드

> 각 `cch-*` 스킬이 `user-invocable: true`로 선언되면 자동으로 `/cch-*` 슬래시 커맨드로 사용 가능.

주요 커맨드: `/cch-plan`, `/cch-commit`, `/cch-todo`, `/cch-setup`, `/cch-status`, `/cch-verify`, `/cch-review`, `/cch-pr`, `/cch-lsp`, `/cch-excalidraw`, `/cch-pinchtab`, `/cch-full-pipeline`, `/cch-team`, `/cch-skill-manager`, `/cch-arch-guide`, `/cch-init` 등

---

## 13. CCH Tier 시스템

| Tier | 조건 | 해금 기능 |
|------|------|-----------|
| **0** | CCH 코어만 설치 | 기본 스킬, CLI |
| **1** | CCH + 1개 이상 플러그인 | Superpowers 강화, 서브에이전트 코드 리뷰, TDD 강제 |
| **2** | CCH + 플러그인 + MCP 서버 | Serena 심볼릭 분석, 풀 MCP 도구 통합 |

Tier 산정: `_calculate_tier()` in `bin/cch` — `~/.claude/plugins/cache/` 플러그인 수 + `~/.claude/mcp.json` MCP 서버 수 기반.

---

## 14. 상태 관리

모든 런타임 상태는 프로젝트 루트의 `.claude/cch/` 아래 저장:

| 경로 | 내용 |
|------|------|
| `.claude/cch/mode` | 현재 모드 (`plan` / `code`) |
| `.claude/cch/health` | 건강 상태 (`Healthy` / `Degraded` / `Blocked`) |
| `.claude/cch/health_reason` | 쉼표 구분 이유 코드 |
| `.claude/cch/tier` | Tier 레벨 (0/1/2) |
| `.claude/cch/last_activity` | 마지막 활동 타임스탬프 |
| `.claude/cch/last_question` | 마지막 사용자 질문 |
| `.claude/cch/last_summary` | 마지막 세션 요약 |
| `.claude/cch/execution-plan.json` | 현재 실행 계획 (plan-bridge 생성) |
| `.claude/cch/branches/<branch>.yaml` | 브랜치-Bead 매핑 |
| `.claude/cch/init/` | cch-init 파이프라인 상태 |
| `.claude/cch/state/logs/` | 실행 로그 |
| `.claude/cch/runs/` | 실행 JSONL 기록 |
| `.claude/cch/sessions/` | 세션 상태 |
| `.claude/cch/metrics/` | TDD 적용 메트릭 등 |

**Beads 통합:**
- CLI: `bd` (Beads CLI) → `.beads/config.yaml`, `.beads/beads.db` (SQLite)
- git 추적용: `.beads/issues.jsonl`
- 커밋 트레일러: `Bead: <bead-id>`

**프로필:**
- `profiles/code.json` — code 모드 추천 스킬 (commit, verify, review, TDD 등)
- `profiles/plan.json` — plan 모드 추천 스킬 (brainstorming, writing-plans, cch-plan 등)

---

## 15. 스킬 의존성 그래프

```
brainstorming / cch-sp-brainstorm / cch-plan(Phase 1)
  └─→ writing-plans / cch-sp-write-plan / cch-plan(Phase 2)
       ├─→ subagent-driven-development / cch-sp-subagent-dev (같은 세션)
       │    ├─ REQUIRES: using-git-worktrees / cch-sp-git-worktree
       │    ├─ USES: test-driven-development / cch-sp-tdd (구현 서브에이전트)
       │    ├─ USES: requesting-code-review / cch-sp-code-review (태스크마다)
       │    ├─ USES: receiving-code-review / cch-sp-receive-review (피드백 시)
       │    └─ REQUIRES: finishing-a-development-branch / cch-sp-finish-branch
       └─→ executing-plans / cch-sp-execute-plan (병렬 세션)
            ├─ REQUIRES: using-git-worktrees / cch-sp-git-worktree
            └─ REQUIRES: finishing-a-development-branch / cch-sp-finish-branch

systematic-debugging / cch-sp-debug
  ├─→ test-driven-development (Phase 4, Step 1)
  └─→ verification-before-completion

cch-plan Smart Entry
  ├─ 아이디어 텍스트 → Phase 1 (Design)
  ├─ *-design.md → Phase 2 (Plan)
  └─ *-impl.md → Phase 3 (TODO Sync)

cch-full-pipeline
  └─→ PRD Generation → Team Building → Parallel Implementation → Consensus Verification → Delivery

cch-pinchtab
  └─→ cch-pt-infra → cch-pt-test → cch-pt-report
```

---

## 스킬 소스 경로

| 소스 ID | 경로 | 타입 |
|---------|------|------|
| `cch-repo` | `./skills/` (프로젝트 루트) | 개발 |
| `cch-cache` | `~/.claude/plugins/cache/claude-code-harness-marketplace/.../skills/` | 배포 (v0.1.0) |
| `superpowers` | `~/.claude/plugins/cache/superpowers-marketplace/.../skills/` | 외부 |
| `custom` | `~/.claude/commands/` | 사용자 정의 |

---

## 총 구성 요소 수 요약

| 카테고리 | 수량 |
|----------|------|
| **Hooks** | 10 (superpowers 1 + CCH 9) |
| **Agents** | 2 (superpowers code-reviewer + CCH skill-analyzer) |
| **Superpowers 스킬** | 14 |
| **CCH Core 스킬** | 19 |
| **CCH SP 위임 스킬 (cch-sp-*)** | 12 |
| **Ruflo 스킬 (cch-rf-*)** | 6 |
| **GPTaku 스킬 (cch-gp-*)** | 9 |
| **PinchTab 스킬 (cch-pt-*)** | 3 |
| **Dist-only 스킬** | 6 |
| **CLI 명령어** | 15+ |
| **Slash Commands** | 3 (superpowers) + 20+ (CCH) |
| **총 스킬 수** | **~69** |
