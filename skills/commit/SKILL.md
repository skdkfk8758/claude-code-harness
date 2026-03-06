---
name: cch-commit
description: Use when committing changes. Analyzes working tree, groups changes into logical units, and creates commits with Korean messages following conventional commit format.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
argument-hint: "[all | 파일/디렉토리 패턴]"
---

# Commit Skill

변경사항을 분석하여 논리 단위로 그룹화하고, 한글 커밋 메시지로 커밋한다.

## Config Loading

Read git convention settings from:
!`echo "${CLAUDE_PROJECT_ROOT:-.}/.claude/project-config.json"`

## Input Resolution

1. **`all`** — 모든 변경사항을 논리 단위로 분석 후 다중 커밋
2. **파일/디렉토리 패턴** — 해당 범위만 분석 후 커밋
3. **인자 없음** — `git status`로 전체 변경사항 확인 후 `all`과 동일하게 진행

## Process

### Phase 1: 변경사항 수집

```bash
git status -s
git diff --stat
git diff --cached --stat
```

- 이미 staged된 파일과 unstaged 파일을 구분하여 보여줌
- 변경사항이 없으면 STOP: "커밋할 변경사항이 없습니다."

### Phase 2: 논리 단위 분석

변경된 파일들을 **의미적으로 연관된 그룹**으로 분류:

1. `git diff` (unstaged) + `git diff --cached` (staged) 내용을 분석
2. 아래 기준으로 논리 그룹 생성:
   - **같은 기능/모듈**에 속하는 변경은 하나의 그룹
   - **독립적인 관심사**(config 변경, 문서 업데이트, 새 기능, 버그 수정 등)는 별도 그룹
   - **테스트**는 대응하는 구현과 같은 그룹
3. 각 그룹에 대해:
   - **파일 목록**: 포함된 파일들
   - **변경 요약**: 무엇이 왜 바뀌었는지 1-2문장
   - **커밋 타입**: `feat`, `fix`, `refactor`, `chore`, `docs`, `test` 등
   - **scope**: 변경의 주요 모듈/디렉토리

### Phase 3: 커밋 계획 제시

사용자에게 그룹화 결과를 테이블로 보여줌:

```
논리 단위 커밋 계획:

| # | Type(Scope) | 설명 | 파일 |
|---|-------------|------|------|
| 1 | feat(workflow) | 자동 브랜치 생성 기능 추가 | skills/workflow/SKILL.md, ... |
| 2 | docs(readme) | v3 워크플로우 설명 업데이트 | README.md |
| 3 | chore(config) | gitignore 항목 추가 | .gitignore |

진행할까요? (Y / 수정할 그룹 번호 / 재분류)
```

- 사용자가 **Y** → Phase 4 진행
- 사용자가 **번호** → 해당 그룹 수정 (파일 이동, 분할, 합치기)
- 사용자가 **재분류** → Phase 2 재수행

### Phase 4: 순차 커밋 실행

각 그룹을 순서대로 커밋:

```bash
# 1. 해당 그룹의 파일만 staging
git add <files-in-group>

# 2. 커밋 (HEREDOC으로 메시지 전달)
git commit -m "$(cat <<'EOF'
<type>(<scope>): <한글 설명>

<optional 한글 body — WHY not WHAT>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### Phase 5: 결과 보고

```
커밋 완료 (N개):

| # | Hash | 메시지 |
|---|------|--------|
| 1 | abc1234 | feat(workflow): 자동 브랜치 생성 기능 추가 |
| 2 | def5678 | docs(readme): v3 워크플로우 설명 업데이트 |
```

## 커밋 메시지 규칙

CLAUDE.md의 Git & Release 언어 규칙을 따름:

- **type(scope)**: 영문 유지 — `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`, `perf`
- **설명**: 한글, 명령형, 마침표 없음, 72자 이내
- **body**: 선택사항, 한글, WHAT이 아닌 WHY 설명
- **Co-Authored-By**: 영문 유지

### Scope 결정

1. 변경 파일의 주요 디렉토리에서 추출
   - `skills/workflow/SKILL.md` → `workflow`
   - `agents/plan-reviewer.md` → `plan-reviewer`
2. 여러 디렉토리에 걸치면 가장 상위 공통 모듈 사용
3. 프로젝트 전반 변경 → `project`

## 단일 파일/단순 변경 시

변경사항이 1개 논리 그룹으로 충분한 경우:
- Phase 3의 계획 테이블을 보여주되, 1행만 표시
- 사용자 확인 후 바로 커밋

## Rules

- NEVER commit without showing the plan to user first
- NEVER stage files that look like secrets (.env, credentials, tokens)
- NEVER use `git add -A` or `git add .` — 항상 파일을 명시적으로 지정
- 논리적으로 무관한 변경을 하나의 커밋에 섞지 않음
- 테스트 파일은 대응하는 구현 변경과 같은 커밋에 포함
- staged된 파일이 이미 있으면, 해당 파일을 첫 번째 그룹으로 우선 배치
