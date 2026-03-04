# PRD: Claude Code Harness (Framework Upgrade, Week-1)

- 문서 버전: v2.0
- 작성일: 2026-03-03
- 상태: Active (Execution)
- 목표 마감: 2026-03-10 (화)

## 1. 제품 정의

CCH는 Claude Code에서 동작하는 통합 오케스트레이션 프레임워크다.

핵심:

1. 사용자 UX는 `/plugin install` + slash command
2. 내부 실행 엔진은 `cch`
3. 운영선은 Baseline + DOT Experiment dual-track
4. 결정 로직은 정책(manifest/rules) 중심으로 관리

## 2. 해결할 문제

1. 다중 capability source 통합 시 계약 불일치
2. 모드 전환/상태 판정의 재현성 부족
3. 장애 시 원인 가시성과 복구 경로 불명확
4. 업데이트/롤백 신뢰 체인 결함
5. 문서-코드-테스트 드리프트

## 3. 제품 목표 (Week-1)

1. P0 안정성 결함 제거(rollback, DOT, KPI, run log)
2. 상태 판정 표준화(`reason_code`)
3. `/cch-status` 기계친화 출력(`--json`) 제공
4. health rule 외부화(`manifests/health-rules.json`)
5. 6-layer 테스트 실구현 및 표준 게이트 통과

## 4. 기능 요구사항

### F1. 명령 표면

필수 slash commands:

1. `/cch-setup`
2. `/cch-mode <plan|code|tool|swarm>`
3. `/cch-status`
4. `/cch-update`
5. `/cch-dot on|off|status`
6. `/omc-setup` (alias)

### F2. 명령 계약

모든 명령은 다음을 만족해야 한다.

1. 종료코드:
   - `0`: success
   - `1`: validation/runtime failure
   - `2`: blocked by policy
2. 증적 필드:
   - `cmd`, `args`, `mode`, `result`, `reason_code`, `duration_ms`
3. 오류 시 최소:
   - `error_class`, `error_message`

### F3. 상태 조회 계약

`/cch-status`는 다음을 제공해야 한다.

1. 텍스트 요약(`--summary`)
2. JSON 출력(`--json`)
3. 최소 필드:
   - `mode`
   - `health.status`
   - `health.reason_code`
   - `resolved.sources`
   - `dot.status`
   - `work.summary`

### F4. Resolver/Health 계약

1. Resolver는 결정적 실행을 보장해야 함
2. DOT on/off는 resolve 결과에 실제 반영되어야 함
3. health 판정은 `Healthy/Degraded/Blocked` + `reason_code`를 반환해야 함
4. health rule은 `manifests/health-rules.json`에서 로드되어야 함

### F5. 업데이트/복구 계약

1. `update check`는 `release.lock` 기반 무결성 검증 수행
2. `update apply`는 rollback point를 선생성
3. `update rollback <id>`는 인자 기반 복원을 실제 수행
4. mismatch 유형(`changed`, `missing`, `unexpected`)을 표준 코드로 분류

### F6. 작업 기록 및 증적

1. 태스크 상태: `.beads/` (Beads SSOT, `bd` CLI로 관리)
2. 실행 로그: `.claude/cch/runs/<date>/<work-id>.jsonl`
3. KPI 로그: `.claude/cch/metrics/dot-poc.jsonl`
4. 로그는 start/end를 모두 기록해야 함

### F7. 테스트 체계

6-layer 테스트:

1. Contract
2. Agent
3. Skill
4. Workflow
5. Resilience
6. DOT Gate

요구:

1. `scripts/test.sh all` 기준 SKIP 0건
2. 전 레이어 통과

### F8. 배포/패키징

1. submodule 비의존 release bundle
2. stable 번들 smoke 검증 통과
3. clean 환경에서 `setup -> mode -> status -> update check` 성공

## 5. 운영 요구사항 (4-Lite)

1. 태스크의 단일 진실원은 `.beads/` (Beads), `docs/TODO.md`는 읽기 전용 아카이브
2. 주차 실행표는 일정/게이트/PR 분할만 관리
3. 작업 추적은 `bd` CLI 기반 Beads로 운영 (`bd ready`, `bd list --label`)

## 6. 범위

### In Scope (이번 주, 2026-03-10까지)

1. P0 + P1 전체 실행
2. 기능별 작은 PR 3~5개 분할
3. 문서 동기화(PRD/Architecture/Roadmap/TODO)

### Out of Scope (이번 주 제외)

1. 전모드 DOT 즉시 활성화
2. 채널/서명 기반 릴리즈 자동화 전체
3. 타 플랫폼 정식 지원

## 7. 완료 기준 (전부 필수)

1. 치명 버그(P0) 0건
2. `cch update rollback <id>` 실동작
3. 6-layer 테스트 전부 통과
4. stable 번들 무결성 검증 통과
5. `cch status`에 mode/health/reason_code/work summary 표시
6. DOT on/off가 resolve 결과에 실제 반영
7. PRD/Architecture/Roadmap/TODO 문서 동기화

## 8. 참조 실행 항목

1. `docs/TODO.md`의 `#24 ~ #35`
2. `docs/plans/2026-03-03-week1-execution.md`
3. `docs/plans/2026-03-03-cch-framework-v2-design.md`
