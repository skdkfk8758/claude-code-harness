---
name: cch-review
description: Code review checklist with optional subagent dispatch. Reviews implementation against spec and coding standards.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Agent, AskUserQuestion
argument-hint: <리뷰할 브랜치, PR 번호, 커밋 범위, 또는 SHA..SHA>
---

# CCH Review - 코드 리뷰

구현이 스펙과 코딩 표준에 부합하는지 리뷰합니다.

## Steps

### Step 1 - 리뷰 범위 결정

ARGUMENTS를 분석하여 리뷰 대상을 결정합니다:

1. **PR 번호**: `gh pr diff <number>` 로 변경사항 추출
2. **커밋 범위**: `git diff <range>` 로 변경사항 추출
3. **브랜치명**: `git diff main...<branch>` 로 변경사항 추출
4. **SHA 범위**: `git diff <base-sha>..<head-sha>` 로 변경사항 추출
5. **인자 없음**: `git diff main...HEAD` (현재 브랜치 vs main)

변경 파일 목록과 diff를 수집합니다.

### Step 2 - 체크리스트 리뷰

다음 항목을 순서대로 검사합니다:

**기능 (Functionality)**
- [ ] 변경사항이 의도된 기능을 구현하는가?
- [ ] 엣지 케이스가 처리되는가?
- [ ] 에러 핸들링이 적절한가?

**코드 품질 (Quality)**
- [ ] 기존 코드 스타일/패턴과 일관적인가?
- [ ] 불필요한 복잡도가 없는가?
- [ ] 매직 넘버, 하드코딩된 값이 없는가?

**안전성 (Safety)**
- [ ] 보안 취약점 (injection, XSS, 등)이 없는가?
- [ ] 민감 정보가 커밋에 포함되지 않았는가?
- [ ] 기존 기능이 깨지지 않는가? (regression)

**테스트 (Testing)**
- [ ] 새 코드에 대한 테스트가 있는가?
- [ ] 테스트가 의미 있는 시나리오를 커버하는가?

### Step 3 - 결과 보고

```
## 코드 리뷰 결과

변경: N개 파일, +X/-Y 줄

| 카테고리 | 상태 | 비고 |
|---------|------|------|
| 기능 | OK/ISSUE | ... |
| 품질 | OK/ISSUE | ... |
| 안전성 | OK/ISSUE | ... |
| 테스트 | OK/ISSUE | ... |

### 발견 사항
1. [severity] 설명 — 파일:줄번호
2. ...

결론: APPROVED / CHANGES_REQUESTED / NEEDS_DISCUSSION
```

## Enhancement (Tier 1+)

> superpowers 플러그인이 설치되어 있으면 다음 강화 기능을 활용합니다.

- **Tier 1+**: `superpowers:code-reviewer` 서브에이전트를 Step 2 대신 사용
  - Agent 도구로 `superpowers:code-reviewer` 워크플로우를 가진 서브에이전트 디스패치
  - 더 심층적인 코드 분석 및 패턴 검출
  - 서브에이전트 실패 시 기본 체크리스트로 폴백
