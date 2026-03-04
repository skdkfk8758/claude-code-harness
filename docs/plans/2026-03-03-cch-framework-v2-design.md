# Claude Code Harness 통합 프레임워크 심화 설계서 (v2.0)

- 작성일: 2026-03-03
- 상태: Proposed
- 대상: `claude-code-harness`를 "다중 서비스 통합 플러그인"에서 "운영 가능한 통합 프레임워크"로 승격
- 기준 문서: `PRD v1.7`, `Architecture v1.7`, `Roadmap v1.7`, `TODO v1.7`

---

## 1. 목적과 문제 재정의

현재 CCH는 다음을 이미 제공한다.

1. 설치 가능한 플러그인 형태
2. slash command 표면(`/cch-*`)
3. mode 기반 라우팅(`plan/code/tool/swarm`)
4. 기본 상태 판정(`Healthy/Degraded/Blocked`)

하지만 프레임워크로 선언하려면 아래가 반드시 닫혀야 한다.

1. **계약 일관성**: 문서-코드-테스트의 단일 사실원(Source of Truth)
2. **실행 결정의 재현성**: 같은 입력이면 같은 resolve 결과
3. **고장 격리와 복구성**: 부분 장애에서 안전하게 축소 운용
4. **공급망 신뢰성**: 업데이트/롤백/검증 체인이 실제로 작동
5. **운영 가시성**: 왜 그런 결정을 했는지 사후 추적 가능

본 문서는 위 5가지를 달성하기 위한 목표 아키텍처, 데이터 계약, 실행 모델, 운영 거버넌스를 정의한다.

---

## 2. 설계 대안 비교

### A안. Thin Wrapper 유지 (현 상태 확장)

요약: 기존 Bash 중심 엔진에 기능을 계속 누적.

장점:

1. 구현 속도 빠름
2. 온보딩 비용 낮음
3. 현재 자산 재사용 최대

단점:

1. 계약 파편화 위험 높음(문서/코드/테스트 드리프트)
2. 복잡 로직(업데이트/정책/실험 게이트) 증가 시 결함 밀도 상승
3. 확장 시 변경 영향 범위가 넓고 예측 어려움

적합도: 단기 MVP에는 적합, 프레임워크 선언에는 부족.

### B안. Policy-Driven Orchestrator (추천)

요약: 엔진은 얇게 유지하되, 결정 로직을 정책/매니페스트 중심으로 외부화.

장점:

1. 모드/소스/헬스 판정 규칙을 데이터화하여 재현성 확보
2. 테스트가 정책 단위로 분해되어 회귀 제어 용이
3. 확장(새 소스, 새 모드, 실험선 추가) 시 코드 변경 최소화

단점:

1. 초기 정규화 비용(스키마, 버전, 마이그레이션) 필요
2. 설계 품질이 낮으면 정책 파일 복잡도 폭증

적합도: 현재 규모와 목표(통합 프레임워크)에 가장 적합.

### C안. Event-Driven Micro-Core

요약: 이벤트 버스 + 플러그인형 어댑터로 엔진 완전 모듈화.

장점:

1. 장기 확장성과 격리성 최상
2. 런타임 관측성/재처리/리플레이에 유리

단점:

1. 과도한 초기 복잡도
2. 현재 팀/제품 단계에 비해 운영 부담 큼

적합도: 장기 후보이나 현 시점 YAGNI 가능성 큼.

### 최종 선택

**B안(Policy-Driven Orchestrator)을 채택**한다.  
이유: 현재 구조를 버리지 않고도 프레임워크 핵심 특성(일관성, 재현성, 운영성)을 확보할 수 있다.

---

## 3. 프레임워크 정의와 비범위

### 3.1 프레임워크 정의

CCH 프레임워크는 다음을 만족해야 한다.

1. 다중 capability source를 mode/policy 기반으로 조합
2. 조합 결과를 표준 출력 계약과 상태 저장소로 가시화
3. 장애 시 축소 실행 경로를 자동 선택하고 근거를 기록
4. 업데이트/검증/롤백의 신뢰 체인을 제공
5. 실험선(DOT)을 생산선(Baseline)과 분리 통제

### 3.2 비범위

1. 분산 시스템 수준의 강한 일관성
2. 중앙 서버형 컨트롤 플레인
3. 실시간 멀티테넌트 스케줄러

---

## 4. 목표 아키텍처

### 4.1 레이어

1. **Interface Layer**
   - slash command (`/cch-*`)
   - CLI (`bin/cch`)

2. **Orchestration Layer**
   - Command Router
   - Mode Engine
   - Resolver Engine
   - Health Evaluator
   - DOT Gate Controller

3. **Policy & Registry Layer**
   - Mode Profile Registry
   - Capability Source Registry
   - Health Rule Registry
   - Update Rule Registry

4. **State & Evidence Layer**
   - runtime state (`.claude/cch/state/*`)
   - work item (`.claude/cch/work-items/*`)
   - run logs (`.claude/cch/runs/*`)
   - metrics (`.claude/cch/metrics/*`)
   - resolved output (`.resolved/*`)

5. **Supply Chain Layer**
   - release manifest/lock/signature
   - update apply/rollback history

### 4.2 컴포넌트 책임 분리

| 컴포넌트 | 책임 | 입력 | 출력 |
| --- | --- | --- | --- |
| Command Router | 명령 파싱/서브커맨드 디스패치 | CLI args | command result |
| Mode Engine | mode 상태 전환/검증 | target mode | state change |
| Resolver Engine | mode+policy로 source 조합 결정 | mode, registry | resolved spec |
| Health Evaluator | 상태 판정 규칙 실행 | availability, policy | Healthy/Degraded/Blocked |
| DOT Gate | 실험선 활성/비활성 및 KPI 게이트 | dot flag, kpi events | experiment decision |
| Update Manager | pin 검증/적용/복구 | release lock, local state | verification/rollback result |
| Evidence Writer | 실행 증적 기록 | decision context | jsonl/yaml artifacts |

### 4.3 핵심 원칙

1. **Policy over hardcode**: 판정 규칙은 코드보다 정책에서 우선 정의
2. **Fail closed for critical path**: 필수 소스 불일치 시 Blocked
3. **Always explain**: 모든 상태는 근거 코드(reason_code) 포함
4. **Deterministic resolve**: 같은 입력=같은 출력(정렬/우선순위 고정)
5. **Baseline first**: DOT는 기본 비활성, 생산선 독립 보장

---

## 5. 명령 계약(Command Contract) v2

모든 명령은 다음 공통 계약을 갖는다.

1. 표준 종료코드:
   - `0`: success
   - `1`: validation/runtime failure
   - `2`: blocked by policy

2. 표준 출력 블록:
   - `summary`: 사람이 읽는 요약
   - `machine`: 파싱 가능한 key-value 또는 JSON

3. 증적 기록:
   - `cmd`, `args`, `mode`, `result`, `reason_code`, `duration_ms`

### 5.1 `/cch-setup`

1. 전제: 실행 경로 접근 가능
2. 수행:
   - 상태 디렉터리 준비
   - 필수 registry/manifest 검증
   - 초기 mode/health 생성
3. 출력:
   - setup status
   - missing artifacts
   - next action

### 5.2 `/cch-mode <mode>`

1. 전제: mode가 registry에 존재
2. 수행:
   - mode 전환
   - resolve 재실행
   - health 재판정
3. 출력:
   - previous mode / current mode
   - resolved source set
   - health delta

### 5.3 `/cch-status`

1. 출력 최소 필드:
   - current mode
   - health + reason_code
   - resolved sources
   - dot status
   - active work item summary
   - latest run outcome

2. 요구: 문서상의 PLAN/TODO 연계 상태를 포함해야 함.

### 5.4 `/cch-update [check|apply|rollback|history]`

1. `check`: lock 검증 + mismatch 리포트
2. `apply`: rollback point 생성 후 적용
3. `rollback <id>`: 대상 스냅샷 복원(인자 필수 전달)
4. `history`: 적용/복원 이력

### 5.5 `/cch-dot on|off|status`

1. code mode에서만 `on/off` 허용
2. `on`:
   - DOT 소스/캐시 검증
   - resolve overlay 반영
3. `status`:
   - 활성 여부
   - 컴파일/캐시 상태
   - KPI 요약

---

## 6. 정책/스키마 설계

### 6.1 Mode Profile Schema (`profiles/*.json`)

필수 필드:

1. `mode`: 고유 mode id
2. `capabilities.primary`: 기본 소스 배열
3. `capabilities.optional`: 선택 소스 배열
4. `capabilities.fallback_order`: 장애 시 대체 우선순위
5. `dot.eligible`: 실험 적용 가능 여부
6. `dot.overlay_sources`: DOT 활성 시 추가할 소스

### 6.2 Capability Registry Schema (`manifests/capabilities.json`)

필수 필드:

1. `required_by_mode`: 모드별 필수성
2. `health_impact`: 미가용 시 영향 등급
3. `check_strategy`: availability 판정 전략(path, command, signature)
4. `version_policy`: 허용 버전 범위

### 6.3 Health Rule Schema (`manifests/health-rules.json`)

예시 규칙:

1. `if mode=swarm and missing ruflo -> Blocked`
2. `if missing optional source -> Degraded`
3. `if resolve output empty -> Blocked`

### 6.4 Resolved Output Schema (`.resolved/state.json`)

필수 필드:

```json
{
  "schema_version": "1.0",
  "mode": "code",
  "dot_enabled": false,
  "resolved_at": "2026-03-03T00:00:00Z",
  "sources": {
    "active": ["omc", "superpowers"],
    "missing": [],
    "fallback_applied": []
  },
  "health": {
    "status": "Healthy",
    "reason_code": "OK",
    "reasons": []
  }
}
```

### 6.5 Work Item Schema (`todo.yaml`)

필수 필드:

1. `id`, `title`, `status`
2. `created_at`, `updated_at`
3. `transitions[]`:
   - `from`, `to`, `at`, `reason`

허용 전이:

1. `todo -> doing`
2. `doing -> blocked`
3. `blocked -> doing`
4. `doing -> done`

---

## 7. Resolver/Health 알고리즘

### 7.1 Resolver 알고리즘 (결정적 실행)

1. profile 로드
2. source 후보 집합 생성
3. source id 사전순 정렬
4. 각 source availability 검사
5. missing source를 impact 기준으로 분류
6. fallback_order에 따라 대체 적용
7. 결과 객체(`active/missing/fallback_applied`) 생성
8. health evaluator 호출
9. 결과를 `.resolved/state.json`에 원자적 기록

### 7.2 DOT Overlay 규칙

1. `dot_enabled=true`이고 `dot.eligible=true`인 mode에서만 적용
2. `dot.overlay_sources`를 primary 뒤에 병합
3. overlay 충돌 시 `priority` 필드 우선
4. DOT 컴파일 성공의 정의:
   - 소스 존재
   - 예상 엔트리 파일 존재
   - 캐시 동기화 성공

### 7.3 Health 판정 규칙

1. `Blocked`: 필수 source 결손, 정책 위반, resolve 결과 비어 있음
2. `Degraded`: optional source 결손, 대체 경로 적용됨
3. `Healthy`: 필수 경로 완전 + 정책 위반 없음

정책 엔진은 반드시 `reason_code`를 반환한다.

---

## 8. 오류 모델과 복구 전략

### 8.1 오류 분류

1. `E_VALIDATION`: 잘못된 인자/상태 전이
2. `E_SOURCE_MISSING`: source 탐지 실패
3. `E_POLICY_BLOCKED`: 정책 위반으로 실행 차단
4. `E_INTEGRITY`: lock/signature 불일치
5. `E_RUNTIME`: 명령 실행 중 예외

### 8.2 복구 전략

1. Validation 오류: 즉시 실패 + 올바른 사용법 반환
2. Source missing: fallback 시도 후 health 하향
3. Integrity 오류: update/apply 차단, read-only 모드로 축소
4. Runtime 오류: 작업 상태를 `blocked`로 전이 가능하도록 증적 기록

### 8.3 복구 우선순위

1. 데이터 무결성 보존
2. 실행 가능 최소 경로 확보
3. 사용자에게 원인/다음 행동 제시

---

## 9. 실행 증적(Evidence) 설계

### 9.1 Run Log (`.claude/cch/runs/<date>/<work-id>.jsonl`)

레코드 필수 필드:

```json
{
  "ts": "2026-03-03T00:00:00Z",
  "cmd": "mode",
  "args": ["code"],
  "work_id": "w-123",
  "mode_before": "plan",
  "mode_after": "code",
  "result": "success",
  "reason_code": "MODE_SWITCHED",
  "duration_ms": 42
}
```

원칙:

1. start/end 모두 기록
2. 실패 시 `error_class`, `error_message` 포함
3. `work_id` 없으면 `_global`

### 9.2 KPI Metrics (`.claude/cch/metrics/dot-poc.jsonl`)

필드:

1. `metric`
2. `value`
3. `mode`
4. `experiment_id`
5. `window` (daily/weekly)

파이프라인 실패가 전체 커맨드 실패로 번지지 않도록, 집계 로직은 반드시 "데이터 없음"을 정상 처리한다.

---

## 10. 업데이트/공급망 거버넌스

### 10.1 Release Artifact 구성

1. plugin payload
2. `release.lock` (SHA256)
3. `release.manifest` (version, build metadata)
4. optional `release.sig` (서명)

### 10.2 Update Check 규칙

1. lock 파일 파싱 성공
2. 각 파일 해시 비교
3. mismatch 유형 분류:
   - changed
   - missing
   - unexpected

### 10.3 Rollback 규칙

1. rollback id 인자 필수
2. 복원 대상:
   - state files
   - resolver output
   - update metadata
3. 복원 후 검증:
   - 상태 파일 존재
   - mode 유효성
   - resolve 재실행 가능성

### 10.4 채널 정책

1. `dev`: 빠른 변경, 낮은 보증
2. `candidate`: 검증 빌드
3. `stable`: 운영 배포

승격 조건:

1. 6-layer 테스트 통과
2. 무결성 검사 통과
3. 회귀 임계치 미충족

---

## 11. 테스트 아키텍처 v2

### 11.1 레이어 구성

1. Contract
2. Agent
3. Skill
4. Workflow
5. Resilience
6. DOT Gate

### 11.2 최소 보증 항목

1. 모든 slash command 정상/오류 계약 검증
2. mode 전환과 resolve 결과의 결정성 검증
3. source 미가용 시 health 판정 정확성 검증
4. rollback 인자 전달/복원 성공 검증
5. KPI 집계에서 데이터 부재 시 정상 반환 검증
6. DOT overlay 적용/미적용 비교 검증

### 11.3 테스트 데이터 전략

1. `fixtures/capabilities/*`로 가용/미가용 조합 생성
2. profile 변형 fixture로 경계조건 검증
3. golden output(`.resolved/*.golden.json`) 비교

### 11.4 CI 게이트

1. PR: contract+agent+skill
2. merge: workflow+resilience+dot_gate
3. release: full suite + integrity + bundle smoke test(macOS/WSL)

---

## 12. 운영 모델

### 12.1 상태 저장소 표준화

권장 구조:

```text
.claude/cch/
  state/
    mode
    health
    dot_enabled
  work-items/
  runs/
  metrics/
  updates/
    rollbacks/
```

현재 루트 직기록 방식은 `state/` 네임스페이스로 정규화한다.

### 12.2 상태 조회 표준

`cch status --json`을 추가해 자동화 친화성 확보:

1. 사람이 읽는 출력과 기계용 출력을 분리
2. 도구 연동 시 문자열 파싱 의존 제거

### 12.3 동시성 제어

1. mode/update 같은 변이 명령에는 lock 파일 적용
2. lock timeout/강제해제 정책 문서화

---

## 13. 마이그레이션 계획 (현실 실행안)

### Phase P0 (1주)

1. update rollback 인자 전달 버그 수정
2. DOT compile 경로(`combo`/`combos`) 정합성 수정
3. KPI show 데이터 부재 처리 안정화
4. run log에 end/duration/result 기록 추가

출시 조건:

1. 치명 결함 0건
2. 회귀 테스트 통과

### Phase P1 (1~2주)

1. policy schema 도입(`health-rules.json`)
2. resolver deterministic 보장(정렬/우선순위 명시)
3. `cch status --json` 도입
4. Resilience/DOT Gate 테스트 파일 실구현

출시 조건:

1. 6-layer 실파일 존재 + CI 통과
2. 문서-코드-테스트 싱크 확인

### Phase P2 (2~4주)

1. release manifest/signature 체인 도입
2. 채널 정책(dev/candidate/stable) 적용
3. 운영 KPI 대시보드 정규화
4. DOT 게이트 자동 판정 리포트

출시 조건:

1. 안정 채널 승격 워크플로우 완료
2. 독립 재현 테스트 통과

---

## 14. 프레임워크 준비도(Framework Readiness) 기준

아래 12개를 모두 만족하면 "프레임워크"로 선언한다.

1. 명령 계약 문서와 구현 일치
2. resolve 결과의 결정성 보장
3. health reason_code 표준화
4. fallback 경로 자동 적용 및 근거 출력
5. update check/apply/rollback 실동작
6. 무결성 검증 실패 시 안전 축소 동작
7. run log start/end/duration 기록
8. KPI 집계 안정성 보장
9. 6-layer 테스트 실구현 및 CI 게이트 연결
10. stable 릴리즈 번들 검증 자동화
11. 문서-로드맵-TODO 상태 동기화
12. DOT 실험선과 Baseline 운영선 독립성 검증

---

## 15. 즉시 실행 백로그 (우선순위)

### P0

1. `update rollback` 인자 전달 수정
2. DOT compile 엔트리 경로 일치화
3. `kpi show` 빈 데이터 안전 처리
4. 실행 로그 end 이벤트/소요시간 추가

### P1

1. `status --json` 추가
2. health rule 외부화
3. resilience/dot_gate 테스트 추가
4. release lock 검증 결과를 reason_code로 통일

### P2

1. signed release manifest
2. 릴리즈 채널/승격 정책 자동화
3. 모드별 SLO 정의 및 경보

---

## 16. 결론

현재 CCH는 구조적으로 좋은 출발점이지만, 프레임워크로서 핵심은 "기능 수"가 아니라 "결정의 신뢰성"이다.  
본 설계의 핵심은 다음 한 문장으로 요약된다.

**"결정 로직을 정책화하고, 모든 실행을 증적화하며, 실패를 안전하게 축소하는 통합 오케스트레이션 프레임워크로 전환한다."**

이 문서를 기준으로 P0/P1를 완료하면, CCH는 "통합 플러그인" 수준을 넘어 "운영 가능한 통합 프레임워크"로 정의할 수 있다.
