---
name: cch-skill-manager
description: Manage, analyze, and create skills across all plugin sources. Use for skill inventory, linting, creation, and dependency analysis.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Agent, Write, Edit, AskUserQuestion
argument-hint: "list | info <name> | lint [name] | create <name> | edit <name> | deps [name] | search <query>"
---

# CCH Skill Manager

스킬 인벤토리, 품질 분석, 생성/수정, 의존성 분석을 위한 통합 관리 도구.

## Step 1 — 인자 파싱

ARGUMENTS 문자열에서 서브커맨드와 대상을 추출합니다.

```
첫 단어 → subcommand (list, info, lint, create, edit, deps, search)
나머지 → target (스킬 이름 또는 검색 쿼리)
인자가 없으면 → list 실행
```

## Step 2 — Light Operations (직접 처리)

`list`, `info`, `search`, `sources` 서브커맨드는 CLI를 직접 호출합니다.

### list — 전체 스킬 인벤토리

```bash
bash bin/cch skill list
```

결과를 읽기 좋은 테이블로 포맷합니다:

| Name | Source | Invocable | Words | Enhancement |
|------|--------|-----------|-------|-------------|

### info — 단일 스킬 상세

```bash
bash bin/cch skill info <name>
```

### search — 키워드 검색

```bash
bash bin/cch skill search "<query>"
```

### sources — 소스 목록

```bash
bash bin/cch skill sources
```

## Step 3 — Heavy Operations (에이전트 디스패치)

`lint`, `create`, `edit`, `deps` 서브커맨드는 분석 에이전트를 디스패치합니다.

### lint — 품질 분석

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-linter`

프롬프트에 포함할 내용:
1. 분석 대상 (특정 스킬 이름 또는 "전체")
2. 기본 검증은 `bash bin/cch skill validate <file>` 활용
3. 심화 규칙 (SM004-SM012) 체크
4. 결과를 심각도별로 그룹화 (error → warn → info)

### create — 새 스킬 생성

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-creator`

프롬프트에 포함할 내용:
1. 생성할 스킬 이름
2. SKILL.md 템플릿 (frontmatter + body 구조)
3. 기존 패턴 참조 (cch-commit, cch-plan 등)

### edit — 기존 스킬 수정

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-editor`

프롬프트에 포함할 내용:
1. 수정할 스킬의 현재 SKILL.md 경로 (`bash bin/cch skill info <name>`)
2. 현재 내용 분석 후 수정 가이드

### deps — 의존성/충돌 분석

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-dep-analyzer`

프롬프트에 포함할 내용:
1. 분석 대상 (특정 스킬 또는 전체)
2. 크로스 레퍼런스 패턴: `cch-name`, `Skill("name")`, `bin/cch <cmd>`
3. 중복 감지 기준 (description 유사도)
4. 결과: 의존성 목록 + 충돌 경고

## Step 4 — 결과 출력

서브커맨드 결과를 사용자에게 포맷하여 출력합니다.
에이전트 결과는 요약하여 전달합니다.
