# Week-1 실행표 (4-Lite)

- 작성일: 2026-03-03
- 기간: 2026-03-04 ~ 2026-03-10
- 마감일: 2026-03-10 (화)
- 기준 전략: B안 단독 (Policy-Driven Orchestrator)
- 상태 소스: `docs/TODO.md`만 사용

---

## 1. 완료 게이트 (전부 필수)

1. 치명 버그(P0) 0건
2. `cch update rollback <id>` 실동작
3. 6-layer 테스트 전체 통과
4. stable 번들 무결성 검증 통과
5. `cch status`에 mode/health/reason_code/work summary 표시
6. DOT on/off가 resolve 결과에 실제 반영
7. PRD/Architecture/Roadmap/TODO 동기화 완료

---

## 2. 우선순위

1. 치명 결함 4개 수정 (rollback, DOT, KPI, run log)
2. Resilience/DOT Gate 테스트 실구현
3. `status --json` + reason_code 표준화 + health-rules 도입
4. 문서 동기화 + stable bundle smoke 검증

---

## 3. PR 분할 계획 (3~5개)

1. PR1: `w-p0-core-stability` (rollback + DOT)
2. PR2: `w-p0-core-stability` (KPI + run log)
3. PR3: `w-release-validation` (resilience + dot_gate tests)
4. PR4: `w-p1-policy-status` (`status --json` + reason_code + health-rules)
5. PR5: `w-release-validation` (문서 동기화 + 번들 smoke 결과)

---

## 4. 일자별 실행표

### 2026-03-04 (수)

1. PR1 착수: rollback 인자 전달/복원 경로 수정
2. DOT compile 경로 정합성(`combo/combos`) 수정
3. 1차 로컬 회귀 확인

### 2026-03-05 (목)

1. PR2 착수: KPI show 무데이터 안정화
2. run log start/end/duration/result 스키마 확장
3. 실패 로그 필드(`error_class`, `error_message`) 반영

### 2026-03-06 (금)

1. PR3 착수: `tests/test_resilience.sh` 작성
2. source missing 시 `Degraded/Blocked` 검증 케이스 추가
3. `tests/test_dot_gate.sh` 초안 작성

### 2026-03-07 (토)

1. PR3 마무리: DOT KPI/kill-switch 테스트 완성
2. `scripts/test.sh all` 기준 6-layer 통과 확인
3. 테스트 flake 여부 점검

### 2026-03-08 (일)

1. PR4 착수: `cch status --json` 추가
2. reason_code 표준화
3. `manifests/health-rules.json` 도입 및 연결

### 2026-03-09 (월)

1. PR4 마무리 및 회귀 테스트
2. PR5 착수: 문서 동기화(PRD/Architecture/Roadmap/TODO)
3. 릴리즈 번들 smoke 검증 실행

### 2026-03-10 (화)

1. 게이트 최종 확인(1~7)
2. 미달 항목 즉시 수정/검증
3. 최종 상태 보고서 작성

---

## 5. 리스크와 대응

1. 리스크: 테스트 레이어 실구현 중 기존 통과 가정과 충돌
   - 대응: PR3에서 실패 케이스를 먼저 고정하고 구현 진행
2. 리스크: health-rules 외부화 시 resolver 회귀
   - 대응: golden resolve 출력 비교 케이스 추가
3. 리스크: 마감 압박으로 문서 드리프트 재발
   - 대응: PR5에서 문서 동기화 체크리스트를 필수 게이트로 운영

---

## 6. 연결 문서

1. `docs/TODO.md` (단일 상태 소스)
2. `docs/plans/2026-03-03-w-p0-core-stability.md`
3. `docs/plans/2026-03-03-w-p1-policy-status.md`
4. `docs/plans/2026-03-03-w-release-validation.md`
5. `docs/plans/2026-03-03-cch-framework-v2-design.md`
