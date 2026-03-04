# Work ID: w-p1-policy-status

- 작성일: 2026-03-03
- 목표 마감: 2026-03-09
- 우선순위: P1
- 관련 TODO: #30, #31, #32

---

## 1. 목표

운영 가시성과 정책 기반 판정을 강화한다.

1. `cch status --json` 제공
2. health reason_code 표준화
3. health 규칙 외부화(`manifests/health-rules.json`)

---

## 2. 범위

### In Scope

1. `cmd_doctor` 확장 (`--json` 플래그)
2. health 판정 결과 구조화 (`status`, `reason_code`, `reasons`)
3. health rule 파일 정의/로드/적용

### Out of Scope

1. release signature 도입
2. full policy engine 프레임워크화
3. DOT KPI 자동 의사결정 엔진

---

## 3. 작업 항목 체크리스트

- [ ] `cch status --json` 인터페이스 추가
- [ ] 사람이 읽는 출력과 기계 출력 포맷 분리
- [ ] 상태 판정 결과에 `reason_code` 필수화
- [ ] run log에도 동일 reason_code 기록 연동
- [ ] `manifests/health-rules.json` 스키마 초안 작성
- [ ] 최소 3개 룰 적용:
  - swarm에서 ruflo missing -> Blocked
  - optional source missing -> Degraded
  - resolved active source 0개 -> Blocked
- [ ] rule parse 실패 시 안전 fallback 정책 정의

---

## 4. 수용 기준 (Acceptance Criteria)

1. `cch status --json`이 mode/health/reason_code/work summary를 포함
2. 기존 `cch doctor --summary` 출력은 호환 유지
3. reason_code는 모든 health 상태에서 누락 없이 출력
4. health rule 파일 수정이 코드 수정 없이 판정에 반영됨

---

## 5. 검증 계획

1. contract/agent/workflow 테스트 확장
2. rule fixture 변경 후 판정 결과 비교
3. json 출력 스냅샷 테스트(필드 누락 방지)

---

## 6. 예상 산출물

1. 코드 수정: `bin/cch`
2. 신규 파일: `manifests/health-rules.json`
3. 테스트 보강: status JSON / reason_code / rule 적용 케이스

---

## 7. 리스크

1. 규칙 외부화 시 rule/코드 불일치
2. status 출력 확장으로 기존 파서 의존 깨질 가능성

대응:

1. rule 버전 필드 도입 및 최소 스키마 검증
2. `--json`은 신규 옵션으로 추가해 기존 텍스트 출력 유지
