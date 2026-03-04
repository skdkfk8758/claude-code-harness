# TODO: CCH v2 Agent Harness Renewal

- 기준 문서: `docs/plans/2026-03-04-cch-v2-harness-renewal.md`
- 경량화 검토: `docs/plans/2026-03-04-cch-v2-lightweight-review.md`
- 작성일: 2026-03-04
- 상태: Phase 0 진행 중

---

## Phase 0: 정리 및 제거 (Cleanup & Removal)

플랜 섹션 16 기반. v2 구현 전 불필요 코드 제거.

### P0-A: 독립 디렉터리/파일 삭제 (의존성 없음)

- [x] #1 `dot/` 디렉터리 삭제 (DOT 실험 종료) — **완료 2026-03-04**
- [ ] #2 `overlays/` 디렉터리 삭제 (.gitkeep만 존재)
- [ ] #3 `src/` 디렉터리 삭제 (빈 디렉터리)
- [ ] #4 불필요 매니페스트 6개 삭제: `kpi-schema`, `slo-definitions`, `architecture-levels`, `release-channels`, `release-manifest-schema`, `capability-schema`
- [ ] #5 `manifests/resolved-schema.json` 삭제

### P0-B: 벤더 래퍼 스킬 삭제

- [ ] #6 `skills/cch-sp-*` 12개 삭제 (superpowers 래퍼)
- [x] #7 `skills/cch-gp-*` 9개 삭제 (gptaku 래퍼) — **완료 2026-03-04**
- [x] #8 `skills/cch-rf-*` 6개 삭제 (ruflo 래퍼) — **완료 2026-03-04**
- [ ] #9 `skills/cch-pt-*` 3개 삭제 (pinchtab 래퍼, `cch-pinchtab` 가이드는 유지)
- [x] #10-a `skills/cch-dot` 삭제 — **완료 2026-03-04**
- [ ] #10-b 유틸리티 스킬 삭제: `cch-release`, `cch-update`, `cch-sync`, `cch-hud`, `cch-mode`

### P0-C: 코어 라이브러리/스크립트 삭제

- [ ] #11 `bin/lib/sources.sh` 삭제 (918줄) + `bin/cch`에서 source 라인 제거
- [ ] #12 `bin/lib/kpi.sh` 삭제 (83줄) + `bin/cch`에서 KPI 함수 호출 제거
- [ ] #13 `scripts/mode-detector.sh`에서 swarm/tool 모드 감지 제거 — **부분 완료 2026-03-04** (삭제 대신 코드 축소)
- [ ] #14 `scripts/build-release.sh` 삭제 (릴리즈 재설계)
- [ ] #15 `scripts/tdd-enforcer.sh`, `scripts/todo-sync-check.sh`, `scripts/plan-doc-reminder.sh` 삭제

### P0-D: 벤더 관련 테스트 삭제

- [ ] #16 `tests/test_source_types.sh` 삭제
- [ ] #17 `tests/test_vendor_integration.sh` 삭제
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

### P0-E: bin/cch 내부 리팩터링 (2,069줄 → ~500줄)

- [ ] #21 JSON 파서 bash 코드 삭제 (110-118줄)
- [ ] #22 `_list_available_sources`, `check_source_available` 삭제 (120-300줄)
- [ ] #23 `_compute_source_hash`, `_do_resolve`, `_apply_fallback_order` 삭제 (301-502줄)
- [ ] #24 `cmd_doctor` 삭제 (903-1190줄, status에 통합)
- [ ] #25 DOT 관련 함수 전체 삭제 (1192-1330줄)
- [ ] #26 KPI 관련 함수 전체 삭제 (1336-1449줄)
- [ ] #27 업데이트/릴리즈/싱크 함수 축소 (1451-1899줄 → ~100줄)
- [ ] #28 `cmd_setup` 변환 (80줄 → ~50줄, Tier 판정 추가)
- [ ] #29 `cmd_mode` 변환 (55줄 → ~30줄, 정책 기반)
- [ ] #30 `cmd_status` + `cmd_status_json` 변환 (191줄 → ~80줄, Tier/HRP 정보)
- [ ] #31 메인 디스패처 변환 (169줄 → ~60줄, 서브커맨드 12→7)

> Phase 0 완료 기준: 전체 코드베이스 ~60% 감소, 남은 코드 컴파일/기본 동작 확인

---

## Phase 1: 기반 구축 (Foundation)

플랜 섹션 3, 10, 13, 15(G1) 기반.

- [ ] #32 Version Gate 구현 — `.claude/cch/version` 파일 기반 v1/v2 분기 (G1)
- [ ] #33 `policies/` 디렉터리 신설 — `workflows.json`, `health.json` 초안 작성
- [ ] #34 매니페스트 통합 (14→4): `command-contract.json`, `error-codes.json` 유지, `health-rules.json` → `policies/health.json` 이전
- [ ] #35 프로필 정리: `profiles/code.json` → `profiles/work.json` 리네임, `profiles/swarm.json` 삭제
- [ ] #36 v2 상태 디렉터리 구조 생성 (`state/`, `scan-result.json`, `sessions/`, `gc/`, `logs/`)
- [ ] #37 `bin/cch`에 Tier 판정 기본 로직 추가 (`_calculate_tier()`, `_check_tier()`)

> Phase 1 완료 기준: v2 디렉터리 구조 확립, `cch setup` 실행 시 v2 구조 생성

---

## Phase 2: Harness Engine 코어 (3대 엔진)

플랜 섹션 6 기반.

### P2-A: Context Engine

- [ ] #38 `scripts/context-engine.mjs` 생성 — 프로젝트 분석 기본 로직
- [ ] #39 Progressive Disclosure 구현 — CLAUDE.md/AGENTS.md 자동 생성
- [ ] #40 Context Budget Manager — 토큰 예산 할당/추적 기본 구현
- [ ] #41 Context Enrichment — 프로젝트 타입별 컨텍스트 주입

### P2-B: Policy Engine

- [ ] #42 `scripts/policy-engine.mjs` 생성 — 정책 JSON 로더/파서
- [ ] #43 워크플로우 규칙 엔진 — `policies/workflows.json` 기반 파이프라인 실행
- [ ] #44 모드 관리 — plan/work/tool 모드 전환 (정책 기반)
- [ ] #45 품질 게이트 — `policies/health.json` 기반 헬스 판정 (Healthy/Degraded/Blocked + reason_code)

### P2-C: Lifecycle Engine

- [ ] #46 `scripts/lifecycle.mjs` 생성 — 세션 상태 관리
- [ ] #47 GC (Garbage Collection) — 오래된 상태/로그 자동 정리
- [ ] #48 Context Replay — `summary-writer.mjs` 확장, 세션 이어가기
- [ ] #49 실행 증적 기록 — JSONL 기반 start/end/duration/result 로깅

> Phase 2 완료 기준: 3대 엔진 독립 동작, `cch status`에서 엔진 상태 확인 가능

---

## Phase 3: HRP (Harness Reinforcement Protocol)

플랜 섹션 5, 15(G4) 기반.

- [ ] #50 `scripts/hrp-scanner.mjs` 생성 — 5-Layer 환경 스캔 (플러그인/MCP/CLI/스킬/프로젝트)
- [ ] #51 Fingerprint 캐시 구현 — `scan-result.json` 해시 비교로 변경 없으면 스킵
- [ ] #52 Delta Scan — 이전 스캔 결과 대비 변경분만 감지
- [ ] #53 Deep Probe — 새 소스 능력 테스트 (타임아웃 안전 장치 포함)
- [ ] #54 3-Layer Scan Budget 통합 — 5초 성능 보장 (G4)
- [ ] #55 HRP Classifier — 감지된 변화를 Safe/Moderate/High로 분류
- [ ] #56 HRP Integrator — Safe=자동 통합, Moderate/High=승인 후 통합
- [ ] #57 `cch scan` 커맨드 추가 — HRP 수동 트리거

> Phase 3 완료 기준: `cch scan`이 5초 내 환경 스캔, omc/superpowers 감지 시 Tier 자동 승격

---

## Phase 4: Tier 시스템

플랜 섹션 4, 15(G3) 기반.

- [ ] #58 Tier State Machine 구현 — Tier 0/1/2 상태 전이 규칙
- [ ] #59 세션 내 Tier 잠금 — 세션 시작 시 결정, 종료까지 유지
- [ ] #60 Graceful Degradation — 플러그인 제거 시 `pending_downgrade` + 다음 세션 적용
- [ ] #61 preserved_config 패턴 — Tier 강등 시 사용자 설정 보존, 재승급 시 복원
- [ ] #62 `cch status`에 Tier 정보 표시 — 현재 Tier, 감지된 플러그인 목록

> Phase 4 완료 기준: Tier 0/1/2 전환이 HRP 스캔 결과에 따라 자동 동작

---

## Phase 5: 코어 스킬 구현

플랜 섹션 7, 15(G2, G5) 기반.

### P5-A: Tier-Aware Skill Template

- [ ] #63 스킬 템플릿 설계 — `SKILL.md` + `adapter.sh` + `tier_behavior` 구조
- [ ] #64 스킬 라우터 구현 — 현재 Tier에 따라 적절한 구현으로 디스패치

### P5-B: 9개 코어 스킬

- [ ] #65 `cch-brainstorm` 구현 — Tier 0: 프롬프트 체인, Tier 1: omc planner, Tier 2: 멀티에이전트
- [ ] #66 `cch-plan` 변환 — 기존 스킬에 Tier-aware 동작 추가
- [ ] #67 `cch-commit` 변환 — 기존 스킬에 Tier-aware 동작 추가
- [ ] #68 `cch-todo` 변환 — 기존 스킬에 Tier-aware 동작 추가
- [ ] #69 `cch-verify` 구현 — Tier 0: 테스트 실행, Tier 1: verifier 에이전트
- [ ] #70 `cch-review` 구현 — Tier 0: 체크리스트, Tier 1: code-reviewer 에이전트
- [ ] #71 `cch-debug` 구현 — Tier 0: 에러 분석, Tier 1: debugger 에이전트
- [ ] #72 `cch-tdd` 구현 — Tier 0: red-green-refactor 가이드, Tier 1: test-engineer
- [ ] #73 `cch-setup` 변환 — 환경 스캔 + Tier 판정 + HRP 트리거

### P5-C: 스킬 테스트 (G5)

- [ ] #74 Contract Test — 전체 스킬 계약 검증 (SKILL.md 스펙)
- [ ] #75 Behavior Test — 스킬별 Tier 0/1/2 동작 검증 (mock 환경)
- [ ] #76 Integration Test — 워크플로우 파이프라인 통합 테스트

> Phase 5 완료 기준: 9개 코어 스킬 Tier 0 동작, 스킬당 최소 3개 테스트 (27+ 케이스)

---

## Phase 6: 통합 및 Hook/Engine 연결

플랜 섹션 15(G6) 기반.

- [ ] #77 Hook→CLI→Engine 호출 체인 구현 (G6)
- [ ] #78 `hooks/hooks.json` v2 갱신 — SessionStart에 HRP 스캔, PreToolUse에 Tier 컨텍스트
- [ ] #79 훅 스크립트 최적화 (7→3): activity-tracker, summary-writer, plan-bridge 유지
- [ ] #80 Engine 반환 계약 통일 — `{success, result, duration_ms}` 표준화
- [ ] #81 `cch status --json` v2 — Tier/HRP/Engine 상태 포함

> Phase 6 완료 기준: 전체 호출 체인 동작, `cch status --json`에 모든 v2 정보 포함

---

## Phase 7: 마이그레이션

플랜 섹션 11, 15(G1, G7) 기반.

- [ ] #82 v1→v2 마이그레이션 도구 구현 — 자동 변환 + v1 백업 보존
- [ ] #83 Feature Parity Matrix 검증 (G7) — v1 `cmd_*` 함수 전수 대응 확인
- [ ] #84 마이그레이션 가이드 문서 작성 — `docs/guide/migration-v1-to-v2.md`
- [ ] #85 v1 롤백 경로 검증 — `cch rollback-to-v1` 실동작 확인

> Phase 7 완료 기준: v1 환경에서 `cch setup` 실행 시 자동 마이그레이션, 5분 이내 완료

---

## Phase 8: 검증 및 릴리즈

플랜 섹션 12 기반.

- [ ] #86 전체 테스트 스위트 통과 — contract + behavior + integration
- [ ] #87 HRP 스캔 성능 벤치마크 — 5초 이내 확인
- [ ] #88 Tier 전환 E2E 테스트 — Tier 0→1→2 승격/강등 시나리오
- [ ] #89 클린 환경 smoke 테스트 — `setup → scan → status → brainstorm → plan → commit`
- [ ] #90 문서 동기화 — PRD/Architecture/Roadmap/TODO v2 기준 갱신
- [ ] #91 릴리즈 번들 생성 — plugin.json/marketplace.json 갱신
- [ ] #92 "Build for Deletion" 체크 — 각 컴포넌트 삭제 조건 문서화 확인

> Phase 8 완료 기준: 12.1/12.2 성공 기준 전항 충족, 릴리즈 번들 배포 준비 완료

---

## Critical Path

```
Phase 0 (제거) → Phase 1 (기반) → Phase 2 (엔진) → Phase 3 (HRP) → Phase 4 (Tier)
                                                                         ↓
Phase 8 (릴리즈) ← Phase 7 (마이그레이션) ← Phase 6 (통합) ← Phase 5 (스킬)
```

병렬 가능:
- Phase 2-A/B/C (3대 엔진)는 병렬 구현 가능
- Phase 3 (HRP)과 Phase 5-A (스킬 템플릿)는 병렬 가능
- Phase 7 (마이그레이션)은 Phase 1 (기반) 이후 언제든 시작 가능

---

## 수치 요약

| 구분 | 항목 수 |
|------|---------|
| 전체 TODO | 92개 |
| Phase 0 (제거) | 31개 |
| Phase 1 (기반) | 6개 |
| Phase 2 (엔진) | 12개 |
| Phase 3 (HRP) | 8개 |
| Phase 4 (Tier) | 5개 |
| Phase 5 (스킬) | 14개 |
| Phase 6 (통합) | 5개 |
| Phase 7 (마이그레이션) | 4개 |
| Phase 8 (릴리즈) | 7개 |
