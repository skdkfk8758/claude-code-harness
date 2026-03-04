# Work ID: w-p0-core-stability

- 작성일: 2026-03-03
- 목표 마감: 2026-03-06
- 우선순위: P0
- 관련 TODO: #24, #25, #26, #27

---

## 1. 목표

핵심 런타임 안정성 결함 4개를 제거한다.

1. rollback 실동작 보장
2. DOT compile 성공 판정 정합성 보장
3. KPI 집계 무데이터 안정성 보장
4. run log 증적 완전성(start/end/duration/result) 보장

---

## 2. 범위

### In Scope

1. `bin/cch`의 update/dot/kpi 경로 수정
2. `bin/lib/log.sh` 로그 스키마 확장
3. 관련 테스트 보강(기존 레이어 내 단위 검증 포함)

### Out of Scope

1. health-rules 정책화
2. `status --json` 추가
3. release 채널/서명

---

## 3. 작업 항목 체크리스트

- [ ] rollback 인자 전달 누락 수정 (`update rollback <id>`)
- [ ] rollback 성공/실패 종료코드 정규화
- [ ] DOT 소스 경로(`combo` vs `combos`) 정합성 수정
- [ ] DOT compile 성공 조건을 "엔트리 존재 + 캐시 동기화"로 강화
- [ ] KPI show에서 metric 부재 시 정상 반환 보장
- [ ] run log에 end 이벤트 기록 추가
- [ ] run log에 `duration_ms`/`reason_code` 추가
- [ ] 실패 시 `error_class`/`error_message` 기록

---

## 4. 수용 기준 (Acceptance Criteria)

1. `cch update apply` 후 `cch update rollback <id>`가 실제 복원 수행
2. DOT on/off 이후 resolve 결과가 의도대로 달라짐
3. KPI 데이터가 부분 존재해도 `cch kpi show` 종료코드 0
4. 하나의 명령 실행에서 start/end 로그가 모두 기록되고 duration 계산 가능

---

## 5. 검증 계획

1. 로컬 회귀: `scripts/test.sh all`
2. 수동 시나리오:
   - rollback 생성/복원
   - DOT on/off + `.resolved/state.json` diff
   - KPI 부분데이터 집계
   - 실패 명령 실행 후 로그 필드 확인

---

## 6. 예상 산출물

1. 코드 수정: `bin/cch`, `bin/lib/log.sh`
2. 테스트 보강 커밋
3. 실행 로그 예시 스냅샷

---

## 7. 리스크

1. `set -euo pipefail` 환경에서 파이프라인 동작 불안정
2. 로그 스키마 변경으로 기존 log viewer 호환성 영향

대응:

1. 집계 루틴을 "데이터 없음" 정상 흐름으로 처리
2. 로그 리더를 하위 호환 방식으로 유지
