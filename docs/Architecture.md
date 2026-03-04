# Architecture: Claude Code Harness (Framework Runtime)

- 문서 버전: v2.0
- 작성일: 2026-03-03
- 상태: Active (Week-1 Execution)

## 1. 아키텍처 목표

CCH를 "다중 통합 플러그인"에서 "운영 가능한 통합 프레임워크"로 전환한다.

핵심 원칙:

1. 사용자 진입점은 slash command, 실행 엔진은 `cch`
2. Baseline와 DOT 실험선을 분리 운영
3. 결정 로직은 코드 하드코딩보다 정책(manifest/rules) 우선
4. 모든 상태 판정은 `reason_code`를 포함해 설명 가능해야 함
5. 같은 입력이면 같은 resolve 결과가 나오도록 결정적 실행 보장

## 2. 아키텍처 결정

대안 A/B/C 중 **B안(Policy-Driven Orchestrator)**을 채택한다.

1. 모드/소스/헬스 규칙을 데이터로 외부화
2. 테스트 가능성을 높이고 회귀를 줄임
3. 확장 시 코드 변경 범위를 제한

## 3. 레이어와 컴포넌트

### 3.1 레이어

1. Interface Layer
   - `/cch-*`, `/omc-setup`
   - `bin/cch`
2. Orchestration Layer
   - Command Router
   - Mode Engine
   - Resolver Engine
   - Health Evaluator
   - DOT Gate Controller
3. Policy & Registry Layer
   - `profiles/*.json`
   - `manifests/capabilities.json`
   - `manifests/health-rules.json` (신규)
4. State & Evidence Layer
   - `.claude/cch/state/*`
   - `.beads/` (프로젝트 수준 태스크 SSOT)
   - `.claude/cch/runs/*`
   - `.claude/cch/metrics/*`
   - `.resolved/*`
5. Supply Chain Layer
   - release bundle
   - `release.lock`
   - rollback history

### 3.2 컴포넌트 책임

| 컴포넌트 | 책임 |
| --- | --- |
| Command Router | 명령 파싱/디스패치/종료코드 계약 |
| Mode Engine | mode 전환/검증 및 상태 반영 |
| Resolver Engine | mode+policy 기반 source 조합 결정 |
| Health Evaluator | `Healthy/Degraded/Blocked` + `reason_code` 산출 |
| DOT Gate | DOT on/off, code mode 한정 실험 게이트 |
| Update Manager | pin 검증, apply/rollback/history 관리 |
| Evidence Writer | 실행 증적(JSONL/YAML) 기록 |

## 4. 명령 계약 v2

모든 명령은 공통 계약을 준수한다.

1. 종료코드:
   - `0`: success
   - `1`: validation/runtime failure
   - `2`: blocked by policy
2. 출력:
   - human readable summary
   - machine readable payload(JSON or key-value)
3. 증적 필드:
   - `cmd`, `args`, `mode`, `result`, `reason_code`, `duration_ms`

명령-실행 매핑:

| Slash Command | 내부 동작 |
| --- | --- |
| `/cch-setup` | `cch setup` |
| `/cch-mode <mode>` | `cch mode <mode>` |
| `/cch-status` | `cch doctor --summary` 또는 `cch doctor --json` |
| `/cch-update` | `cch update [check|apply|rollback|history]` |
| `/cch-dot on|off|status` | `cch dot on|off|status` |
| `/omc-setup` | `cch setup` alias |

## 5. 설치 및 실행 라이프사이클

1. `/plugin install claude-code-harness`
2. `/cch-setup`
3. `/cch-mode <plan|code|tool|swarm>`
4. 필요 시 `/cch-dot on` (code 모드 전용)
5. `/cch-status`로 상태 점검
6. `/cch-update`로 무결성/복구 체인 점검

## 6. Resolver/Health 모델

### 6.1 Resolver

1. profile 로드
2. source 후보 생성
3. source id 정렬(결정적 실행)
4. availability 검사
5. fallback_order 적용
6. `.resolved/state.json` 원자적 기록

### 6.2 Health 판정

1. `Blocked`: 필수 source 결손 또는 정책 위반
2. `Degraded`: optional source 결손/대체 경로 적용
3. `Healthy`: 필수 경로 완전

필수 출력:

1. `status`
2. `reason_code`
3. `reasons[]`

## 7. DOT 운영 모델

1. 기본 OFF
2. `code` 모드에서만 ON/OFF 가능
3. ON 시 overlay source를 resolve에 반영
4. 컴파일 성공 기준:
   - 소스 존재
   - 엔트리 존재
   - 캐시 동기화 성공
5. KPI/킬스위치 이벤트는 `.claude/cch/metrics/dot-poc.jsonl`에 기록

## 8. 상태/증적 저장소

### 8.1 네임스페이스 규약 (cch-ujy #40)

`.claude/cch/` 디렉터리는 다음 네임스페이스를 따른다:

```text
.claude/cch/
├── init/               # cch-init 상태 (scan-result, progress, mode)
├── state/              # 런타임 상태 (resolve 결과, 실행 로그)
│   ├── .resolved/      # resolve 캐시 (state.json)
│   └── logs/           # 실행 로그 (JSONL)
├── integrity.json      # 소스 무결성 체크섬
└── execution-plan.json # 현재 실행 계획
```

이 디렉터리 구조는 `bin/cch`의 `_ensure_state_dirs()` 함수가 `cmd_setup` 호출 시 자동으로 생성한다.

### 8.2 런타임 상태 파일

```text
.claude/cch/
  mode              # 현재 모드 (plan|code|tool|swarm)
  health            # 헬스 상태 (Healthy|Degraded|Blocked)
  health_reason     # reason_code 목록 (쉼표 구분)
  dot_enabled       # DOT 실험 활성화 여부 (true|false)
  branches/         # 브랜치별 상태 파일 (YAML)
  rollbacks/        # 롤백 포인트
  metrics/          # KPI 메트릭 (dot-poc.jsonl)
  locks/            # 동시성 제어 lock 파일
```

4-Lite 운영 원칙:

1. 태스크의 단일 진실원은 `.beads/` (Beads), `docs/TODO.md`는 읽기 전용 아카이브
2. `docs/plans/*`는 주차 실행/설계/검증 근거 문서

## 9. 업데이트/공급망 모델

1. release bundle은 submodule 비의존
2. `release.lock` 기반 SHA256 검증
3. `update apply` 전에 rollback point 생성
4. `update rollback <id>` 실동작 보장
5. mismatch 유형(`changed`, `missing`, `unexpected`)을 reason_code로 표준화

## 10. 테스트 아키텍처와 품질 게이트

6-layer:

1. Contract
2. Agent
3. Skill
4. Workflow
5. Resilience
6. DOT Gate

Week-1 표준 게이트:

1. 로컬 검증
2. `bash scripts/test.sh all` 통과
3. stable bundle smoke 검증 통과

## 11. Week-1 실행 동기화 (2026-03-10 마감)

확정 범위:

1. P0 + P1 전체
2. 작업 방식: 기능별 작은 PR 3~5개
3. Work streams:
   - `w-p0-core-stability`
   - `w-p1-policy-status`
   - `w-release-validation`

필수 완료 조건:

1. 치명 버그(P0) 0건
2. rollback 실동작
3. 6-layer 테스트 통과
4. stable 번들 무결성 통과
5. status에 mode/health/reason_code/work summary 표시
6. DOT on/off의 resolve 반영 검증
7. PRD/Architecture/Roadmap/TODO 동기화

## 12. 참조 문서

1. `docs/plans/2026-03-03-cch-framework-v2-design.md`
2. `docs/plans/2026-03-03-week1-execution.md`
3. `docs/plans/2026-03-03-w-p0-core-stability.md`
4. `docs/plans/2026-03-03-w-p1-policy-status.md`
5. `docs/plans/2026-03-03-w-release-validation.md`
