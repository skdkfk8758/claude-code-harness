# Workflow Extension — Tasks

## Summary
- **Total**: 6 tasks in 3 batches
- **Target file**: `skills/workflow/SKILL.md`
- **삽입 위치 기준**: 섹션 헤딩 기반

## Known Limitations
- 로컬 에이전트의 I/O 계약 검증 없음 (문서화로 가이드)
- `.claude/skills/`는 `.gitignore`에 이미 포함 — 로컬 스킬은 git 추적 안 됨

---

--- Batch 1 (Tasks 1-2) → checkpoint ---

### Task 1: Path Discovery에 프로젝트 루트 추가
- **Estimate**: 2분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `## Path Discovery` 섹션 내부, `This skill's directory` 줄 직전
  - 추가할 내용:
    ```
    Project root (for reading local overrides):
    !`echo ${CLAUDE_PROJECT_ROOT:-.}`
    ```
- **Verify**: `grep "Project root" skills/workflow/SKILL.md` → 해당 줄 출력
- **Dependencies**: none

### Task 2: Resource Resolution 섹션 추가
- **Estimate**: 5분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `## Path Discovery` 섹션과 `## Available Workflows` 섹션 사이 (빈 줄 포함)
  - 삽입할 내용:

```
## Resource Resolution

리소스 해석 시 프로젝트 로컬을 먼저 탐색하고, 없으면 플러그인으로 fallback한다.
로컬 디렉토리가 존재하지 않으면 탐색을 건너뛴다 (하위 호환).

### resolve-agent(name)

1. Check `{project-root}/.claude/agents/{name}.md` — 존재하면 사용
2. Fallback: `{plugin-root}/agents/{name}.md`
3. 둘 다 없으면 → error: "Agent '{name}' not found in local (.claude/agents/) or plugin paths"

### resolve-skill(name)

1. Check `{project-root}/.claude/skills/{name}/SKILL.md` — 존재하면 사용
2. Fallback: `{plugin-root}/skills/{name}/SKILL.md`
3. 둘 다 없으면 → error: "Skill '{name}' not found in local (.claude/skills/) or plugin paths"

### resolve-workflow(name)

1. Check `{project-root}/.claude/workflows/{name}.yaml` — 존재하면 사용
2. Fallback: `{plugin-root}/skills/workflow/{name}.yaml`
3. 둘 다 없으면 → error: "Workflow '{name}' not found in local (.claude/workflows/) or plugin paths"

### Resolution 로그

로컬 리소스를 사용할 때 반드시 알림:

    [workflow] Using local agent: .claude/agents/{name}.md
    [workflow] Using local skill: .claude/skills/{name}/SKILL.md
    [workflow] Using local workflow: .claude/workflows/{name}.yaml

플러그인 리소스 사용 시에는 로그 없음 (기존 동작).
```

- **Verify**: `grep -c "resolve-agent\|resolve-skill\|resolve-workflow" skills/workflow/SKILL.md` → 6+ 출력 (정의 3개 + 참조)
- **Dependencies**: Task 1

--- Batch 2 (Tasks 3-5) → checkpoint ---

### Task 3: Available Workflows 병합 로직 추가
- **Estimate**: 3분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **수정 위치**: `## Available Workflows` 섹션 전체 교체
  - 변경 후:

```
## Available Workflows

워크플로우 목록을 두 경로에서 스캔하여 병합한다:

1. 프로젝트 로컬: `{project-root}/.claude/workflows/*.yaml`
2. 플러그인: 이 스킬 디렉토리의 `*.yaml` 파일

병합 규칙:
- 같은 파일명이면 로컬 우선 (오버라이드)
- 나머지는 합집합
- 로컬 워크플로우에는 `(local)` 표시

각 YAML의 `name`과 `description` 필드를 읽어 사용자에게 표시:

    사용 가능한 워크플로우:
      1. {name} — {description}
      2. {name} (local) — {description}
      ...

    번호 또는 이름을 입력하세요:

YAML 파일이 없거나 읽기 실패 시: "등록된 워크플로우가 없습니다."
로컬 디렉토리가 없으면 플러그인만 스캔 (기존 동작).
```

- **Verify**: `grep "(local)" skills/workflow/SKILL.md` → 해당 줄 출력
- **Dependencies**: Task 2

### Task 4: `type: agent` 섹션에서 resolve-agent 사용
- **Estimate**: 2분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **수정 위치**: `` ### `type: agent` (Executor — automatic) `` 섹션 내부
  - 현재 (라인 257-259):
    ```
    1. Resolve the agent prompt file path:
       - Use the plugin root path discovered above
       - Read `{plugin-root}/agents/{agent-name}.md`
    ```
  - 변경 후:
    ```
    1. Resolve the agent prompt file path:
       - Use `resolve-agent({agent-name})` (see Resource Resolution)
    ```
- **Verify**: `grep "resolve-agent" skills/workflow/SKILL.md` → 해당 줄 출력
- **Dependencies**: Task 2

### Task 5: Cross-Cutting Rules와 Enforcement에서 resolve-skill 사용
- **Estimate**: 3분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **수정 위치 1**: `## Cross-Cutting Rules` 섹션
    - 현재: `1. Read each skill from {plugin-root}/skills/{name}/SKILL.md`
    - 변경: `1. Use resolve-skill({name}) for each skill (see Resource Resolution)`
  - **수정 위치 2**: `### Enforcement Verification` 섹션
    - 현재: `1. Read {plugin-root}/skills/{skill-name}/SKILL.md`
    - 변경: `1. Use resolve-skill({skill-name}) (see Resource Resolution)`
- **Verify**: `grep -c "resolve-skill" skills/workflow/SKILL.md` → 4+ 출력 (정의 1 + 참조 3)
- **Dependencies**: Task 2

--- Batch 3 (Task 6) → checkpoint ---

### Task 6: Input Resolution에서 resolve-workflow 사용
- **Estimate**: 2분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **수정 위치**: `## Input Resolution` 섹션, 우선순위 1 행
    - 현재: `| 1. 정확한 YAML명 | /workflow feature-dev | 즉시 로드 |`
    - 변경: `| 1. 정확한 YAML명 | /workflow feature-dev | resolve-workflow({name})로 로드 |`
  - **수정 위치**: `## Startup` 섹션
    - 현재: `2. Read the workflow YAML file (e.g., feature-dev.yaml in this skill's directory)`
    - 변경: `2. Use resolve-workflow({name}) to load the workflow YAML file`
- **Verify**: `grep "resolve-workflow" skills/workflow/SKILL.md` → 2+ 줄 출력
- **Dependencies**: Task 5

---

## Verification Checklist (전체 완료 후)

1. `grep "Project root" skills/workflow/SKILL.md` → 출력 확인
2. `grep "## Resource Resolution" skills/workflow/SKILL.md` → 출력 확인
3. `grep -c "resolve-agent" skills/workflow/SKILL.md` → 2+ (정의 1 + 참조 1+)
4. `grep -c "resolve-skill" skills/workflow/SKILL.md` → 4+ (정의 1 + 참조 3+)
5. `grep -c "resolve-workflow" skills/workflow/SKILL.md` → 3+ (정의 1 + 참조 2+)
6. `grep "(local)" skills/workflow/SKILL.md` → 출력 확인
7. `grep "Using local" skills/workflow/SKILL.md` → 3줄 출력 (agent, skill, workflow)
8. SKILL.md 전체 줄 수 확인: `wc -l skills/workflow/SKILL.md` → 약 700-720줄
