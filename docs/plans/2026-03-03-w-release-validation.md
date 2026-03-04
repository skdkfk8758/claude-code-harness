# Work ID: w-release-validation

- 작성일: 2026-03-03
- 목표 마감: 2026-03-10
- 우선순위: Release Gate
- 관련 TODO: #28, #29, #33

---

## 1. 목표

릴리즈 게이트를 "문서 주장"이 아닌 "검증 결과"로 닫는다.

1. 6-layer 테스트를 실파일 기준으로 완성
2. stable 번들 smoke + lock 무결성 검증
3. 문서(PRD/Architecture/Roadmap/TODO) 상태 동기화

---

## 2. 범위

### In Scope

1. `tests/test_resilience.sh` 작성
2. `tests/test_dot_gate.sh` 작성
3. `scripts/test.sh all` 결과 검증
4. 번들 빌드 + clean 디렉터리 smoke
5. 문서 상태값 정렬

### Out of Scope

1. 장기 채널 정책 자동화(dev/candidate/stable 파이프라인)
2. WSL 환경 자동 실행 파이프라인 신설

---

## 3. 작업 항목 체크리스트

- [ ] Resilience 테스트 파일 생성 및 케이스 구현
- [ ] DOT Gate 테스트 파일 생성 및 케이스 구현
- [ ] `scripts/test.sh all`에서 SKIP 0건 달성
- [ ] 테스트 결과(총/성공/실패)를 문서화
- [ ] `scripts/build-release.sh`로 번들 생성
- [ ] clean 경로에서 setup/mode/status/update smoke 실행
- [ ] `update check` lock PASS 확인
- [ ] PRD/Architecture/Roadmap/TODO 상태 문구 동기화

---

## 4. 수용 기준 (Acceptance Criteria)

1. 6-layer 테스트 실파일 존재 + 전체 통과
2. 번들 smoke에서 핵심 명령(`setup`, `mode`, `status`, `update check`) 성공
3. lock 검증 PASS 재현 가능
4. 문서 간 상충되는 상태/수치(예: 테스트 개수, 완료 여부) 제거

---

## 5. 검증 계획

1. 로컬:
   - `bash scripts/test.sh all`
   - `bash scripts/build-release.sh`
2. clean smoke:
   - 임시 디렉터리에서 번들 실행
   - `bash bin/cch setup`
   - `bash bin/cch mode code`
   - `bash bin/cch doctor --summary`
   - `bash bin/cch update check`

---

## 6. 산출물

1. 테스트 파일 2개
2. smoke 검증 로그 요약
3. 동기화된 문서 세트(PRD/Architecture/Roadmap/TODO)

---

## 7. 리스크

1. 기존 문서의 완료 선언과 실제 구현 상태 충돌
2. 테스트 추가 후 숨겨진 회귀 발견 가능성

대응:

1. 숫자/상태의 단일 기준을 테스트 결과로 고정
2. 회귀는 TODO에 즉시 신규 항목으로 승격
