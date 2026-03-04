# CCH 스킬 중복 정리 — 설계 문서

- 작성일: 2026-03-04
- 상태: approved

## 1. 개요

CCH 스킬 생태계(marketplace 50개, repo 18개)에서 확인된 중복과 동기화 문제를 3단계로 정리한다.

**목표**: 50개 → ~44개 축소, repo↔marketplace 동기화 완료

**원칙**:
- 네이티브 스킬(cch-review, cch-verify)이 thin wrapper(cch-sp-*)보다 우선
- 기능이 풍부한 쪽이 살아남음
- 단계별 커밋으로 롤백 가능

## 2. 현황 분석

### 위치별 스킬 분포
| 위치 | 수 | 비고 |
|------|---|------|
| marketplace (`plugins/marketplaces/.../skills/`) | 50 | canonical |
| repo (`skills/`) | 18 | 3개 marketplace에 없음 |
| dist (v0.2.0) | 52 | marketplace + 2 |

### Repo 전용 스킬 (marketplace 누락)
- `cch-review`: 체크리스트 기반 코드 리뷰 + superpowers 선택적 강화
- `cch-verify`: 테스트 실행 + 실패 분석 + debug/TDD 흡수
- `cch-lsp`: LSP 서버 감지/설치/Serena 설정

## 3. Phase A — 확실한 중복 삭제 (6개)

| # | 삭제 대상 | 근거 | 대체 |
|---|-----------|------|------|
| 1 | `cch-sp-brainstorm` | `cch-plan` Phase 1이 동일 프로세스 인라인 수행 (context 탐색→질문→접근법→설계문서) | `cch-plan` |
| 2 | `cch-sp-write-plan` | `cch-plan` Phase 2가 동일 프로세스 인라인 수행 (설계문서→TDD task 분해→impl.md) | `cch-plan` |
| 3 | `cch-sp-verify` | `cch-verify`(repo)가 완전 버전 (테스트+실패분석+debug+TDD). sp-verify는 thin wrapper | `cch-verify` |
| 4 | `cch-dot` | `bin/cch dot <on|off>` 단일 명령 래퍼 | CLI 직접 사용 |
| 5 | `cch-update` | `bin/cch update check` 단일 명령 래퍼 | CLI 직접 사용 |
| 6 | `cch-release` | `bin/cch release <ver>` 단일 명령 래퍼 | CLI 직접 사용 |

### 삭제 영향 범위
- `cch-sp-brainstorm`: `cch-sp-write-plan`이 "Called after" 참조 → 함께 삭제되므로 문제없음
- `cch-sp-write-plan`: `cch-sp-subagent-dev`, `cch-sp-execute-plan`이 후속 스킬로 참조 → `cch-plan`의 완료 보고에서 동일 옵션 제공하므로 문제없음
- `cch-sp-verify`: `cch-sp-finish-branch`, `cch-sp-debug`가 참조 → `cch-verify`로 대체 안내 필요
- `cch-dot`, `cch-update`, `cch-release`: 독립적, 참조 없음

## 4. Phase B — 스킬 통합 (2건)

### B-1. 코드 리뷰 통합

**현재**:
- `cch-review` (repo): 자체 체크리스트 4카테고리(기능/품질/안전성/테스트) + superpowers Enhancement
- `cch-sp-code-review` (marketplace): superpowers:requesting-code-review에 100% 위임

**통합 → `cch-review`**:
- 기본 동작: 체크리스트 리뷰 (superpowers 없어도 동작)
- Enhancement (Tier 1+): superpowers code-reviewer 서브에이전트 사용
- `cch-sp-code-review`의 SHA 범위 지정 기능을 Step 1에 흡수
- 결과: `cch-sp-code-review` 삭제, `cch-review`를 marketplace에 추가

### B-2. 검증 통합

**현재**:
- `cch-verify` (repo): 테스트 실행 + 실패 분석 + debug + TDD 통합
- `cch-sp-verify`: Phase A에서 이미 삭제

**작업**: repo의 `cch-verify`를 marketplace에 추가 (내용 변경 없음)

## 5. Phase C — Repo ↔ Marketplace 동기화

repo 전용 3개 스킬을 marketplace에 반영:
1. `cch-review` (Phase B에서 통합 완료된 버전)
2. `cch-verify` (repo 원본)
3. `cch-lsp` (repo 원본)

동기화 후 `bin/cch sync` 실행하여 dist 반영.

## 6. 참조 업데이트 대상

삭제/통합되는 스킬을 참조하는 다른 스킬:

| 참조하는 스킬 | 참조 내용 | 수정 방향 |
|-------------|----------|----------|
| `cch-sp-subagent-dev` | "cch-sp-code-review 호출" | → "cch-review 호출"로 변경 |
| `cch-sp-finish-branch` | "cch-sp-verify 호출" | → "cch-verify 호출"로 변경 |
| `cch-sp-debug` | "cch-sp-verify로 검증" | → "cch-verify로 검증"으로 변경 |
| `cch-plan` 완료보고 | "cch-sp-brainstorm/write-plan 참조" | 자기 참조 제거 (자체 Phase로 수행) |

## 7. 범위 외 (추후 별도 작업)

- 병렬 실행 4중복 통합 (cch-sp-parallel-agents, cch-gp-pumasi, cch-gp-team, cch-rf-swarm)
- cch-full-pipeline ↔ cch-team 통합
- Prefix 기능 중심 리네이밍 (cch-sp-* → cch-*)
- cch-pt-* user-invocable 설정 변경

## 8. 산출물 맵

| Phase | 변경 | 파일 경로 |
|-------|------|----------|
| A | 삭제 | `marketplace/skills/cch-sp-brainstorm/` |
| A | 삭제 | `marketplace/skills/cch-sp-write-plan/` |
| A | 삭제 | `marketplace/skills/cch-sp-verify/` |
| A | 삭제 | `marketplace/skills/cch-dot/` |
| A | 삭제 | `marketplace/skills/cch-update/` |
| A | 삭제 | `marketplace/skills/cch-release/` |
| B | 수정 | `marketplace/skills/cch-sp-code-review/` → 삭제 |
| B | 추가 | `marketplace/skills/cch-review/` (repo에서 복사+SHA 기능 흡수) |
| B | 추가 | `marketplace/skills/cch-verify/` (repo에서 복사) |
| C | 추가 | `marketplace/skills/cch-lsp/` (repo에서 복사) |
| 참조 | 수정 | `marketplace/skills/cch-sp-subagent-dev/SKILL.md` |
| 참조 | 수정 | `marketplace/skills/cch-sp-finish-branch/SKILL.md` |
| 참조 | 수정 | `marketplace/skills/cch-sp-debug/SKILL.md` |
