# Roadmap: Claude Code Harness (Framework Upgrade)

- 기준일: 2026-03-03
- 버전: v2.0
- 현재 상태: Active (Week-1 Execution)
- 현재 마감: 2026-03-10 (화)

## 1) 완료된 기반 마일스톤 (2026-03-03 기준)

다음 기반은 구현/검증 완료로 간주한다. (상세 상태: `bd list --label "phase:1"` 등으로 조회)

1. M0: Design Consolidation
2. M1: Plugin Contract First
3. M2: Install Lifecycle MVP
4. M2.5: Work Record Model
5. M3: Release Bundle Hardening
6. M4: Baseline Engine
7. M4.2: Test Matrix Foundation (일부 레이어 실파일 보강 필요)
8. M4.5: DOT Critical PoC Gate
9. M5: DOT Selective Migration
10. M6: Update Governance

## 2) 현재 실행 마일스톤: Week-1 (P0 + P1)

기간: 2026-03-04 ~ 2026-03-10

전략:

1. Policy-Driven Orchestrator 방향으로 정렬
2. 기능별 작은 PR 3~5개
3. 표준 게이트(`local + scripts/test.sh all + bundle smoke`) 적용

Work streams:

1. `w-p0-core-stability` (`#24~#27`)
2. `w-p1-policy-status` (`#30~#32`, `#34`, `#35`)
3. `w-release-validation` (`#28`, `#29`, `#33`)

### M7. Core Stability Hardening (P0)

상태: In Progress  
완료 목표: 2026-03-06

1. `update rollback <id>` 실동작 보장
2. DOT compile 경로/성공 판정 정합성 확보
3. KPI show 무데이터 안정성 보장
4. 실행 로그 start/end/duration/result 완전 기록

### M8. Policy & Status Standardization (P1)

상태: In Progress  
완료 목표: 2026-03-09

1. `cch status --json` 도입 (PLAN 연계 + DOT 실험 상태 포함)
2. health `reason_code` 표준화
3. `manifests/health-rules.json` 도입 (Architecture 8절 4개 대표 규칙 반영)
4. Resolver 결정적 실행 보장(정렬/원자 기록)
5. update check 결과 reason_code 체계 통합
6. `/cch-mode plan` 시 PLAN 문서 자동 생성 (`#53`)

### M9. Release Validation Sync

상태: In Progress  
완료 목표: 2026-03-10

1. Resilience/DOT Gate 테스트 실파일 구현
2. `scripts/test.sh all`에서 SKIP 0
3. stable bundle smoke + lock 무결성 검증
4. PRD/Architecture/Roadmap/TODO 문서 동기화

### M9.5. Hook/Team/Doc 자동화 (Phase 3+)

상태: Done (2026-03-03)

1. UserPromptSubmit 모드 자동 감지 hook (`#50`)
2. `/cch-team` 순차 파이프라인 스킬 (`#51`)
3. 문서 자동 영구화 + 경로 명시 시스템 (`#52`)

## 3) Week-1 완료 게이트 (전부 필수)

1. 치명 버그(P0) 0건
2. `cch update rollback <id>` 실동작
3. 6-layer 테스트 전부 통과
4. stable 번들 무결성 검증 통과
5. `cch status`에 mode/health/reason_code/work summary 표시
6. DOT on/off가 resolve 결과에 실제 반영
7. PRD/Architecture/Roadmap/TODO 동기화

## 4) Week-1 이후 로드맵 (예정)

### M10. Framework v2 Core Completion (Phase 4, `#36~#43`,`#54`)

상태: Planned

정책/스키마 정규화:

1. Mode Profile JSON 스키마 정규화 (`#36`)
2. Capability Registry 스키마 도입 (`#37`)
3. Resolved Output 스키마 정규화 + golden 비교 체계 (`#54`)

명령/오류 계약 표준화:

4. 명령 계약 v2: 종료코드(0/1/2), 출력 블록(summary/machine), 증적 필수화 (`#38`)
5. 오류 분류 체계: E_VALIDATION/E_SOURCE_MISSING/E_POLICY_BLOCKED/E_INTEGRITY/E_RUNTIME (`#39`)

런타임 인프라:

6. state 디렉터리 네임스페이스 정규화 (`#40`)
7. 동시성 제어 lock 파일 도입 (`#41`)

CI/테스트 게이트:

8. CI 게이트 정규화: PR/merge/release 단계별 범위 (`#42`)
9. Phase 4 통합 검증 (`#43`)

### M11. Supply Chain & Operations (Phase 5, `#44~#49`,`#55`)

상태: Planned

공급망 거버넌스:

1. signed release manifest/signature 체인 도입 (`#44`)
2. 릴리즈 채널/승격 정책 자동화: dev/candidate/stable (`#45`)

운영 관측성:

3. KPI metrics 스키마 확장: `experiment_id`/`window` 필드 추가 (`#55`)
4. 운영 KPI 대시보드 정규화 (`#46`)
5. DOT 게이트 자동 판정 리포트 (`#47`)
6. 모드별 SLO 정의 및 경보 (`#48`)

최종 게이트:

7. Framework Readiness 12개 기준 최종 판정 (`#49`)

## 5) 추적 문서

1. `.beads/` (Beads — 태스크 SSOT, `bd ready`로 조회)
2. `docs/plans/2026-03-03-week1-execution.md`
3. `docs/plans/2026-03-03-w-p0-core-stability.md`
4. `docs/plans/2026-03-03-w-p1-policy-status.md`
5. `docs/plans/2026-03-03-w-release-validation.md`
6. `docs/plans/2026-03-03-cch-framework-v2-design.md`
