# docs/TODO.md 삭제 — Design

**Date:** 2026-03-04
**Status:** Approved
**Approach:** A (Clean Delete)

---

## 1. 개요 및 목표

### 문제

`docs/TODO.md`가 126개 항목 중 ~123개 완료 상태로 남아있어 Beads SSOT와 이중 관리를 유발.
Phase 9(#113~#116)에서 Beads SSOT 전환을 완료했지만, #117(TODO.md 삭제)만 미실행.

### 목표

1. 미완료 항목 3개를 Beads로 마이그레이션 (또는 드롭)
2. `README.md`, `Architecture.md`, `Roadmap.md`에서 TODO.md 참조 제거
3. `docs/TODO.md` 파일 삭제
4. Plan 문서의 TODO.md 참조는 히스토리 문서이므로 수정하지 않음

### 비변경 범위

- `docs/plans/*.md` — 히스토리 문서, 수정 불필요
- SKILL.md, JSON — 이미 참조 없음
- Beads/TaskList 시스템 — 변경 없음

---

## 2. 미완료 항목 처리 방침

| # | 항목 | 처리 |
|---|------|------|
| #32 | Version Gate (v1/v2 분기) | **드롭** — "보류" 상태이며 v2 전용 운영 확정 |
| #110 | beads.sh JSON 헬퍼 → core.mjs 위임 | **Bead 생성** — 유효한 기술 부채 |
| #117 | docs/TODO.md → Beads 마이그레이션 + 파일 삭제 | **이번 작업에서 완료** |

---

## 3. 참조 정리 대상

| 파일 | 라인 | 현재 내용 | 변경 |
|------|------|-----------|------|
| `README.md` | 79 | `- [TODO](docs/TODO.md)` | 줄 삭제 |
| `docs/Architecture.md` | 190 | `4. docs/TODO.md — 전체 작업 항목 추적` | Beads 참조로 교체 |
| `docs/Roadmap.md` | 71 | `5. docs/TODO.md — 전체 작업 항목 추적` | Beads 참조로 교체 |
| `docs/plans/*.md` | 다수 | TODO.md 언급 | **수정 안 함** (히스토리) |

---

## 4. 산출물 맵

| 파일 | 작업 | 설명 |
|------|------|------|
| `docs/TODO.md` | Delete | 파일 삭제 |
| `README.md` | Modify | TODO.md 링크 제거 |
| `docs/Architecture.md` | Modify | TODO.md 참조 → Beads 참조로 교체 |
| `docs/Roadmap.md` | Modify | TODO.md 참조 → Beads 참조로 교체 |
