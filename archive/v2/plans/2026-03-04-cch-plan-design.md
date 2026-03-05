# cch-plan 스킬 설계

> 설계(인터뷰) → 플래닝 → TODO 작성 통합 워크플로우

- 작성일: 2026-03-04
- 상태: Approved

## 개요

`cch-plan`은 아이디어부터 실행 가능한 TODO까지 하나의 스킬로 이어주는 통합 워크플로우이다.
기존 superpowers 스킬(brainstorming, writing-plans)을 체이닝하고, TODO 동기화를 추가한다.

## 아키텍처: Phase-Gated with Smart Entry

```
입력 분석 → [Phase 1: Design] → [Phase 2: Plan] → [Phase 3: TODO] → 완료
                 ↑ skip 가능       ↑ skip 가능       ↑ 항상 실행
```

입력 상태에 따라 적절한 Phase부터 시작:
- 아이디어 텍스트 → Phase 1부터
- *-design.md 경로 → Phase 2부터
- *-impl.md 경로 → Phase 3부터

## Step 0: 입력 분석

입력 유형 감지 로직:

1. 인자가 파일 경로인가?
   - `*-design.md` → Phase 2부터 (설계문서 있음)
   - `*-impl.md` → Phase 3부터 (플랜문서 있음)
   - 기타 `.md` → Phase 1, 해당 문서를 컨텍스트로 활용
2. 인자가 텍스트인가? → Phase 1부터 (아이디어)
3. 인자 없음? → AskUserQuestion으로 목적 질문 후 Phase 1

감지 결과를 출력하고 시작 Phase를 안내한다.

## Phase 1: Design (인터뷰)

`superpowers:brainstorming` 스킬 위임.

- 입력: 사용자 아이디어 또는 컨텍스트 문서
- 처리: brainstorming 프로세스 전체 수행
  - 프로젝트 컨텍스트 탐색
  - 명확화 질문 (1회 1개)
  - 2-3가지 접근법 제안
  - 설계 섹션별 제시 + 승인
  - 설계 문서 저장
- 출력: `docs/plans/YYYY-MM-DD-<topic>-design.md`

brainstorming의 마지막 단계("writing-plans 호출")를 cch-plan이 직접 수행하여 자동 연결.

## Phase 2: Plan (구현 계획)

`superpowers:writing-plans` 스킬 위임.

- 입력: Phase 1 설계 문서 (또는 기존 설계 문서 경로)
- 처리: writing-plans 프로세스 전체 수행
  - 코드베이스 탐색
  - Task 분해 (2-5분 단위)
  - TDD 기반 Step 구성
  - 구현 플랜 문서 저장
- 출력: `docs/plans/YYYY-MM-DD-<topic>-impl.md`

실행 옵션 제시 단계를 Phase 3 (TODO Sync)으로 대체.

## Phase 3: TODO Sync

cch-plan 고유 로직.

- 입력: Phase 2 구현 플랜 문서
- 처리:
  1. 플랜 문서에서 Task 목록 파싱
  2. `docs/TODO.md` 읽기 → 마지막 항목 ID 확인
  3. 새 Phase 섹션 + 연속 번호 항목 추가
  4. `docs/TODO.md`에 기록
  5. `TaskCreate`로 현재 세션 실행 항목 생성 (의존성 포함)
- 출력:
  - `docs/TODO.md`에 새 Phase 블록 추가
  - `TaskList`에 실행 가능한 항목들 생성

TODO.md 추가 형식 (기존 패턴 준수):
```markdown
## Phase XX: <Phase명>

### #N <항목 제목>
- [ ] 세부 요구사항 1
- [ ] 세부 요구사항 2
의존: #M (있을 경우)
```

## 산출물 맵

| Phase | 산출물 | 경로 |
|-------|--------|------|
| Phase 1 | 설계 문서 | `docs/plans/YYYY-MM-DD-<topic>-design.md` |
| Phase 2 | 구현 플랜 | `docs/plans/YYYY-MM-DD-<topic>-impl.md` |
| Phase 3 | TODO 항목 | `docs/TODO.md` + `TaskCreate` 세션 항목 |

## SKILL.md 명세

```yaml
---
name: cch-plan
description: "설계(인터뷰) → 플래닝 → TODO 작성 통합 워크플로우"
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit,
               AskUserQuestion, TaskCreate, TaskUpdate, TaskList
argument-hint: <아이디어, 설계문서 경로, 또는 플랜문서 경로>
---
```

| Step | 이름 | 핵심 동작 |
|------|------|----------|
| 0 | 입력 분석 | 인자 파싱, 기존 산출물 탐지, 시작 Phase 결정 |
| 1 | Phase 1: Design | `superpowers:brainstorming` 위임 (skip 가능) |
| 2 | Phase 2: Plan | `superpowers:writing-plans` 위임 (skip 가능) |
| 3 | Phase 3: TODO Sync | docs/TODO.md + TaskCreate 동시 생성 |
| 4 | 완료 보고 | 산출물 경로 + 다음 단계 안내 |
