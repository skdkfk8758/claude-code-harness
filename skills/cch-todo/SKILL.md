---
name: cch-todo
description: Show all tasks from plan documents and current session TaskList.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, TaskList
---

# CCH Todo - 작업 목록 통합 조회

플랜 문서와 세션 TaskList를 조회하여 통합 작업 목록을 출력합니다.

## 데이터 소스 (2소스)

1. **플랜 문서** (`docs/plans/*-impl.md`) — 프로젝트 수준 태스크 정의 (SSOT, 영속, git 추적)
2. **TaskList** — 현재 세션 실행 뷰 (휘발, 플랜 문서에서 생성)

## Steps

### Step 1 - 데이터 수집 (병렬)

다음 2개를 **동시에** 읽습니다:

1. `docs/plans/*-impl.md` 파일 목록 및 내용 (Glob + Read) — `### Task N:` 패턴으로 태스크 추출
2. TaskList 도구로 세션 태스크 조회

### Step 2 - 통합 정리

수집된 데이터를 아래 형식으로 정리합니다:

```
## 작업 목록

### 현재 세션 (TaskList)
| # | 작업 | 상태 |
|---|------|------|
(TaskList에서 in_progress/pending 항목. 없으면 "세션 태스크 없음")

### 플랜 문서 태스크
| 플랜 | Task | 제목 | 체크 |
|------|------|------|------|
(impl.md 파일에서 추출한 태스크 목록)
```

### Step 3 - 컨텍스트 요약

마지막에 다음을 추가합니다:

1. **현재 위치**: 어떤 플랜의 어떤 작업 단계인지
2. **권장 다음 작업**: 의존성이 해소된 최우선 미완료 항목

## 주의사항

- 플랜 문서(`docs/plans/*-impl.md`)가 태스크의 SSOT입니다.
- 완료된 항목은 축약하여 컨텍스트를 절약합니다.
- 미완료 항목만 상세 테이블로 출력합니다.
- TaskList는 세션 뷰입니다. 세션 종료 시 소멸하지만 플랜 문서에 진행 상태가 기록됩니다.
