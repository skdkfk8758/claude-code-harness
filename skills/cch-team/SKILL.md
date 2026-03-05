---
name: cch-team
description: Run dev->test->verify pipeline with automatic documentation
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, TaskCreate, TaskUpdate, TaskList, Write, Edit
---

# CCH Team Pipeline

순차 개발 파이프라인 실행: Plan → Developer → Test Engineer → Verifier → Document

## Steps

### Step 0 - 계획 문서 생성
1. 사용자의 요청을 분석하여 구현 범위를 파악합니다.
2. 작업 ID를 생성합니다: `<date>-<short-desc>` (예: `2026-03-03-login-feature`)
3. **`docs/plans/<work-id>.md` 파일을 생성**합니다:
   - 아래 템플릿을 사용합니다
   - 이 문서 경로를 사용자에게 명시합니다
4. 계획 문서의 상태를 `doing`으로 업데이트합니다.

#### 계획 문서 템플릿 (`docs/plans/<work-id>.md`)

```markdown
# <Title>

- 작업 ID: <work-id>
- TODO 항목: #N
- 생성일: YYYY-MM-DD
- 상태: doing

## 배경
<사용자 요청 요약>

## 구현 범위
- [ ] <항목 1>
- [ ] <항목 2>

## 예상 변경 파일
- `path/to/file1`

## 파이프라인 결과

| 단계 | 상태 | 요약 |
|------|------|------|
| Developer | pending | — |
| Test Engineer | pending | — |
| Verifier | pending | — |

## Done Definition
- [ ] 계획 문서 상태를 `done`으로 업데이트
- [ ] 계획 문서 완료일 기록

## 완료
- 완료일: (완료 후 채움)
```

### Step 1 - Developer
1. TaskCreate로 "[Dev] <구현 내용>" 태스크를 생성합니다.
2. Agent 도구로 executor 서브에이전트를 실행합니다:
   - subagent_type: "general-purpose"
   - 프롬프트에 구현 요구사항 + 계획 문서 경로 전달
   - isolation: "worktree" 사용
3. 완료 후 Task를 completed로 업데이트합니다.

### Step 2 - Test Engineer
1. TaskCreate로 "[Test] <테스트 작성>" 태스크를 생성합니다 (blocked by Step 1).
2. Agent 도구로 테스트 에이전트를 실행합니다:
   - subagent_type: "general-purpose"
   - Stage 1의 변경사항 기반으로 테스트 작성 및 실행
   - 테스트 실패 시 수정 후 재실행
3. 완료 후 Task를 completed로 업데이트합니다.

### Step 3 - Verifier
1. TaskCreate로 "[Verify] <최종 검증>" 태스크를 생성합니다 (blocked by Step 2).
2. Agent 도구로 검증 에이전트를 실행합니다:
   - subagent_type: "general-purpose"
   - 코드 품질 검증 (LSP diagnostics)
   - 테스트 통과 확인
   - 변경사항 요약 리포트 생성
3. 완료 후 Task를 completed로 업데이트합니다.

### Step 4 - 결과 문서화
1. `docs/plans/<work-id>.md` 를 업데이트합니다:
   - 실제 변경된 파일 목록
   - 테스트 결과 요약
   - 검증 결과 요약
   - 완료 시각
2. 계획 문서의 상태를 `done`으로, 완료일을 기록합니다.
3. 사용자에게 최종 보고:
   - "계획 문서: `docs/plans/<work-id>.md`"
   - 구현/테스트/검증 결과 요약
