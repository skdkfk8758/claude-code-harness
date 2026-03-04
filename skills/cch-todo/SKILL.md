---
name: cch-todo
description: Show all tasks from Beads (SSOT) and current session TaskList.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, TaskList
---

# CCH Todo - 작업 목록 통합 조회

Beads(SSOT)와 세션 TaskList를 조회하여 통합 작업 목록을 출력합니다.

## 데이터 소스 (2소스)

1. **Beads** (`bash bin/cch beads list`) — 프로젝트 수준 태스크 추적 (유일한 SSOT, 영속, git 추적)
2. **TaskList** — 현재 세션 실행 뷰 (휘발, Beads에서 hydrate)

## Steps

### Step 1 - 데이터 수집 (병렬)

다음 2개를 **동시에** 읽습니다:

1. `bash bin/cch beads ready --limit 15` — 실행 가능한(unblocked) Beads 조회
2. TaskList 도구로 세션 태스크 조회

### Step 2 - 통합 정리

수집된 데이터를 아래 형식으로 정리합니다:

```
## 작업 목록

### 현재 세션 (TaskList)
| # | 작업 | 상태 | Bead ID |
|---|------|------|---------|
(TaskList에서 in_progress/pending 항목. 없으면 "세션 태스크 없음")

### 준비된 작업 (Beads — 미할당, 차단 없음)
| Bead ID | 작업 | Phase | 우선순위 |
|---------|------|-------|---------|
(bd ready 결과)

### Phase별 진행률
| Phase | 완료 | 진행 | 대기 |
|-------|------|------|------|
(bd list 결과를 Phase 레이블로 집계)
```

### Step 3 - 컨텍스트 요약

마지막에 다음을 추가합니다:

1. **현재 위치**: 어떤 Phase의 어떤 작업 단계인지
2. **권장 다음 작업**: `bd ready`로 의존 관계가 풀린 최우선 미완료 항목

## 주의사항

- Beads가 유일한 SSOT입니다. `bd ready`로 작업 가능한 항목을 조회합니다.
- 완료된 항목은 Phase 단위로 축약하여 컨텍스트를 절약합니다.
- 미완료 항목만 상세 테이블로 출력합니다.
- TaskList는 세션 뷰입니다. 세션 종료 시 소멸하지만 Beads에 상태가 이미 반영되어 있습니다.

## Enhancement (Tier 1+)

> superpowers 플러그인이 설치되어 있으면 다음 강화 기능을 활용합니다.

- **Tier 1+**: Phase별 진행률 표시에 Tier 정보 포함 (`bash bin/cch status` 결과 인라인)
- **Tier 1+**: 권장 다음 작업에 적절한 superpowers 스킬 제안 (예: 설계 필요 시 brainstorming 추천)
