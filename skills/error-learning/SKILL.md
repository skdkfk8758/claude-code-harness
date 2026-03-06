---
name: error-learning
description: Use after fixing errors to extract lessons, before implementation to check past patterns, or manually to record mistakes. Builds and queries the Error Knowledge Base.
user-invocable: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
argument-hint: "<mode: extract|record|check> [context]"
---

# Error Learning Skill

실수에서 배우고, 같은 실수를 반복하지 않는 피드백 루프.

## Input Resolution

입력을 다음 우선순위로 해석:

1. **정확한 모드** — `extract`, `record`, `check` → 즉시 해당 모드 실행
2. **자연어** — 아래 NL 맵으로 모드 매칭 후 실행
3. **인자 없음** — 사용자에게 모드 선택 요청

### NL → Mode Map

| 자연어 키워드 | 매핑 모드 |
|--------------|----------|
| 교훈 추출, 분석, 배운 점, 정리, extract, lesson | `extract` |
| 기록, 저장, 실수 있었어, 메모, record, save | `record` |
| 확인, 검색, 이전 실수, 패턴, 주의사항, check, lookup | `check` |

## 3가지 모드

### Mode: extract (자동 — 수정 완료 후)

워크플로우에서 버그 수정 후 자동 호출. investigation 문서와 diff를 분석하여 교훈을 추출.

#### 입력
- `docs/plans/{date}-{name}-investigation.md` (systematic-debugging 산출물)
- `git diff` (실제 수정 내용)

#### 프로세스

1. **investigation 문서 분석**
   - 근본원인 (Root Cause) 추출
   - 증상 (Symptom) 추출
   - 수정방법 요약

2. **패턴 분류**
   - 카테고리 판별: `logic | async | import | type | config | env | test | design | other`
   - 심각도 판별: `high` (프로덕션 영향) / `medium` (기능 영향) / `low` (개발 편의)
   - 관련 태그 3-5개 도출

3. **중복 체크**
   - `docs/error-patterns/_index.md` 검색
   - 동일/유사 패턴 존재 시 기존 항목 업데이트 (신규 생성 안 함)
   - 신규 패턴이면 다음 ID 할당: `{category}-{NNN}`

4. **KB 저장**
   - `docs/error-patterns/{category}-{NNN}.md` 생성
   - `docs/error-patterns/_index.md` 테이블에 행 추가

#### 패턴 파일 포맷

```markdown
---
id: {category}-{NNN}
category: {category}
severity: {high|medium|low}
tags: [{tag1}, {tag2}, {tag3}]
date: {YYYY-MM-DD}
source: workflow
related-files: [{file1}, {file2}]
repeat-count: 0
---

## 증상
{에러가 어떻게 나타났는지 — 에러 메시지, 실패 양상}

## 근본원인
{왜 발생했는지 — 기술적 원인 1-2문장}

## 수정방법
{어떻게 고쳤는지 — 구체적 코드 변경 요약}

## 예방규칙
- {이 실수를 방지하기 위한 구체적 체크 항목 1}
- {체크 항목 2}
- {체크 항목 3}
```

---

### Mode: record (수동 — 사용자 호출)

워크플로우 밖에서 발생한 실수를 직접 기록.

#### 프로세스

1. **인터뷰** (최소 질문)
   - "어떤 실수가 있었나요?" (증상)
   - "원인이 무엇이었나요?" (근본원인)

2. **자동 보완**
   - 관련 파일 경로: `git diff` 또는 사용자 지정
   - 카테고리/태그: 설명 기반 자동 분류 (사용자 확인)
   - 예방규칙: 원인 기반 자동 도출 (사용자 확인)

3. **KB 저장** (extract와 동일 포맷)

---

### Mode: check (자동 — 구현 시작 전)

구현 에이전트에 주입되는 사전 경고. 변경 대상과 관련된 과거 패턴을 검색.

#### 프로세스

1. **검색 기준 수집**
   - 변경 대상 파일 경로 (태스크 문서 또는 plan에서 추출)
   - 태스크 키워드 (기능명, 모듈명)

2. **KB 검색** (2단계)
   - Stage 1: `_index.md`에서 관련 파일/태그 매칭 (Grep)
   - Stage 2: 매칭된 패턴 파일의 "예방규칙" 섹션만 읽기

3. **주의사항 생성**
   - 매칭된 패턴이 없으면: 아무것도 주입하지 않음
   - 매칭된 패턴이 있으면: 아래 포맷으로 에이전트 프롬프트에 삽입

```
## Past Error Patterns — Check Before You Code

| ID | Category | Severity | Prevention Rule |
|----|----------|----------|-----------------|
| async-001 | async | high | await 누락 시 silent fail — 모든 async 호출에 await 확인 |
| logic-003 | logic | medium | 배열 경계 off-by-one — length 비교 시 < 사용 통일 |

These patterns were found in YOUR target files or related areas.
Review each prevention rule before writing code.
```

---

## Enforcement Verification

`enforcement: enforce`로 cross-cutting 적용 시 오케스트레이터가 확인하는 항목.

### Evidence Required (check 모드)
1. `_index.md` 검색 실행 증거 (Grep 호출 또는 "매칭 패턴 없음" 명시)
2. 매칭 시: 예방규칙이 에이전트 출력에 포함되어 있음

### Evidence Required (extract 모드)
1. 패턴 파일 생성 또는 기존 패턴 업데이트 증거
2. `_index.md` 업데이트 증거

### Pass Criteria
- check: 검색 수행 완료 (매칭 유무 불문)
- extract: 패턴 파일 + 인덱스 업데이트 완료

### Failure Response
```
error-learning 규칙 미준수: KB 검색/저장 증거가 부족합니다.
check 모드: _index.md 검색을 실행하고 결과를 보고하세요.
extract 모드: 패턴 파일과 인덱스 업데이트를 수행하세요.
```

---

## _index.md 초기 구조

KB가 비어있을 때의 초기 파일:

```markdown
# Error Pattern Index

| ID | Category | Tags | Severity | Related Files | Date | Repeats |
|----|----------|------|----------|---------------|------|---------|
```

---

## Rules
- extract 시 investigation 문서가 없으면 git diff + 커밋 메시지로 대체 추출
- record 시 질문은 2개 이하로 제한 (CLAUDE.md 인터뷰 규칙 준수)
- check 시 매칭 패턴이 5개 초과면 severity high만 표시 (노이즈 방지)
- 동일 패턴 재발 시 `repeat-count` 증가 + severity 자동 상향 (low→medium→high)
- 패턴 파일은 절대 삭제하지 않음 — 이력 보존
