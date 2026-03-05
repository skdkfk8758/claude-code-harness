# CCH v3 Renewal - Execution Design

- 작성일: 2026-03-05
- 상태: Approved
- 선행 문서: `2026-03-05-v3-renewal-analysis.md`, `2026-03-05-v3-renewal-plan.md`
- 전략: 순차 실행 (Phase 0-7)
- 성공 기준: v3.0.0 태그 발행

---

## 목표

기존 v3-renewal-plan.md의 7 Phase를 4세션으로 나눠 순차 실행한다.
외부 의존성(superpowers, kkirikkiri, Beads) 완전 제거 후 v3.0.0 태그를 발행한다.

## 세션 분할

### 세션 1: Archive & Dependency Removal (Phase 0 + 1)

Phase 0 - Archive:
- [ ] T0-1: archive/v2/ 생성 및 기존 플랜 이동
- [ ] T0-2: .beads/ 아카이브 후 삭제
- [ ] T0-3: 외부 플러그인 비활성화
- [ ] T0-4: archive 커밋
- [ ] T0-5: v2-archive 태그

Phase 1 - Dependency Removal:
- [ ] T1-1~T1-10: beads.sh/bin/cch/skill.sh/manifests/profiles/scripts 정리

검증: `grep -r "beads\|superpowers" bin/ scripts/` -> 0 결과

### 세션 2: Skill Rewrite (Phase 2)

- [ ] T2-1~T2-12: 13개 스킬 Beads/superpowers 참조 제거 및 내재화
- [ ] T2-13: cch-debug 신규 스킬 생성

검증: 각 스킬의 Enhancement 섹션 0개, Bead/bd 참조 0개

### 세션 3: Persistence & Test (Phase 3 + 4)

Phase 3 - Persistence:
- [ ] T3-1~T3-6: CLAUDE.md/AGENTS.md/auto-memory/SessionStart 훅

Phase 4 - Test Cleanup:
- [ ] T4-1~T4-7: 테스트 정리 및 전체 통과 확인

검증: `bash scripts/test.sh all` 통과

### 세션 4: Docs & Verify (Phase 5 + 6 + 7)

Phase 5 - Docs:
- [ ] T5-1~T5-6: PRD/Architecture/Roadmap/README 갱신

Phase 6 - Plugin Cleanup:
- [ ] T6-1~T6-6: 외부 플러그인 설정/캐시 실제 삭제

Phase 7 - Verification:
- [ ] T7-1~T7-5: 전체 검증 + v3.0.0 태그

## Rollback

- `git checkout v2-archive` 로 전체 복원
- 각 Phase 커밋으로 부분 롤백

## Decisions

| 결정 | 이유 |
|------|------|
| 순차 실행 선택 | 안전성 우선, 의존성 문제 방지 |
| 4세션 분할 | 세션당 작업량 적정화, 리뷰 포인트 확보 |
| Phase 0 먼저 | 아카이브 없이 삭제하지 않음 (복구 보장) |
| v3.0.0 태그 발행이 완료 기준 | 모든 Phase 완료 + 검증 후 태그 |
