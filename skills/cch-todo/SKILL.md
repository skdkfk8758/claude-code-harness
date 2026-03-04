---
name: cch-todo
description: Show all tasks from Beads (primary), session tasks, and execution plans.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, TaskList
---

# CCH Todo - 작업 목록 통합 조회

모든 작업 소스를 수집하여 통합 작업 목록을 출력합니다.

## 데이터 소스 (우선순위 순)

1. **Beads** (`bash bin/cch beads list`) — 프로젝트 수준 태스크 추적 (SSOT)
2. **`docs/Roadmap.md`** — 마일스톤 및 마감일
3. **`docs/plans/`** — 활성 실행 계획 문서
4. **TaskList** — 현재 세션 내 태스크

## Steps

### Step 1 - 데이터 수집 (병렬)

다음 4개를 **동시에** 읽습니다:

1. `bash bin/cch beads list --json` — Beads 태스크 목록 조회
2. `docs/Roadmap.md` 전체 읽기
3. `docs/plans/*.md` 파일 목록 확인 (Glob)
4. TaskList 도구로 세션 태스크 조회

### Step 2 - 통합 정리

수집된 데이터를 아래 형식으로 정리합니다:

```
## 작업 목록 (Beads 기준)

### 준비된 작업 (Unblocked)
`bash bin/cch beads ready --limit 10` 결과를 테이블로 출력:
| Bead ID | 작업 | Phase | 우선순위 |
|---------|------|-------|---------|

### Phase별 현황
`bash bin/cch beads list --label "phase:<code>"` 로 Phase별 상태:
| Phase | 열린 항목 | 차단됨 | 완료 |
|-------|----------|--------|------|

### 세션 태스크
TaskList에 등록된 현재 세션 작업 (있는 경우만)

### 실행 계획 연결
활성 `docs/plans/*.md` 문서와 Bead 항목 매핑
```

### Step 3 - 컨텍스트 요약

마지막에 다음을 추가합니다:

1. **현재 위치**: 어떤 Phase의 어떤 마일스톤 단계인지
2. **마감일**: Roadmap 기준 다음 마감
3. **권장 다음 작업**: `bd ready`로 의존 관계가 풀린 최우선 미완료 항목

## 주의사항

- Beads가 SSOT입니다. `bd ready`로 작업 가능한 항목을 조회합니다.
- 완료된 항목은 Phase 단위로 축약하여 컨텍스트를 절약합니다.
- 미완료 항목만 상세 테이블로 출력합니다.
