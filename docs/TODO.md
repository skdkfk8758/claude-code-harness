# TODO: Claude Code Harness (Plugin MVP)

- 작성일: 2026-03-03
- 갱신일: 2026-03-03
- 기준 문서: PRD v1.7, Architecture v1.7, Roadmap v1.7, Framework v2 설계서
- 상태: **Phase 1 + Phase 2 + Phase 3 + Phase 3+ + Phase 3B 완료, Phase 3S + Phase PT + Phase PTW + Phase 4 + Phase 5 예정** (2026-03-03)
- 전체 항목: #1~#81 (완료 60, 미완료 21)

## Critical Path

```
Phase 1~2: #1 → #2 → #3 → #5 → #6 → #10 → #13 → #14 → #15 → #17 → #23
Phase 3:   #24 → #25 → #30 → #31 → #32 → #53 → #33
Phase 3+:  #50 → #51 → #52
Phase 3B:  #77 → #78 → #79 → #80 → #81
Phase 3S:  #56 → #57 → #58 → #59 → #60
Phase PT:  #61 → #62 → #63 → #64 → #65 → #66 → #67 → #68 → #69
Phase PTW: #70 → #71 → #72 → #73 → #74 → #75 → #76
Phase 4:   #36 → #37 → #54 → #38 → #39 → #41 → #43
Phase 5:   #55 → #46 → #47 → #44 → #45 → #49
```

---

## 기반: 프로젝트 초기화

- [x] **#1** 프로젝트 초기 구조 셋업 (디렉터리 스캐폴딩) _(2026-03-03 완료)_
  - Claude Code 네이티브 플러그인 포맷에 맞춰 구조 생성
  - `.claude-plugin/`, `skills/`, `hooks/`, `bin/cch`, `profiles/`, `manifests/`, `overlays/`, `dot/`
  - 상태 저장 경로 `.claude/cch/` 구조 정의
  - 의존: 없음

---

## M1. Plugin Contract First

- [x] **#2** Plugin manifest/entrypoint 정의 _(2026-03-03 완료)_
  - `.claude-plugin/plugin.json` 작성 (Claude Code 네이티브 매니페스트)
  - skills/hooks 경로 등록
  - 의존: #1

- [x] **#3** Slash command 5종 계약 구현 - Plugin Command Handler _(2026-03-03 완료)_
  - `skills/cch-setup/SKILL.md` → `bin/cch setup`
  - `skills/cch-mode/SKILL.md` → `bin/cch mode <mode>`
  - `skills/cch-status/SKILL.md` → `bin/cch doctor --summary`
  - `skills/cch-update/SKILL.md` → `bin/cch update`
  - `skills/cch-dot/SKILL.md` → `bin/cch dot <on|off>`
  - YAML frontmatter로 invocation 제어, allowed-tools 설정
  - 의존: #1, #2

- [x] **#4** `/omc-setup` 호환 alias 구현 _(2026-03-03 완료)_
  - `skills/omc-setup/SKILL.md` → `bin/cch setup` 위임
  - 의존: #3

---

## M2. Install Lifecycle MVP

- [x] **#5** `/cch-setup` 초기화 흐름 구현 _(2026-03-03 완료)_
  - `bin/cch setup`: 디렉터리 검사, profile 검증, `.claude/cch/` 생성
  - health/mode/dot_enabled 초기 상태 기록
  - 의존: #3

- [x] **#6** `/cch-mode` 모드 전환 엔진 구현 _(2026-03-03 완료)_
  - `bin/cch mode`: 4모드 유효성 검증, profile 존재 확인
  - 모드 전환 시 DOT 자동 비활성화 (code 외 모드)
  - `.claude/cch/mode`에 현재 모드 저장
  - 의존: #5

- [x] **#7** `/cch-setup → /cch-mode → /cch-status` E2E 검증 _(2026-03-03 완료)_
  - setup → mode code → doctor 정상 흐름 확인
  - DOT 토글 + 모드 가드 (code 외 거부) 검증
  - 의존: #5, #6

---

## M3. Release Bundle Hardening

- [x] **#8** Submodule 비의존 릴리즈 번들 생성 파이프라인 _(2026-03-03 완료)_
  - `scripts/build-release.sh`: 번들 빌드 + SHA256 체크섬 lock 생성
  - git recursive clone 없이 동작 확인
  - 의존: #7

- [x] **#9** 크로스플랫폼 동작 검증 (macOS/WSL) _(2026-03-03 완료)_
  - macOS clean install 검증 통과
  - copy/mirror 방식 정상 동작 확인
  - WSL 검증은 CI 단계에서 수행 예정
  - 의존: #8

---

## M4. Baseline Engine

- [x] **#10** Capability Resolver 구현 (`.resolved/` 생성) _(2026-03-03 완료)_
  - `cmd_resolve`: 모드별 소스 조합, `.resolved/state.json` 생성
  - 5개 외부 소스 가용성 체크 + fallback impact 판정
  - 의존: #6

- [x] **#11** Health Reporter 구현 (Healthy/Degraded/Blocked 판정) _(2026-03-03 완료)_
  - `cmd_doctor`: 소스별 상태, fallback 원인, DOT 상태 출력
  - Healthy/Degraded/Blocked 자동 판정
  - 의존: #10

- [x] **#12** Fallback 가시화 및 Graceful Degradation 로직 _(2026-03-03 완료)_
  - 소스 미가용 시 `[MISS] source -> impact` 형식 출력
  - 부분 장애 시 가능한 기능 계속 동작 (Degraded)
  - 의존: #10, #11

---

## M4.5. DOT Critical PoC Gate

- [x] **#13** DOT 실험선 기본 구현 (code 모드 한정) _(2026-03-03 완료)_
  - `dot_compile`: DOT 소스 탐색 + 로컬 cache fallback
  - `dot_enable/dot_disable`: 토글 + 자동 resolve 트리거
  - `dot status`: 컴파일 상태, KPI 요약 출력
  - 의존: #6, #10

- [x] **#14** DOT PoC KPI 측정 인프라 구축 _(2026-03-03 완료)_
  - `cmd_kpi`: record/show/reset 서브커맨드
  - 4개 메트릭: token_usage, mode_switch_latency, prompt_conflict, quality_regression
  - 킬스위치: quality_regression 2건+ 시 자동 경고
  - 의존: #13

---

## M5. DOT Selective Migration

- [x] **#15** Superpowers 3스킬 DOT 이관 _(2026-03-03 완료)_
  - `dot/combos/`: brainstorming.md, tdd.md, systematic-debugging.md
  - `dot/combo.lock`: 이관 출처 및 버전 고정
  - DOT compile 시 자동 cache
  - 의존: #13, #14

---

## M6. Update Governance

- [x] **#16** Update Manager 구현 (pin 검증, 롤백 포인트) _(2026-03-03 완료)_
  - `update check`: release.lock 기반 SHA256 pin 검증
  - `update apply`: 롤백 포인트 자동 생성
  - `update rollback <id>`: 상태 복원
  - `update history`: 롤백 이력 조회
  - 의존: #7

---

## Release Gate

- [x] **#17** 출시 전 필수 체크 전체 검증 _(2026-03-03 완료)_
  - [x] slash command 5종 동작 검증
  - [x] `/omc-setup` alias 호환 검증
  - [x] submodule 없이 clean install 성공
  - [x] macOS에서 `cch-setup → cch-mode` 성공 (WSL은 CI에서 예정)
  - [x] `cch-status`에서 fallback 원인 가시화
  - [x] DOT PoC 결과가 정량 KPI로 기록
  - 의존: #4, #7, #9, #12, #14, #15, #16

---

## Phase 2: Architecture 보완 (6.1, 11, 12절)

> Architecture.md에 추가된 작업 기록 저장소, 테스트 아키텍처, 상태 전이 모델 요구사항 반영

### 6.1 작업 기록 저장소

- [x] **#18** Work Item 저장소 구현 (`work-items/<work-id>/todo.yaml`) _(2026-03-03 완료)_
  - `bin/lib/work.sh` 모듈: create/list/show/transition 커맨드
  - `.claude/cch/work-items/<work-id>/todo.yaml` 구조
  - 의존: #5

- [x] **#19** 실행 로그 기록기 구현 (`runs/<date>/<work-id>.jsonl`) _(2026-03-03 완료)_
  - `bin/lib/log.sh` 모듈: show/tail 커맨드
  - main에서 모든 커맨드 실행 시 JSONL 자동 기록
  - 의존: #18

- [x] **#20** DOT PoC 메트릭 JSONL 통합 (`metrics/dot-poc.jsonl`) _(2026-03-03 완료)_
  - `kpi/` 개별 로그 → `metrics/dot-poc.jsonl` 단일 JSONL로 마이그레이션
  - `{"ts","metric","value","mode"}` 포맷
  - 킬스위치 자동 감지 (quality_regression 2건+)
  - 의존: #14

### 11. 테스트 아키텍처

- [x] **#21** 테스트 프레임워크 스캐폴딩 및 6레이어 구현 _(2026-03-03 완료)_
  - `scripts/test.sh` 러너 + assert 유틸리티
  - 6개 레이어 **96 tests, 0 failures**:
    1. Contract Layer (16 tests) - slash command 계약 검증
    2. Agent Layer (12 tests) - capability/resolve 포맷 검증
    3. Skill Layer (36 tests) - SKILL.md frontmatter 6스킬 검증
    4. Workflow Layer (11 tests) - e2e + work item 라이프사이클
    5. Resilience Layer (7 tests) - fallback/health/MISS 검증
    6. DOT Gate Layer (14 tests) - KPI JSONL + 킬스위치 검증
  - 의존: #7, #12, #14

### 12. 상태 전이 모델

- [x] **#22** 상태 전이 엔진 구현 (`todo → doing → blocked → done`) _(2026-03-03 완료)_
  - `cch work transition <work-id> <target-state>` 커맨드
  - 4개 전이 규칙 강제, 잘못된 전이 거부 (예: `todo → done`)
  - `todo.yaml`에 전이 이력 자동 기록
  - 의존: #18

### Phase 2 Release Gate

- [x] **#23** Phase 2 통합 검증 _(2026-03-03 완료)_
  - [x] 작업 기록 저장소 CRUD 동작 검증
  - [x] 실행 로그 JSONL 기록/조회 검증
  - [x] DOT 메트릭 JSONL 통합 마이그레이션 검증
  - [x] 6레이어 테스트 전체 통과 (96/96)
  - [x] 상태 전이 규칙 강제 검증 (잘못된 전이 거부)
  - 의존: #18, #19, #20, #21, #22

---

## Phase 2 의존성 그래프

```
기존 완료 태스크
 ├─ #5  (cch-setup) ──────────┐
 ├─ #7  (E2E 검증)   ────────┤
 ├─ #12 (Fallback)   ────────┤
 └─ #14 (DOT KPI)  ─────┐    │
                         │    │
                   #20 메트릭 │
                     JSONL    │
                         │    │
              #18 Work Item ──┤
               ├─ #19 실행 로그│
               └─ #22 상태 전이│
                              │
                    #21 테스트 6레이어
                              │
                    #23 Phase 2 Gate
```

---

## Phase 1 의존성 그래프

```
#1 프로젝트 초기 구조
 └─ #2 Plugin manifest
     └─ #3 Slash command 5종
         ├─ #4 /omc-setup alias ──────────────────────────┐
         └─ #5 /cch-setup 초기화                          │
             ├─ #6 /cch-mode 모드 전환                    │
             │   ├─ #10 Capability Resolver               │
             │   │   ├─ #11 Health Reporter               │
             │   │   │   └─ #12 Fallback 로직 ───────────┐│
             │   │   └─ #13 DOT 실험선                    ││
             │   │       ├─ #14 DOT KPI 측정 ────────────┐││
             │   │       └───────────────────┐           │││
             │   │                           │           │││
             │   │                     #15 Superpowers ──┤││
             │   │                       이관            │││
             │   └──────────────────────────────────┐    │││
             └─ #7 E2E 검증                         │    │││
                 ├─ #8 릴리즈 번들                   │    │││
                 │   └─ #9 크로스플랫폼 검증 ────────┤    │││
                 └─ #16 Update Manager ──────────────┤    │││
                                                     │    │││
                              #17 Release Gate ◄─────┴────┘││
                                               ◄──────────┘│
                                               ◄───────────┘
```

---

## Phase 3: Week-1 Execution (4-Lite, Due: 2026-03-10)

> 목적: TODO를 단일 상태 소스로 유지하면서, 주차 실행표 + work-id 설계 문서로 실행력을 높인다.

### 운영 원칙 (4-Lite)

1. 상태의 단일 진실원은 `docs/TODO.md`로 고정
2. 주차 실행표는 일정/게이트/PR 분할만 관리 (상태 중복 금지)
3. work-id 문서는 고위험 스트림 3개만 운영
4. 모든 PR은 work-id 중 1개에 반드시 매핑

### 확정된 완료 기준 (인터뷰 반영)

- 마감: 2026-03-10 (화)
- 필수 조건(전부 충족):
  1. 치명 버그(P0) 0건
  2. `cch update rollback <id>` 실동작
  3. 6-layer 테스트 전부 통과
  4. stable 번들 무결성 검증 통과
  5. `cch status`에 mode/health/reason_code/work summary 표시
  6. DOT on/off가 resolve 결과에 실제 반영
  7. PRD/Architecture/Roadmap/TODO 문서 동기화

### 실행 전략/게이트/범위 (인터뷰 반영)

1. 전략: B안 단독 (Policy-Driven Orchestrator)
2. 우선순위: 균형형 (`치명 결함 4개 -> 6-layer 실테스트 -> status 확장 -> 문서 동기화+릴리즈 검증`)
3. 게이트: 표준 게이트 (`local + scripts/test.sh all + bundle smoke`)
4. 범위: `P0 + P1 전체`
5. 작업 방식: 기능별 작은 PR 3~5개

### Work Streams

- `w-p0-core-stability`: rollback/DOT/KPI/log 안정화
- `w-p1-policy-status`: status --json, reason_code, health-rules
- `w-release-validation`: 6-layer 검증, 번들 smoke, 문서 싱크

참조 문서:
- `docs/plans/2026-03-03-week1-execution.md`
- `docs/plans/2026-03-03-w-p0-core-stability.md`
- `docs/plans/2026-03-03-w-p1-policy-status.md`
- `docs/plans/2026-03-03-w-release-validation.md`

### Week-1 TODO (Single Source of Truth)

- [x] **#24** `w-p0-core-stability`: rollback 인자 전달/복원 검증 버그 수정 _(2026-03-03 완료)_
  - `update rollback <id>` 인자 전달 누락 제거
  - 성공/실패 종료코드 계약 정리
  - 복원 후 검증 3단계: 상태 파일 존재 확인 → mode 유효성 확인 → resolve 재실행 가능성 확인
  - 의존: #16

- [x] **#25** `w-p0-core-stability`: DOT compile 경로/성공 판정 정합성 수정 _(2026-03-03 완료)_
  - `combo`/`combos` 경로 정렬
  - 컴파일 성공 조건을 "실제 엔트리 존재 + 캐시 동기화" 기준으로 강화
  - DOT overlay 충돌 시 `priority` 필드 기반 우선순위 해결 로직 추가
  - 의존: #13, #15

- [x] **#26** `w-p0-core-stability`: KPI show 무데이터 안정성 보강 _(2026-03-03 완료)_
  - 데이터가 없는 metric에서도 커맨드 비정상 종료 금지
  - `pipefail` 하에서 안전 집계 구현
  - 의존: #14, #20

- [x] **#27** `w-p0-core-stability`: 실행 로그 start/end/duration/result 완전 기록 _(2026-03-03 완료)_
  - `.claude/cch/runs/*` 스키마 확장
  - 실패 시 `error_class`, `error_message` 포함
  - 의존: #19

- [x] **#28** `w-release-validation`: Resilience Layer 테스트 파일 실구현 _(2026-03-03 완료)_
  - `tests/test_resilience.sh` 추가
  - source 미가용 시 health/fallback 판정 검증
  - 의존: #12, #21

- [x] **#29** `w-release-validation`: DOT Gate Layer 테스트 파일 실구현 _(2026-03-03 완료)_
  - `tests/test_dot_gate.sh` 추가
  - KPI/킬스위치 조건 검증
  - 의존: #14, #20, #21

- [x] **#30** `w-p1-policy-status`: `cch status --json` 추가 _(2026-03-03 완료)_
  - mode/health/reason_code/resolved/work summary 출력
  - PLAN 연계 상태 출력 (`docs/plans/` 활성 작업 문서 요약)
  - DOT 실험 상태 출력 (활성 여부, 컴파일 상태, KPI 요약)
  - human readable 출력과 machine 출력 분리
  - 의존: #11, #18, #19

- [x] **#31** `w-p1-policy-status`: health reason_code 표준화 _(2026-03-03 완료)_
  - 상태 판정 결과에 reason_code 필수화
  - `cch-status`와 run log에 공통 적용
  - 의존: #11, #30

- [x] **#32** `w-p1-policy-status`: `manifests/health-rules.json` 도입 _(2026-03-03 완료)_
  - health rule 외부화 (최소 4규칙, Architecture 8절 대표 fallback 전체 반영)
    1. `gptaku_plugins` 미가용 → `tool` Degraded
    2. `ruflo` 미가용 → `swarm` Blocked
    3. `superpowers` 미가용 → 품질 게이트 약화 (Degraded)
    4. DOT 미가용 → 실험선 비활성/캐시 fallback
  - resolver/doctor가 rule을 참조하도록 반영
  - rule parse 실패 시 안전 fallback 정책 정의
  - 의존: #31

- [x] **#33** `w-release-validation`: 문서 동기화 + stable bundle smoke 검증 _(2026-03-03 완료)_
  - `docs/PRD.md`, `docs/Architecture.md`, `docs/Roadmap.md` 상태 동기화
  - `scripts/build-release.sh` 기반 smoke 검증 결과 기록
  - 의존: #24, #25, #26, #27, #28, #29, #30, #31, #32

- [x] **#34** `w-p1-policy-status`: update check 결과를 reason_code로 통일 _(2026-03-03 완료)_
  - release lock 검증 결과를 health reason_code 체계에 통합
  - mismatch 유형(changed/missing/unexpected)별 코드 할당
  - 의존: #16, #31

- [x] **#35** `w-p0-core-stability`: Resolver 결정적 실행 보장 _(2026-03-03 완료)_
  - source id 사전순 정렬 강제
  - 동일 입력 시 동일 출력 보장 (golden output 비교)
  - `.resolved/state.json` 원자적 기록
  - 의존: #10

- [x] **#53** `w-p1-policy-status`: `/cch-mode plan` 시 PLAN 문서 자동 생성 _(2026-03-03 완료)_
  - `/cch-mode plan` 실행 시 `docs/plans/YYYY-MM-DD-<work-id>.md` 템플릿 자동 생성
  - 기존 문서 존재 시 중복 생성 방지
  - PRD F8.1, Architecture 6.1 요구사항 충족
  - 의존: #6, #18

### Week-1 의존성 그래프 (갱신)

```
기존 완료 태스크
 ├─ #16 (Update Manager) ─────┐
 ├─ #13 (DOT 실험선) ─────────┤
 ├─ #15 (Superpowers 이관) ───┤
 ├─ #14 (DOT KPI) ────────────┤
 ├─ #20 (메트릭 JSONL) ───────┤
 ├─ #19 (실행 로그) ──────────┤
 ├─ #12 (Fallback) ───────────┤
 ├─ #11 (Health Reporter) ────┤
 ├─ #18 (Work Item) ──────────┤
 ├─ #21 (테스트 6레이어) ─────┤
 └─ #10 (Resolver) ───────────┤
                               │
 #24 rollback 수정 ────────────┤
 #25 DOT compile 수정 ─────────┤
 #26 KPI show 안정화 ──────────┤
 #27 실행 로그 완전 기록 ──────┤
                               │
 #28 Resilience 테스트 ────────┤
 #29 DOT Gate 테스트 ──────────┤
                               │
 #30 status --json ────────────┤
  └─ #31 reason_code 표준화 ───┤
      ├─ #32 health-rules.json │
      └─ #34 update reason_code│
                               │
 #35 Resolver 결정적 실행 ─────┤
                               │
 #33 문서 동기화 + bundle smoke ◄── 전체 의존
```

---

## Phase 3+: Hook/Team/Doc 자동화

> 목적: 모드 자동 감지, 순차 팀 파이프라인, 문서 자동 영구화를 통한 개발 워크플로우 고도화

### Hook/Team/Doc 자동화 (Phase 3+)

- [x] **#50** `w-hook-mode-detect`: UserPromptSubmit 모드 자동 감지 hook 구현 _(2026-03-03 완료)_
  - `scripts/mode-detector.sh`: 한국어/영어 키워드 기반 의도 분석
  - `hooks/hooks.json`: UserPromptSubmit hook 등록
  - system-reminder로 모드 추천 주입, Claude가 최종 판단
  - 의존: #3, #6

- [x] **#51** `w-team-pipeline`: /cch-team 순차 파이프라인 스킬 구현 _(2026-03-03 완료)_
  - `skills/cch-team/SKILL.md`: Developer → Test Engineer → Verifier
  - Step 0에서 `docs/plans/<work-id>.md` 자동 생성 + 경로 명시
  - `bin/cch work create` 연동으로 작업 항목 자동 등록
  - 의존: #18, #50

- [x] **#52** `w-doc-auto-persist`: 문서 자동 영구화 + 경로 명시 시스템 _(2026-03-03 완료)_
  - `scripts/plan-doc-reminder.sh`: ExitPlanMode 시 문서 저장 안내
  - `/cch-team` Step 4에서 결과 문서 업데이트 + 경로 보고
  - 기존 네이밍 규칙 준수: `docs/plans/YYYY-MM-DD-<work-id>.md`
  - 의존: #50, #51

---

## Phase 3B: Interview-to-Execution Bridge (인터뷰→실행 자동 브릿지)

> 목적: 인터뷰/계획 단계 완료 후 에이전트가 실행 단계로 자동 전환되지 않는 구조적 문제 해결
> 설계 문서: `docs/plans/2026-03-03-interview-bridge-design.md`
> 구현 계획: `docs/plans/2026-03-03-interview-bridge-impl.md`

### Work Stream: `w-interview-bridge`

- [x] **#77** plan-parser.mjs: plan 문서 Markdown 파서 구현 _(2026-03-03 완료)_
  - `scripts/lib/plan-parser.mjs`: `parsePlanDocument(content, filename)` 함수
  - Goal, tasks(체크박스), acceptance_criteria, changed_files, is_empty_template 추출
  - work_id: 파일명에서 날짜 prefix 제거하여 생성
  - 템플릿 placeholder 필터링 ("Step 1", "Criterion 1" 스킵)
  - `tests/unit/plan-parser.test.mjs`: 4개 유닛 테스트
  - 의존: #52

- [x] **#78** bridge-output.mjs: 훅 응답 JSON 빌더 구현 _(2026-03-03 완료)_
  - `scripts/lib/bridge-output.mjs`: `buildBridgeOutput(plan, status)` 함수
  - 성공 시: `[CCH BRIDGE ACTIVATED]` + /cch-team 파이프라인 트리거 지시
  - 실패 시: `[CCH BRIDGE WARNING]` + 원인별 안내 (no_plan_found, empty_template, no_tasks)
  - `continue: true` 항상 반환 (도구 실행 차단 금지)
  - `tests/unit/plan-bridge.test.mjs`: 3개 유닛 테스트
  - 의존: #77

- [x] **#79** plan-bridge.mjs: PostToolUse 훅 메인 오케스트레이터 구현 _(2026-03-03 완료)_
  - `scripts/plan-bridge.mjs`: ExitPlanMode PostToolUse 훅 스크립트
  - 오늘 날짜 plan 문서 탐색 (mtime 기준 최신)
  - 파싱 → `.claude/cch/execution-plan.json` 저장
  - `bin/cch work create` + `work transition doing` + `mode code` 자동 실행
  - `additionalContext`로 /cch-team 파이프라인 트리거 지시 주입
  - 모든 에러 시 `{"continue":true}` 반환 (non-blocking)
  - 의존: #77, #78

- [x] **#80** hooks.json에 PostToolUse:ExitPlanMode 엔트리 등록 _(2026-03-03 완료)_
  - `hooks/hooks.json` PostToolUse 배열에 ExitPlanMode 매처 추가
  - `node scripts/plan-bridge.mjs` 실행, timeout 5초
  - 기존 PreToolUse plan-doc-reminder.sh 유지 (역할 분리)
  - 의존: #79

- [x] **#81** Interview Bridge 통합 테스트 _(2026-03-03 완료)_
  - `tests/integration/plan-bridge-e2e.test.mjs`: E2E 흐름 검증
  - 임시 plan 문서 생성 → ExitPlanMode 입력 → execution-plan.json 생성 확인
  - non-ExitPlanMode 입력 시 안전 통과 확인
  - teardown으로 임시 파일 자동 정리
  - 의존: #79, #80

### Phase 3B 의존성 그래프

```
Phase 3+ 완료 태스크
 └─ #52 (문서 자동 영구화) ────┐
                                │
 #77 plan-parser.mjs ───────────┤
  └─ #78 bridge-output.mjs ─────┤
      └─ #79 plan-bridge.mjs ───┤
          └─ #80 hooks.json 등록┤
                                │
          #81 통합 테스트 ◄─────┘
```

---

## Phase 3S: Source Install Type System (소스 설치 유형 분류 체계)

> 목적: 외부 소스(superpowers, omc, ruflo 등)의 설치 유형을 구분하여 각 소스에 맞는 설치/검증 전략 적용
> 배경: 현재 CCH는 모든 소스를 `git clone`으로 동일하게 처리하나, 실제 소스별 성격이 다름
>
> | 소스 | 실제 성격 | 현재 CCH 방식 | 올바른 설치 | 문제점 |
> |------|----------|-------------|-----------|--------|
> | superpowers | Claude Code **플러그인** (marketplace) | git clone | `/plugin install` | 디렉터리만 있고 플러그인 미등록, skills/hooks 미활성 |
> | omc | Claude Code **플러그인** (marketplace) | git clone → `.omc/` | `/plugin install` | 플러그인은 별도 설치됨, git clone은 불필요한 중복 |
> | ruflo | **Node.js 프로젝트** (npm) | git clone | git clone + `npm install` | dependencies 미설치, 기능 사용 불가 |
> | gptaku_plugins | 파일 모음 | git clone | git clone (적합) | 정상 |
> | dot | 로컬 실험 | 내장 `./dot/` | 별도 설치 불필요 | 정상 |

### Work Stream: `w-source-type-system`

- [ ] **#56** `manifests/sources.json` 스키마 확장: `install_type` 필드 도입
  - 4개 설치 유형 정의:
    - `plugin`: Claude Code 플러그인 마켓플레이스 기반 (superpowers, omc)
    - `npm`: Node.js 프로젝트, clone 후 `npm install` 필요 (ruflo)
    - `git`: 단순 git clone으로 충분 (gptaku_plugins)
    - `local`: 로컬 내장, 외부 설치 불필요 (dot)
  - `plugin` 유형 추가 필드: `marketplace`, `plugin_id` (예: `superpowers@superpowers-marketplace`)
  - `npm` 유형 추가 필드: `post_install` (예: `npm install`)
  - 기존 필드(`repo`, `target`, `scope`, `branch`) 유지, 하위 호환 보장
  - 스키마 예시:
    ```json
    {
      "superpowers": {
        "install_type": "plugin",
        "marketplace": "superpowers-marketplace",
        "plugin_id": "superpowers@superpowers-marketplace",
        "repo": "https://github.com/obra/superpowers",
        "target": ".claude/cch/sources/superpowers",
        "scope": "project",
        "branch": "main",
        "description": "Core skill library"
      }
    }
    ```
  - `install_type` 미지정 시 기본값 `git` (하위 호환)
  - 의존: #10

- [ ] **#57** `check_source_available` 유형별 가용성 검증 분기 구현
  - `plugin` 유형: `~/.claude/plugins/installed_plugins.json`에서 `plugin_id` 존재 여부 확인
    - 디렉터리만 있고 플러그인 미등록 시 → `degraded` (설치 안내 메시지 출력)
  - `npm` 유형: git clone 디렉터리 존재 + `node_modules/` 존재 여부 확인
    - clone만 되고 `npm install` 미실행 시 → `degraded`
  - `git` 유형: 기존 로직 유지 (디렉터리 존재 확인)
  - `local` 유형: 기존 DOT 로직 유지
  - 검증 결과에 `check_detail` 추가 (예: `plugin_not_installed`, `npm_deps_missing`)
  - `bin/cch`의 `check_source_available()` 함수 리팩터링
  - 의존: #56, #10

- [ ] **#58** `sources_install()` 유형별 설치 전략 분기 구현
  - `plugin` 유형: git clone 생략, 설치 안내 메시지 출력
    - Claude Code 내부에서 `claude plugin install`이 불가하므로 사용자에게 명령 안내
    - marketplace 미등록 시 `extraKnownMarketplaces` 등록 안내도 포함
  - `npm` 유형: git clone 후 `post_install` 명령 자동 실행
  - `git` 유형: 기존 `git clone --depth 1` 로직 유지
  - `local` 유형: 설치 동작 없음 (스킵)
  - `bin/lib/sources.sh`의 `sources_install()` 함수 확장
  - 의존: #56

- [ ] **#59** `cch doctor` 소스 진단 강화 (유형별 상태 리포트)
  - 소스 상태 출력에 `install_type` 및 `check_detail` 포함:
    ```
    === External Sources ===
      [OK]     omc (plugin: oh-my-claudecode@omc) - installed via marketplace
      [MISS]   superpowers (plugin: superpowers@superpowers-marketplace) - plugin not installed
               → Fix: claude plugin install superpowers@superpowers-marketplace
      [WARN]   ruflo (npm) - dependencies not installed
               → Fix: cd .claude/cch/sources/ruflo && npm install
      [OK]     gptaku_plugins (git) - cloned
    ```
  - `[MISS]` 상태에 유형별 수정 가이드 자동 출력
  - `[WARN]` 상태 추가: 디렉터리 존재하지만 불완전 설치 (npm deps 누락, 플러그인 미등록 등)
  - `cch status --json`에도 `install_type`, `check_detail`, `fix_command` 필드 추가
  - 의존: #57, #11

- [ ] **#60** Source Type System 테스트 추가
  - `tests/test_source_types.sh` 신규 생성
  - 테스트 케이스:
    1. `install_type` 미지정 → 기본값 `git` 적용 확인
    2. `plugin` 유형 → `installed_plugins.json` 기반 검증 동작 확인
    3. `npm` 유형 → `node_modules/` 존재 여부 기반 검증 확인
    4. `git` 유형 → 기존 디렉터리 기반 검증 확인
    5. `sources_install` → `plugin` 유형 시 clone 스킵 + 안내 메시지 확인
    6. `cch doctor` → 유형별 상태/수정 가이드 출력 확인
    7. 하위 호환: `install_type` 없는 기존 `sources.json` → 정상 동작 확인
  - 기존 6-layer 테스트 체계의 Resilience Layer에 통합
  - 의존: #57, #58, #21

### Phase 3S 의존성 그래프

```
기존 완료 태스크
 ├─ #10 (Resolver) ──────────┐
 ├─ #11 (Health Reporter) ───┤
 └─ #21 (테스트 6레이어) ────┤
                              │
 #56 sources.json 스키마 확장 ┤
  ├─ #57 check_source_available 분기 ┤
  │   └─ #59 doctor 진단 강화 ───────┤
  └─ #58 sources_install 분기 ───────┤
                                      │
               #60 Source Type 테스트 ◄┘
```

### Phase 3S → Phase 3 연동

- #57 완료 후 #32(`health-rules.json`) 수정 시 `install_type` 기반 규칙 반영 가능
- #59 완료 후 #30(`status --json`) 출력에 `install_type`/`check_detail` 포함

---

## Phase 4: Framework v2 Core (Policy-Driven Orchestrator 전환)

> 목적: v2 설계서 기반으로 "통합 플러그인"을 "운영 가능한 통합 프레임워크"로 승격
> 기준 문서: `docs/plans/2026-03-03-cch-framework-v2-design.md`

### 4.1 정책/스키마 정규화

- [ ] **#36** Mode Profile JSON 스키마 정규화 (`profiles/*.json`)
  - 필수 필드: `mode`, `capabilities.primary/optional/fallback_order`, `dot.eligible/overlay_sources`
  - 기존 profiles를 구조화된 JSON으로 마이그레이션
  - 의존: #6

- [ ] **#37** Capability Registry 스키마 도입 (`manifests/capabilities.json`)
  - 필수 필드: `required_by_mode`, `health_impact`, `check_strategy`, `version_policy`
  - resolver가 registry를 참조하도록 반영
  - 의존: #10, #36

- [ ] **#54** Resolved Output 스키마 정규화 (`.resolved/state.json`)
  - v2 설계서 6.4 필수 필드 준수: `schema_version`, `mode`, `dot_enabled`, `resolved_at`
  - `sources`: `active`/`missing`/`fallback_applied` 구조화
  - `health`: `status`/`reason_code`/`reasons` 구조화
  - golden output 비교 테스트 fixture 추가 (`.resolved/*.golden.json`)
  - 의존: #10, #35, #37

### 4.2 명령/오류 계약 표준화

- [ ] **#38** 명령 계약 v2 표준화
  - 표준 종료코드: `0`(success), `1`(validation/runtime failure), `2`(blocked by policy)
  - 표준 출력 블록: `summary`(사람) + `machine`(JSON/key-value)
  - 모든 명령에 증적 기록 필수화(`cmd`, `args`, `mode`, `result`, `reason_code`, `duration_ms`)
  - 의존: #27, #30, #31

- [ ] **#39** 오류 분류 체계 표준화
  - 5개 오류 클래스: `E_VALIDATION`, `E_SOURCE_MISSING`, `E_POLICY_BLOCKED`, `E_INTEGRITY`, `E_RUNTIME`
  - 오류별 복구 전략 구현 (즉시 실패, fallback, 축소 운용)
  - `error_class`를 run log에 연동
  - 의존: #27, #38

### 4.3 런타임 인프라

- [ ] **#40** state 디렉터리 네임스페이스 정규화
  - 루트 직기록(`mode`, `health`, `dot_enabled`)을 `state/` 하위로 이전
  - 하위 호환: 기존 경로 읽기 시 자동 리디렉션
  - 의존: #5

- [ ] **#41** 동시성 제어 lock 파일 도입
  - `mode`/`update` 등 변이 명령에 lock 파일 적용
  - lock timeout/강제해제 정책 구현
  - 의존: #38

### 4.4 CI/테스트 게이트

- [ ] **#42** CI 게이트 정규화 (단계별 테스트 범위)
  - PR: contract + agent + skill
  - merge: workflow + resilience + dot_gate
  - release: full suite + integrity + bundle smoke (macOS/WSL)
  - 의존: #28, #29, #33

### Phase 4 Release Gate

- [ ] **#43** Phase 4 통합 검증
  - [ ] Mode Profile JSON 스키마 기반 resolve 동작 검증
  - [ ] Capability Registry 참조 기반 health 판정 검증
  - [ ] 명령 계약 v2 종료코드/출력 블록 검증
  - [ ] 오류 클래스별 복구 전략 동작 검증
  - [ ] state 네임스페이스 정규화 후 하위 호환 검증
  - [ ] lock 파일 동시성 제어 검증
  - [ ] CI 게이트 단계별 테스트 범위 설정 검증
  - 의존: #36, #37, #38, #39, #40, #41, #42

---

## Phase 5: Supply Chain & Operations (릴리즈 채널/관측성)

> 목적: 릴리즈 채널 거버넌스, 서명 체인, 운영 관측성 확보
> 기준 문서: `docs/plans/2026-03-03-cch-framework-v2-design.md` 10절, 13절 P2, 15절 P2

- [ ] **#44** signed release manifest/signature 체인 도입
  - `release.manifest`(version, build metadata) + optional `release.sig`
  - 서명 검증 실패 시 `update apply` 차단, read-only 축소
  - 의존: #8, #38

- [ ] **#45** 릴리즈 채널/승격 정책 자동화 (dev/candidate/stable)
  - 승격 조건: 6-layer 통과 + 무결성 검사 + 회귀 임계치 미충족
  - 채널별 보증 수준 문서화
  - 의존: #43, #44

- [ ] **#55** KPI metrics 스키마 확장
  - 기존 `{"ts","metric","value","mode"}` 포맷에 `experiment_id`, `window` 필드 추가
  - 스키마 버전 필드 도입으로 하위 호환 보장
  - 의존: #20

- [ ] **#46** 운영 KPI 대시보드 정규화
  - `metrics/` JSONL 기반 집계/시각화 인터페이스
  - `daily`/`weekly` 윈도우 지원
  - 의존: #20, #26, #55

- [ ] **#47** DOT 게이트 자동 판정 리포트
  - 2주 PoC 결과 자동 리포트 생성
  - KPI 달성/미달 요약 + 킬스위치 트리거 여부 판정
  - 의존: #14, #46

- [ ] **#48** 모드별 SLO 정의 및 경보
  - 각 모드에 대한 SLO 기준 정의 (resolve 시간, 가용성 등)
  - SLO 위반 시 자동 경보/로깅
  - 의존: #37, #32

### Phase 5 Release Gate

- [ ] **#49** Phase 5 통합 검증 + Framework Readiness 최종 판정
  - [ ] 명령 계약 문서와 구현 일치
  - [ ] resolve 결과의 결정성 보장
  - [ ] health reason_code 표준화
  - [ ] fallback 경로 자동 적용 및 근거 출력
  - [ ] update check/apply/rollback 실동작
  - [ ] 무결성 검증 실패 시 안전 축소 동작
  - [ ] run log start/end/duration 기록
  - [ ] KPI 집계 안정성 보장
  - [ ] 6-layer 테스트 실구현 및 CI 게이트 연결
  - [ ] stable 릴리즈 번들 검증 자동화
  - [ ] 문서-로드맵-TODO 상태 동기화
  - [ ] DOT 실험선과 Baseline 운영선 독립성 검증
  - 의존: #43, #44, #45, #46, #47, #48

---

## Phase PT: PinchTab Web UI Testing Skills

> PinchTab을 활용한 웹 UI 디버깅/테스트 스킬 세트
> 설계 문서: `docs/plans/2026-03-03-pinchtab-skills-design.md`
> 구현 계획: `docs/plans/2026-03-03-pinchtab-skills-impl.md`

- [x] **#61** PinchTab 테스트 디렉토리 구조 생성 _(2026-03-03 완료)_
  - `tests/pinchtab/scenarios/examples/`, `tests/pinchtab/reports/` 생성
  - `.gitignore`에 reports 디렉토리 제외 규칙 추가
  - 의존: 없음

- [x] **#62** `bin/cch-pt` 헬퍼 스크립트 작성 _(2026-03-03 완료)_
  - PinchTab CLI/HTTP API 래퍼 (ensure, health, nav, snap, action, screenshot 등)
  - 세션 디렉토리 초기화 기능 (session-init)
  - 의존: #61

- [x] **#63** `cch-pt-infra` 스킬 작성 _(2026-03-03 완료)_
  - `skills/cch-pt-infra/SKILL.md`: 서버 설치/시작/상태/프로필/정리
  - `bin/cch-pt` 래퍼를 통한 PinchTab 생명주기 관리
  - 의존: #62

- [x] **#64** `cch-pt-test` 스킬 작성 _(2026-03-03 완료)_
  - `skills/cch-pt-test/SKILL.md`: YAML 시나리오 실행, assert 로직
  - 시나리오 YAML 파싱, 스텝별 PinchTab API 호출, 결과 JSON 출력
  - 의존: #62

- [x] **#65** `cch-pt-report` 스킬 작성 _(2026-03-03 완료)_
  - `skills/cch-pt-report/SKILL.md`: CLI 요약 출력 + Markdown 보고서 생성
  - 실패 원인 분석, 스크린샷 연결
  - 의존: #64

- [x] **#66** `cch-pinchtab` 오케스트레이터 스킬 작성 _(2026-03-03 완료)_
  - `skills/cch-pinchtab/SKILL.md`: 진입점, 자연어→계획 변환, 파이프라인 조율
  - 서브에이전트로 pt-infra → pt-test → pt-report 순차 실행
  - 의존: #63, #64, #65

- [x] **#67** 시나리오 템플릿 및 예제 작성 _(2026-03-03 완료)_
  - `tests/pinchtab/scenarios/_template.yaml`: 시나리오 작성 가이드
  - `tests/pinchtab/scenarios/examples/health-check.yaml`: 기본 접근 확인
  - `tests/pinchtab/scenarios/examples/form-test.yaml`: 폼 입력 테스트
  - 의존: #64

- [x] **#68** PinchTab 스킬 통합 검증 _(2026-03-03 완료)_
  - PinchTab 서버 기동 + 헬퍼 스크립트 기능 테스트
  - 예제 시나리오 실행 + 보고서 생성 검증
  - 전체 스킬 목록 확인
  - 의존: #66, #67

### Phase PT Release Gate

- [x] **#69** Phase PT 통합 검증 _(2026-03-03 완료)_
  - [ ] bin/cch-pt 전체 명령 동작 확인
  - [ ] 4개 스킬 SKILL.md 형식 검증
  - [ ] 예제 시나리오 실행 및 보고서 생성 확인
  - [ ] 자연어 → 테스트 계획 변환 동작 확인
  - [ ] 에이전트 간 상태 전달 (세션 디렉토리) 정상 확인
  - 의존: #68

---

## Phase PTW: PinchTab Workflow Execution

> PinchTab 워크플로우 실행 — 자연어 시나리오의 적응형 자동 실행
> 설계 문서: `docs/plans/2026-03-03-pinchtab-workflow-design.md`

- [x] **#70** cch-pinchtab 오케스트레이터에 워크플로우 모드 추가 _(2026-03-03 완료)_
  - `skills/cch-pinchtab/SKILL.md` 확장: 워크플로우 모드 판별 로직
  - 입력 분석에서 "찾아줘/해줘/검색/알려줘" 키워드 감지
  - 4단계 파이프라인 (PLAN → INFRA → EXECUTE → REPORT) 흐름 추가
  - 의존: #66

- [x] **#71** Phase 1 PLAN — 자연어 → 실행 계획 변환 _(2026-03-03 완료)_
  - 자연어 의도 분석 및 URL 추론
  - 대략적 스텝 생성 (navigate, snapshot, fill, click 등)
  - ref 값은 `<dynamic>` 표기 — 실행 시 동적 결정
  - 사용자 승인 흐름 (계획 제시 → 승인/수정)
  - 의존: #70

- [x] **#72** Phase 3 EXECUTE — 적응형 실행 루프 (OBSERVE-THINK-ACT-VERIFY-RECORD) _(2026-03-03 완료)_
  - OBSERVE: `snap interactive` / `text` 로 현재 상태 파악
  - THINK: Adaptive ref 결정 (role → label → full snap → user)
  - ACT: `click`, `fill`, `press`, `nav` 등 실행
  - VERIFY: `snap diff` / `text` 로 결과 확인
  - RECORD: 스텝별 결과 + 성능 메트릭 JSON 기록
  - 의존: #71

- [x] **#73** 예외 감지 및 사용자 개입 처리 _(2026-03-03 완료)_
  - 요소 못 찾음 → 재 snapshot → 전체 분석 → AskUserQuestion
  - 예상 외 팝업/모달 → 스크린샷 + 사용자 문의
  - 로그인/캡챠 감지 → headed 모드 전환 제안
  - 최대 반복 제한 (스텝 3회, 전체 30스텝, 5분)
  - 의존: #72

- [x] **#74** 데이터 추출 및 결과 보고 확장 _(2026-03-03 완료)_
  - `extracted-data.json` 구조화 저장
  - pt-report 확장: 워크플로우 컨텍스트 + 데이터 추출 결과 포함
  - CLI 실시간 출력 형식 (진행률 + 추출 데이터 요약)
  - 의존: #72

- [x] **#75** 워크플로우 통합 검증 _(2026-03-03 완료)_
  - 자연어 → 계획 변환 동작 확인
  - 적응형 실행 루프 동작 확인 (네이버 검색 시나리오)
  - 예외 처리 및 사용자 개입 흐름 확인
  - 데이터 추출 + 보고서 생성 확인
  - 의존: #73, #74

### Phase PTW Release Gate

- [x] **#76** Phase PTW 통합 검증 _(2026-03-03 완료)_
  - [ ] 워크플로우 모드 판별 정상 동작
  - [ ] 자연어 → 실행 계획 변환 동작
  - [ ] OBSERVE-THINK-ACT-VERIFY-RECORD 사이클 동작
  - [ ] 적응형 ref 결정 전략 동작
  - [ ] 예외 감지 및 사용자 개입 처리
  - [ ] 데이터 추출 결과 JSON 저장
  - [ ] CLI 실시간 출력 + Markdown 보고서 생성
  - 의존: #75

---

## 전체 Phase 의존성 요약

```
Phase 1 (완료) ─── #1~#17: Plugin MVP
     │
Phase 2 (완료) ─── #18~#23: Architecture 보완
     │
Phase 3 (완료) ─── #24~#35,#53: Week-1 Execution (P0+P1, 2026-03-03 완료)
     │
Phase 3+ (완료) ── #50~#52: Hook/Team/Doc 자동화
     │
Phase 3B (완료) ── #77~#81: Interview-to-Execution Bridge
     │
Phase 3S (예정) ── #56~#60: Source Install Type System (소스 설치 유형 분류)
     │
Phase PT (예정) ── #61~#69: PinchTab Web UI Testing Skills
     │
Phase PTW (예정) ─ #70~#76: PinchTab Workflow Execution (적응형 자동 실행)
     │
Phase 4 (예정) ─── #36~#43,#54: Framework v2 Core (정책/스키마/계약)
     │
Phase 5 (예정) ─── #44~#49,#55: Supply Chain & Operations (채널/서명/관측성)
```

---

## Critical Path (갱신)

```
Phase 1~2: #1 → #2 → #3 → #5 → #6 → #10 → #13 → #14 → #15 → #17 → #23
Phase 3:   #24 → #25 → #30 → #31 → #32 → #53 → #33
Phase 3+:  #50 → #51 → #52
Phase 3B:  #77 → #78 → #79 → #80 → #81
Phase 3S:  #56 → #57 → #58 → #59 → #60
Phase PT:  #61 → #62 → #63 → #64 → #65 → #66 → #67 → #68 → #69
Phase PTW: #70 → #71 → #72 → #73 → #74 → #75 → #76
Phase 4:   #36 → #37 → #54 → #38 → #39 → #41 → #43
Phase 5:   #55 → #46 → #47 → #44 → #45 → #49
```

### Phase PT 의존성 그래프

```
#61 (디렉토리 구조)
 └─→ #62 (bin/cch-pt 헬퍼)
      ├─→ #63 (cch-pt-infra 스킬)
      └─→ #64 (cch-pt-test 스킬)
           ├─→ #65 (cch-pt-report 스킬)
           └─→ #67 (시나리오 템플릿/예제)
      #63 + #64 + #65
           └─→ #66 (cch-pinchtab 오케스트레이터)
      #66 + #67
           └─→ #68 (통합 검증)
                └─→ #69 (Phase PT Release Gate)
```

### Phase PTW 의존성 그래프

```
#66 (cch-pinchtab 오케스트레이터) ← Phase PT
 └─→ #70 (워크플로우 모드 추가)
      └─→ #71 (PLAN: 자연어→계획 변환)
           └─→ #72 (EXECUTE: 적응형 실행 루프)
                ├─→ #73 (예외 감지/사용자 개입)
                └─→ #74 (데이터 추출/보고 확장)
                #73 + #74
                     └─→ #75 (워크플로우 통합 검증)
                          └─→ #76 (Phase PTW Release Gate)
```

### Phase 3S 연동 포인트

```
Phase 3S               Phase 3 / Phase 4
─────────              ──────────────────
#57 (check_available) ──→ #32 (health-rules.json) install_type 기반 규칙 반영
#59 (doctor 강화)     ──→ #30 (status --json) install_type/check_detail 출력
#56 (스키마 확장)     ──→ #37 (Capability Registry) check_strategy 연동
```
