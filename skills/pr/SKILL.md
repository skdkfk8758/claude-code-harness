---
name: cch-pr
description: Use when creating a pull request. Analyzes branch diff, generates Korean PR title/body with workflow context, and creates the PR via gh CLI.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
argument-hint: "[base-branch] or [PR 설명]"
---

# PR Skill

현재 브랜치의 변경사항을 분석하여 한글 PR을 생성한다.

## Config Loading

Read PR settings from:
!`echo "${CLAUDE_PROJECT_ROOT:-.}/.claude/project-config.json"`

## Input Resolution

1. **base-branch 지정** — 해당 브랜치 대비 diff 분석 (e.g., `/pr main`, `/pr develop`)
2. **PR 설명** — 자연어 설명을 PR 본문에 반영
3. **인자 없음** — base를 `main`으로 간주

## Process

### Phase 1: Pre-flight Check

```bash
git branch --show-current
git status --porcelain
git log --oneline {base}..HEAD
git diff --stat {base}..HEAD
```

1. main/default 브랜치에서 실행 시 STOP: "PR은 feature 브랜치에서 생성합니다."
2. 커밋되지 않은 변경이 있으면: "커밋되지 않은 변경사항이 있습니다. 먼저 `/commit`으로 정리하시겠습니까?"
3. base 대비 커밋이 없으면 STOP: "base 브랜치와 차이가 없습니다."

### Phase 2: 변경사항 분석

1. **커밋 히스토리**: `git log --oneline {base}..HEAD` — 모든 커밋 분석 (최신 커밋만이 아닌 전체)
2. **파일 변경 통계**: `git diff --stat {base}..HEAD`
3. **워크플로우 컨텍스트** (있는 경우):
   - `.claude/workflow-state.json` 읽기
   - 각 step의 `summary`, `decisions`, `issues` 추출
4. **plan 문서** (있는 경우):
   - `docs/plans/` 하위의 관련 문서 탐색

### Phase 3: PR 초안 생성

분석 결과를 바탕으로 한글 PR 초안 작성:

```markdown
## 요약
{변경의 목적과 핵심 내용을 2-3문장으로}

## 주요 변경사항
- {변경 1}
- {변경 2}
- ...

## 주요 결정사항
{워크플로우 컨텍스트에서 추출한 결정 사항. 없으면 섹션 생략}

## 리뷰 결과
{아키텍처 리뷰 요약. 없으면 섹션 생략}

## 관련 문서
- [설계](docs/plans/{date}-{name}-design.md)
- [계획](docs/plans/{date}-{name}-plan.md)
- [리뷰](docs/plans/{date}-{name}-review.md)
{문서가 없으면 섹션 생략}

## 테스트
{테스트 통과 여부, 커버리지 변화 등. 확인 불가 시 "수동 확인 필요" 표기}
```

**PR 제목**: `<type>(<scope>): <한글 설명>` — 70자 이내
- 커밋이 단일 type이면 그대로 사용
- 여러 type이면 가장 중요한 변경의 type 사용
- scope는 브랜치명 또는 주요 변경 모듈에서 추출

### Phase 4: 사용자 확인

```
PR 초안:

제목: feat(workflow): 자동 브랜치 생성 및 메타인지 기법 도입
본문: (위 내용 미리보기)

진행할까요? (Y / 제목 수정 / 본문 수정)
```

### Phase 5: Push & PR 생성

```bash
# 1. Remote에 push (tracking 설정)
git push -u origin $(git branch --show-current)

# 2. PR 생성
gh pr create --title "<제목>" --body "$(cat <<'EOF'
<본문>

---
Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Phase 6: 결과 보고

```
PR 생성 완료:
  제목: feat(workflow): 자동 브랜치 생성 및 메타인지 기법 도입
  URL: https://github.com/...
  base: main ← feature/v3-enhancements
```

## 데이터 소스 우선순위

PR 본문 생성 시 아래 순서로 정보를 수집:

1. **workflow-state.json** — 가장 풍부한 컨텍스트 (summary, decisions, issues)
2. **docs/plans/** — 설계/계획/리뷰 문서 링크
3. **커밋 히스토리** — workflow 없을 때 fallback
4. **사용자 인자** — 자연어 설명이 있으면 요약에 반영

## Rules

- NEVER create PR from main/default branch
- NEVER push with `--force` unless user explicitly requests
- PR 제목/본문은 반드시 한글 (기술 용어만 원문 유지)
- 데이터가 있는 섹션만 포함 — 빈 섹션 생성 금지
- 사용자 확인 없이 push/PR 생성하지 않음
- 모든 커밋을 분석 — 최신 커밋만 보고 PR 설명 작성 금지
