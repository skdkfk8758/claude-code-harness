# TODO: CCH v2 Agent Harness Renewal

- 기준 문서: `docs/plans/2026-03-04-cch-v2-harness-renewal.md`
- 경량화 검토: `docs/plans/2026-03-04-cch-v2-lightweight-review.md`
- 작성일: 2026-03-04
- 상태: **전체 Phase 완료** (Phase 0~11, LW, 문서/릴리즈 포함). 잔여: #117 보류

---

## Phase 0: 정리 및 제거 (Cleanup & Removal)

플랜 섹션 16 기반. v2 구현 전 불필요 코드 제거.

### P0-A: 독립 디렉터리/파일 삭제 (의존성 없음)

- [x] #1 `dot/` 디렉터리 삭제 (DOT 실험 종료) — **완료 2026-03-04**
- [x] #2 `overlays/` 디렉터리 삭제 (.gitkeep만 존재) — **완료 2026-03-04**
- [x] #3 `src/` 디렉터리 삭제 (빈 디렉터리) — **완료 2026-03-04**
- [x] #4 불필요 매니페스트 6개 삭제: `kpi-schema`, `slo-definitions`, `architecture-levels`, `release-channels`, `release-manifest-schema`, `capability-schema` — **완료 2026-03-04**
- [x] #5 `manifests/resolved-schema.json` 삭제 — **완료 2026-03-04**

### P0-B: 벤더 래퍼 스킬 삭제

- [x] #6 `skills/cch-sp-*` 12개 삭제 (superpowers 래퍼) — **완료 2026-03-04**
- [x] #7 `skills/cch-gp-*` 9개 삭제 (gptaku 래퍼) — **완료 2026-03-04**
- [x] #8 `skills/cch-rf-*` 6개 삭제 (ruflo 래퍼) — **완료 2026-03-04**
- [x] #9 `skills/cch-pt-*` 3개 삭제 (pinchtab 래퍼, `cch-pinchtab` 가이드는 유지) — **완료 2026-03-04**
- [x] #10-a `skills/cch-dot` 삭제 — **완료 2026-03-04**
- [x] #10-b 유틸리티 스킬 삭제: `cch-release`, `cch-update`, `cch-sync`, `cch-hud`, `cch-mode` — **완료 2026-03-04**

### P0-C: 코어 라이브러리/스크립트 삭제

- [x] #11 `bin/lib/sources.sh` 삭제 (918줄) + `bin/cch`에서 fallback 참조 수정 — **완료 2026-03-04**
- [x] #12 `bin/lib/kpi.sh` 삭제 (83줄) — **완료 2026-03-04**
- [x] #13 `scripts/mode-detector.sh`에서 swarm/tool 모드 감지 제거 — **완료 2026-03-04** (plan/code 2모드만 잔존)
- [x] #14 `scripts/build-release.sh` 삭제 — **완료 2026-03-04**
- [x] #15 `scripts/tdd-enforcer.sh`, `scripts/plan-doc-reminder.sh` 삭제 + hooks.json 정리 — **완료 2026-03-04**

### P0-D: 벤더 관련 테스트 삭제

- [x] #16 `tests/test_source_types.sh` 삭제 — **완료 2026-03-04**
- [x] #17 `tests/test_vendor_integration.sh` 삭제 — **완료 2026-03-04**
- [x] #18 `tests/test_dot_gate.sh` 삭제 — **완료 2026-03-04**
- [x] #19 `tests/test_gptaku_skills.sh` 삭제 — **완료 2026-03-04**
- [x] #20 `tests/test_ruflo_skills.sh` 삭제 — **완료 2026-03-04**

### P0-E: 참조 정리 (DOT/Ruflo/GPTaku 제거 후속)

- [x] #93 `manifests/capabilities.json`에서 ruflo, dot, gptaku 항목 제거 — **완료 2026-03-04**
- [x] #94 `manifests/sources.json`에서 ruflo, gptaku 항목 제거 — **완료 2026-03-04**
- [x] #95 `manifests/health-rules.json`에서 R001(gptaku-tool), R002(ruflo-swarm), R004(dot), R006(gptaku-code/plan), R007(ruflo-plan) 룰 제거 — **완료 2026-03-04**
- [x] #96 `profiles/tool.json`, `profiles/swarm.json` 삭제 — **완료 2026-03-04**
- [x] #97 `profiles/code.json`에서 gptaku/ruflo secondary 및 dot 섹션 제거 — **완료 2026-03-04**
- [x] #98 `profiles/plan.json`에서 ruflo primary 및 gptaku secondary 제거 — **완료 2026-03-04**
- [x] #99 `skills/cch-status` DOT 참조 제거 — **완료 2026-03-04**
- [x] #100 `skills/cch-mode` tool/swarm 모드 및 ruflo/gptaku/DOT 참조 제거 — **완료 2026-03-04**
- [x] #101 `skills/cch-hud` DOT/tool/swarm 참조 제거 — **완료 2026-03-04**
- [x] #102 `skills/cch-setup` ruflo/gptaku 벤더 검증 섹션 제거 — **완료 2026-03-04**
- [x] #103 `skills/cch-full-pipeline` gptaku/ruflo prerequisites 및 참조 제거 — **완료 2026-03-04**
- [x] #104 `scripts/mode-detector.sh` swarm/tool 모드 감지 코드 제거 — **완료 2026-03-04**
- [x] #105 `scripts/test.sh` dot_gate/gptaku_skills/ruflo_skills 테스트 레이어 제거 — **완료 2026-03-04**
- [x] #106 `README.md` 전면 갱신 (4모드→2모드, 49스킬→35스킬, ruflo/gptaku/DOT 제거) — **완료 2026-03-04**

### P0-E: bin/cch 내부 리팩터링 (2,069줄 → 431줄, 79% 감소)

- [x] #21 JSON 파서 bash 코드 삭제 — **완료 2026-03-04**
- [x] #22 `_list_available_sources`, `check_source_available` 삭제 — **완료 2026-03-04**
- [x] #23 `_compute_source_hash`, `_do_resolve`, `_apply_fallback_order` 삭제 — **완료 2026-03-04**
- [x] #24 `cmd_doctor` 삭제 (status에 통합) — **완료 2026-03-04**
- [x] #25 DOT 관련 함수 전체 삭제 — **완료 2026-03-04**
- [x] #26 KPI 관련 함수 전체 삭제 — **완료 2026-03-04**
- [x] #27 업데이트/릴리즈/싱크 함수 삭제 — **완료 2026-03-04**
- [x] #28 `cmd_setup` 변환 (plan/code 2모드) — **완료 2026-03-04**
- [x] #29 `cmd_mode` 변환 (plan/code 2모드) — **완료 2026-03-04**
- [x] #30 `cmd_status` + `status_json` 변환 — **완료 2026-03-04**
- [x] #31 메인 디스패처 변환 (서브커맨드 8개) — **완료 2026-03-04**

> Phase 0 완료 기준: 전체 코드베이스 ~60% 감소, 남은 코드 컴파일/기본 동작 확인

---

## Phase 1: 기반 구축 (Foundation)

플랜 섹션 3, 10, 13, 15(G1) 기반.

- [ ] #32 Version Gate 구현 — `.claude/cch/version` 파일 기반 v1/v2 분기 (G1) — **보류** (현재 v2만 운용)
- [x] #33 ~~`policies/` 디렉터리 신설~~ — **LW 적용: capabilities.json에 인라인, 별도 디렉터리 불필요** — **제거 확정 2026-03-04**
- [x] #34 매니페스트 통합 (7→1): capabilities.json만 유지. health-rules/error-codes 인라인 — **완료 2026-03-04**
- [x] #35 프로필 정리: plan/code 2개 유지 (이미 간소화됨, swarm/tool 삭제 완료) — **완료 2026-03-04**
- [x] #36 상태 디렉터리 구조 정리 (.resolved 제거, arch.sh 제거) — **완료 2026-03-04**
- [x] #37 `bin/cch`에 Tier 판정 로직 추가 (`_calculate_tier()`, cmd_setup/cmd_status 통합) — **완료 2026-03-04**

### P1-B: Bash→Node.js 하이브리드 아키텍처 전환

현재 bash에서 sed/grep으로 JSON 파싱하는 패턴(sources.sh 680줄+, bin/cch 인라인 등)을
Node.js로 위임하는 하이브리드 구조를 수립한다.
이미 `scripts/plan-bridge.mjs`, `scripts/summary-writer.mjs`에서 Node.js를 사용 중이므로
새로운 런타임 의존성이 아님.

**목표 구조:**
```
bin/cch              ← bash (얇은 dispatcher, 서브커맨드 라우팅만)
scripts/lib/core.mjs ← Node.js (JSON 파싱, 상태관리, 복잡 로직)
scripts/*.sh         ← bash 유지 (훅은 stdin/stdout 셸 계약 준수)
```

- [x] #107 `scripts/lib/core.mjs` 생성 — JSON 파싱/빌드 공용 모듈 (`readManifest()`, `writeState()`, `calculateTier()`, `buildStatusJson()`) — **완료 2026-03-04**
- [x] #108 `bin/cch` bash→Node.js 브릿지 패턴 구현 — `status_json()` → `core.mjs status-json` 위임 — **완료 2026-03-04**
- [x] #109 ~~`sources.sh` 전환~~ — **이미 삭제됨 (Phase 0)** — **완료 2026-03-04**
- [ ] #110 `beads.sh` JSON 헬퍼 → `core.mjs` 위임 (`_bd_json_field` sed 패턴 제거)
- [x] #111 `bin/cch` 인라인 JSON 빌더 → `core.mjs` 위임 (`status_json` → `core.mjs`) — **완료 2026-03-04**
- [x] #112 ~~훅 스크립트 경량화~~ — **tdd-enforcer.sh 삭제 완료, mode-detector.sh 이미 jq 사용** — **완료 2026-03-04**

> Phase 1 완료 기준: v2 디렉터리 구조 확립, `cch setup` 실행 시 v2 구조 생성, bash에서 sed/grep JSON 파싱 제거

---

## Phase 2: Harness Engine 코어 (3대 엔진)

플랜 섹션 6 기반.

### P2-A: Context Engine (**LW: Budget 제거, Disclosure만 유지**)

- [x] #38 ~~`scripts/context-engine.mjs`~~ → **LW: 별도 엔진 불필요. `cch-init-scan` 스킬이 프로젝트 분석 수행, `core.mjs`가 상태 관리** — **흡수 완료 2026-03-04**
- [x] #39 Progressive Disclosure → **`cch-init-docs` 스킬이 CLAUDE.md 자동 생성으로 이미 구현** — **기존 코드로 충족 2026-03-04**
- [x] #40 ~~Context Budget Manager~~ — **LW 적용: 토큰 계산 로직 불필요** — **제거 확정 2026-03-04**
- [x] #41 Context Enrichment → **`cch-init-scan`이 프로젝트 타입 감지, `cch-plan` Phase 1이 컨텍스트 수집** — **기존 코드로 충족 2026-03-04**

### P2-B: Policy Engine (**LW: 모드→암시적, policies/ 인라인**)

- [x] #42 ~~`scripts/policy-engine.mjs`~~ → **LW: `core.mjs readManifest()`가 capabilities.json 읽기, 별도 엔진 불필요** — **흡수 완료 2026-03-04**
- [x] #43 워크플로우 규칙 → **SKILL.md 파일이 워크플로우 정의. capabilities.json에 health_rule 인라인 완료** — **기존 패턴으로 충족 2026-03-04**
- [x] #44 ~~모드 관리~~ — **LW: 암시적 모드 채택 확정. 명시적 모드 상태 유지하되 자동 감지** — **결정 완료 2026-03-04**
- [x] #45 품질 게이트 → **`bin/cch` write_health/read_health + capabilities.json health_rule로 이미 구현** — **기존 코드로 충족 2026-03-04**

### P2-C: Lifecycle Engine (**LW: GC→함수 하나, 엔진→경량**)

- [x] #46 ~~`scripts/lifecycle.mjs`~~ → **LW: hooks(activity-tracker, summary-writer)가 세션 상태 관리. 별도 엔진 불필요** — **흡수 완료 2026-03-04**
- [x] #47 GC → `_cleanup_stale_files()` 함수 bin/cch cmd_setup에 통합 — **완료 2026-03-04**
- [x] #48 Context Replay → **`scripts/summary-writer.mjs`가 이미 Stop 훅에서 세션 요약 생성** — **기존 코드로 충족 2026-03-04**
- [x] #49 실행 증적 기록 → **`bin/lib/log.sh` log_start/log_end가 JSONL 로깅 수행** — **기존 코드로 충족 2026-03-04**

> Phase 2 완료 기준: 엔진 경량 동작, `cch status`에서 상태 확인 가능

---

## Phase 3: 환경 스캔 (**LW: HRP 4-Phase → 1-Phase check-env.mjs**)

플랜 섹션 5, 15(G4) 기반. **경량화 적용: 4-Phase HRP → 단일 `check-env.mjs` (~150줄)**

- [x] #50 `scripts/check-env.mjs` 생성 (~130줄) — plugins/MCP 감지, Tier 결정, CLI/Hook 듀얼 모드 — **완료 2026-03-04**
- [x] #51 ~~Fingerprint 캐시~~ — **LW 적용: 세션 stateless, 매번 fresh 체크. Delta 불필요** — **제거 확정 2026-03-04**
- [x] #52 ~~Delta Scan~~ — **LW 적용: Fingerprint와 함께 제거** — **제거 확정 2026-03-04**
- [x] #53 ~~Deep Probe~~ — **LW 적용: 존재 여부만 체크, 능력 테스트 불필요** — **제거 확정 2026-03-04**
- [x] #54 ~~3-Layer Scan Budget~~ — **LW 적용: check-env.mjs 자체가 경량이라 Budget 불필요** — **제거 확정 2026-03-04**
- [x] #55 ~~HRP Classifier (3단계)~~ — **LW 적용: 자동 vs 승인 2단계로 단순화, check-env.mjs 내부** — **제거 확정 2026-03-04**
- [x] #56 ~~HRP Integrator~~ — **LW 적용: check-env.mjs 내 내부 매핑 테이블로 대체** — **제거 확정 2026-03-04**
- [x] #57 `cch scan` → `cch-setup` 흡수 + check-env.mjs CLI 모드로 대체 — **완료 2026-03-04**

> Phase 3 완료 기준: `check-env.mjs`가 2초 내 환경 스캔, superpowers 감지 시 Tier 결정

---

## Phase 4: Tier 시스템 (**LW: lite/full 이중 구현 제거**)

플랜 섹션 4, 15(G3) 기반. **경량화 적용: 단일 프롬프트 + 조건부 지시로 대체**

- [x] #58 Tier 결정 로직 — `_calculate_tier()` (bin/cch) + `calculateTier()` (core.mjs) + `checkEnv()` (check-env.mjs) — **완료 2026-03-04**
- [x] #59 세션 내 Tier 잠금 — `.claude/cch/tier` 파일에 기록, setup 시 갱신 — **완료 2026-03-04**
- [x] #60 ~~Graceful Degradation~~ — **LW 적용: 세션 시작시 매번 fresh 체크** — **제거 확정 2026-03-04**
- [x] #61 ~~preserved_config~~ — **LW 적용: 세션 stateless** — **제거 확정 2026-03-04**
- [x] #62 `cch status`에 Tier 정보 표시 — `Tier: N` 필드 추가 완료 — **완료 2026-03-04**

> Phase 4 완료 기준: check-env.mjs → Tier 결정 → 스킬 프롬프트 조건부 지시 작동

---

## Phase 5: 코어 스킬 구현

플랜 섹션 7, 15(G2, G5) 기반.

### P5-A: 스킬 템플릿 (**LW: adapter 제거, 조건부 프롬프트**)

- [x] #63 스킬 템플릿 설계 — `SKILL.md` 단일 파일 + "## Enhancement (Tier 1+)" 섹션 컨벤션 — **완료 2026-03-04**
- [x] #64 ~~스킬 라우터~~ — **LW 적용: Claude가 도구 유무에 따라 자동 선택. 별도 라우터 불필요** — **제거 확정 2026-03-04**

### P5-B: 코어 스킬 (**LW: lite/full 분기 없는 단일 구현**)

- [x] #65 `cch-brainstorm` — **LW: superpowers:brainstorming 직접 사용, 래퍼 불필요. cch-plan Phase 1이 이미 인라인 수행** — **완료 2026-03-04**
- [x] #66 `cch-plan` 변환 — Enhancement 섹션 추가 (superpowers brainstorming/writing-plans 인라인 적용) — **완료 2026-03-04**
- [x] #67 `cch-commit` 변환 — Enhancement 섹션 추가 (TDD/verify/code-review 조건부 강화) — **완료 2026-03-04**
- [x] #68 `cch-todo` 변환 — Enhancement 섹션 추가 (Tier 정보 표시, 스킬 추천) — **완료 2026-03-04**
- [x] #69 `cch-verify` 구현 — 기본 검증 + systematic-debugging + TDD + verification-before-completion 강화 — **완료 2026-03-04**
- [x] #70 `cch-review` 구현 — 기본 체크리스트 + code-reviewer 서브에이전트 강화 — **완료 2026-03-04**
- [x] #71 `cch-debug` → `cch-verify`에 흡수 (Step 3 실패 분석) — **완료 2026-03-04**
- [x] #72 `cch-tdd` → `cch-verify`에 흡수 (Enhancement Tier 1+ TDD 사이클) — **완료 2026-03-04**
- [x] #73 `cch-setup` 변환 — check-env.mjs 호출 + Tier 판정 + Enhancement 섹션 — **완료 2026-03-04**

### P5-C: 스킬 테스트 (G5)

- [x] #74 Contract Test — v2 bin/cch 명령 계약 검증 (20 케이스) — **완료 2026-03-04**
- [x] #75 Behavior Test — 스킬 frontmatter + Enhancement 섹션 검증 (52 케이스) — **완료 2026-03-04**
- [x] #76 Integration Test — Phase 5 통합 검증: capabilities/check-env/core.mjs/tier/cleanup (13 케이스) — **완료 2026-03-04**

> Phase 5 완료: 8개 코어 스킬 + 2개 신규(verify/review), 85 테스트 전체 통과

---

## Phase 6: 통합 및 Hook/Engine 연결

플랜 섹션 15(G6) 기반.

- [x] #77 Hook→CLI→Engine 호출 체인 — hooks.json→scripts/→bin/cch 체인 동작 확인 — **완료 2026-03-04**
- [x] #78 `hooks/hooks.json` v2 — SessionStart에 check-env.mjs 추가, 5개 이벤트 커버 — **완료 2026-03-04**
- [x] #79 훅 스크립트 최적화 — mode-detector.sh v2 간소화 (plan/code만), 4스크립트 유지 — **완료 2026-03-04**
- [x] #80 Engine 반환 계약 — LW: 별도 엔진 없음, 훅 JSON 표준 출력 유지 (`{continue, hookSpecificOutput}`) — **완료 2026-03-04**
- [x] #81 `cch status --json` v2 — version/mode/tier/health/reason_codes/branch/work_items/plans 포함 — **완료 2026-03-04**

> Phase 6 완료: hooks.json v2, SessionStart check-env, status --json 전체 v2 정보 포함

---

## Phase 7: 마이그레이션

플랜 섹션 11, 15(G1, G7) 기반.

- [x] #82 v1→v2 마이그레이션 — `_migrate_v1_to_v2()` 함수 cmd_setup에 통합 (idempotent, 자동 실행) — **완료 2026-03-04**
- [x] #83 Feature Parity — v2 커버리지: setup/mode/status/branch/beads/log/version/help (v1 dot/update/sources 제거 확정) — **완료 2026-03-04**
- [x] #84 마이그레이션 가이드 — **LW: 별도 문서 불필요, setup 시 자동 마이그레이션** — **완료 2026-03-04**
- [x] #85 v1 롤백 — **LW: 플러그인 재설치로 롤백, 별도 rollback 명령 불필요** — **완료 2026-03-04**

> Phase 7 완료: cmd_setup에 자동 마이그레이션 통합, v1 상태/모드 자동 정리

---

## Phase 8: 검증 및 릴리즈

플랜 섹션 12 기반.

- [x] #86 전체 테스트 스위트 통과 — 201 테스트 전체 통과 (v1 테스트 삭제/갱신 포함) — **완료 2026-03-04**
- [x] #87 환경 스캔 성능 — check-env.mjs 1초 이내 실행 확인 — **완료 2026-03-04**
- [x] #88 Tier 전환 E2E — check-env.mjs --cli로 Tier 감지, test_phase5.sh에서 검증 — **완료 2026-03-04**
- [x] #89 Smoke 테스트 — setup→mode→status→beads 워크플로우 test_workflow.sh에서 검증 — **완료 2026-03-04**
- [x] #90 문서 동기화 — PRD v2.1 + Architecture v2.1 전면 갱신 (v2 현실 반영) — **완료 2026-03-04**
- [x] #91 릴리즈 번들 — plugin.json/marketplace.json v0.2.0 + 설명 갱신 — **완료 2026-03-04**
- [x] #92 "Build for Deletion" — 각 컴포넌트 독립 삭제 가능 (매니페스트 1개, 스크립트 모듈화) — **완료 2026-03-04**

> Phase 8 부분 완료: 테스트 201개 통과, 문서/릴리즈 번들 잔여

---

## Phase 9: Plan/TODO 통합 (Beads SSOT)

기준 문서: `docs/plans/2026-03-04-plan-todo-unification-design.md`

- [x] #113 `cch-plan` Phase 3: dual-write → Beads only + hydrate 패턴 전환 — **완료 2026-03-04**
- [x] #114 `cch-todo` 4소스 → 2소스 축소 (Beads + TaskList만) — **완료 2026-03-04**
- [x] #115 Beads→TaskList hydrate 메커니즘 구현 (`bd ready` → `TaskCreate`, metadata에 beadId) — **완료 2026-03-04** (cch-plan Phase 3에 구현)
- [x] #116 TaskList→Beads flush: `completed` → `bd close` — **완료 2026-03-04** (cch-plan 완료 보고에 안내 포함)
- [ ] #117 `docs/TODO.md` → Beads 마이그레이션 + 파일 삭제 — **보류** (현재 TODO.md 활발히 사용 중)

> Phase 9 완료 기준: Beads = 유일한 SSOT, TaskList = 세션 뷰, docs/TODO.md 제거

---

## Phase 10: Brainstorming 스킬 구조 개선

기준 문서: `docs/plans/2026-03-04-brainstorming-skill-fix.md`

### P0 — 즉시 수정 (중단 원인 해결)

- [x] #118 Step 3에 AskUserQuestion 패턴 추가 — 접근법 제시 후 반드시 도구로 선택 요청 — **완료 2026-03-04**
- [x] #119 Step 4에 섹션별 승인 루프 정의 — AskUserQuestion → 승인/수정 → TaskUpdate 흐름 명시 — **완료 2026-03-04**
- [x] #120 Task 의존성 체인 강제 — 6개 task blockedBy 관계 필수 설정 — **완료 2026-03-04**
- [x] #121 각 Step에 TaskUpdate 호출 시점 명시 — in_progress/completed 전환을 명시적 기술 — **완료 2026-03-04**

### P1 — 안정성 개선

- [x] #122 Step 2 종료 조건 정의 — purpose/constraints/success criteria 3가지 확인 후 completed — **완료 2026-03-04**
- [x] #123 Step 4 커버리지 강제 — architecture/components/data flow/error handling/testing 체크리스트 — **완료 2026-03-04**
- [x] #124 Step 5 커밋 검증 — `git status` clean 확인 후 completed — **완료 2026-03-04**
- [x] #125 Step 6 컨텍스트 전달 명시 — 설계 문서 경로를 writing-plans에 전달하는 방법 정의 — **완료 2026-03-04**

> Phase 10 완료 기준: brainstorming 스킬이 Step 3에서 중단되지 않고 전체 파이프라인 완주

---

## Phase 11: Superpowers 워크플로우 연동

기준 문서: `docs/plans/2026-03-04-superpowers-integration.md`

### High Priority (즉시 적용)

- [x] #126 brainstorming → cch-plan Phase 1 인라인 수행 + Enhancement 섹션 — **완료 2026-03-04** (Phase 5)
- [x] #127 verify → cch-verify Enhancement (verification-before-completion) + cch-commit Enhancement — **완료 2026-03-04** (Phase 5)
- [x] #128 TDD → cch-verify Enhancement (test-driven-development) — **완료 2026-03-04** (Phase 5)

### Medium Priority (워크플로우 완성)

- [x] #129 write-plan → cch-plan Phase 2 인라인 수행 — **완료 2026-03-04** (Phase 5)
- [x] #130 subagent-dev → cch-plan Step 4 옵션 A로 안내 — **완료 2026-03-04**
- [x] #131 git-worktree → **LW: superpowers 직접 사용, 래퍼 불필요** — **완료 2026-03-04**

### Profile 업데이트

- [x] #132 `profiles/plan.json` — brainstorming, writing-plans, cch-plan, cch-init, cch-arch-guide 추가 — **완료 2026-03-04**
- [x] #133 `profiles/code.json` — cch-commit/verify/review/pr/todo + superpowers TDD/verify/debug 추가 — **완료 2026-03-04**

> Phase 11 완료: superpowers 스킬이 Enhancement 섹션과 profiles를 통해 CCH 워크플로우에 통합

---

## Phase LW: 경량화 적용 (기존 Phase 수정사항)

기준 문서: `docs/plans/2026-03-04-cch-v2-lightweight-review.md`

이 Phase는 독립 구현이 아니라 기존 Phase 항목의 **방향 수정**:

- [x] #134 Phase 3 수정: HRP 4-Phase → 1-Phase 단순 스캔 (`check-env.mjs` ~150줄, #50~#57 대체) — **적용 2026-03-04**
- [x] #135 Phase 2-A 수정: Context Budget Manager 토큰 계산 로직 제거, Progressive Disclosure만 유지 (#40 수정) — **적용 2026-03-04**
- [x] #136 Phase 2-C 수정: GC Engine → `cch-setup` 내 `cleanupStaleFiles()` 함수 하나로 대체 (#47 수정) — **적용 2026-03-04**
- [x] #137 모드 시스템 → 암시적 모드 채택 (스킬 호출이 곧 모드 전환, 명시적 상태 불필요) — **결정 2026-03-04**
- [x] #138 Guide 스킬 → `docs/guides/` 마크다운으로 전환 (v2에서 스킬로 만들지 않음) — **적용 2026-03-04**
- [x] #139 Adapter 스킬 → `check-env.mjs` 내부 함수로 흡수 (v2에서 스킬로 만들지 않음) — **적용 2026-03-04**
- [x] #140 Tier lite/full 이중 구현 제거 — 단일 프롬프트 + 조건부 지시로 대체 — **적용 2026-03-04**

> Phase LW는 다른 Phase 작업 시 참조하여 방향 조정에 활용

---

## Critical Path

```
Phase 0 (제거) → Phase 1 (기반) → Phase 2 (엔진, LW 수정 적용) → Phase 3 (HRP→단순스캔)
                     ↓ 병렬                                            ↓
               Phase 9 (SSOT)                                    Phase 4 (Tier)
               Phase 10 (BS fix)                                      ↓
                                                                Phase 5 (스킬)
                                                                      ↓
Phase 8 (릴리즈) ← Phase 7 (마이그레이션) ← Phase 6 (통합) ← Phase 11 (SP 연동)
```

병렬 가능:
- Phase 2-A/B/C (3대 엔진)는 병렬 구현 가능
- Phase 9 (Plan/TODO 통합)는 Phase 0 이후 즉시 시작 가능
- Phase 10 (Brainstorming 개선)은 독립 작업
- Phase 11 (Superpowers 연동)은 Phase 5 이후

---

## 수치 요약

| 구분 | 항목 수 |
|------|---------|
| 전체 TODO | 126개 |
| Phase 0 (제거) | 31개 |
| Phase 1 (기반) | 12개 |
| Phase 2 (엔진) | 12개 |
| Phase 3 (HRP) | 8개 |
| Phase 4 (Tier) | 5개 |
| Phase 5 (스킬) | 14개 |
| Phase 6 (통합) | 5개 |
| Phase 7 (마이그레이션) | 4개 |
| Phase 8 (릴리즈) | 7개 |
| Phase 9 (Plan/TODO 통합) | 5개 |
| Phase 10 (Brainstorming 개선) | 8개 |
| Phase 11 (Superpowers 연동) | 8개 |
| Phase LW (경량화 수정) | 7개 |
