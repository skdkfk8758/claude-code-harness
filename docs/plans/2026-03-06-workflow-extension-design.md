# Workflow Extension — 프로젝트 로컬 리소스 해석 설계

## Problem Statement

현재 워크플로우 오케스트레이터의 모든 리소스 해석이 **플러그인 루트에 하드바인딩**되어 있다.
다른 프로젝트에서 CCH를 플러그인으로 설치하면, 프로젝트 고유의 에이전트/스킬/워크플로우를
추가하거나 기존 것을 오버라이드할 수 없다.

### 현재 해석 경로 (단일)

| 리소스 | 해석 경로 | SKILL.md 라인 |
|--------|----------|--------------|
| Agent 프롬프트 | `{plugin-root}/agents/{name}.md` | 258-259 |
| Cross-cutting 스킬 | `{plugin-root}/skills/{name}/SKILL.md` | 360 |
| Enforcement 스킬 | `{plugin-root}/skills/{name}/SKILL.md` | 384 |
| 워크플로우 YAML | `{CLAUDE_SKILL_DIR}/*.yaml` | 19 |
| Gate 스킬 | 사용자가 직접 호출 (해석 문제 없음) | — |

### 사용자 시나리오

1. **커스텀 에이전트 추가**: e-commerce 프로젝트에서 `payment-specialist` 에이전트를 만들어 워크플로우에서 사용
2. **기존 에이전트 오버라이드**: `code-refactor-master`에 프로젝트 특화 규칙을 추가한 버전 사용
3. **커스텀 워크플로우**: 프로젝트 고유의 `data-migration` 워크플로우 정의
4. **커스텀 cross-cutting 스킬**: 프로젝트 고유의 보안 규칙 스킬을 워크플로우에 연결

## Chosen Approach: Fallback Chain Resolution

### 핵심 원칙

1. **Project-first** — 프로젝트 로컬 리소스가 플러그인 리소스보다 우선
2. **Zero-config** — 프로젝트에 `.claude/agents/` 등을 만들면 자동 인식, 설정 불필요
3. **하위 호환** — 로컬 리소스가 없으면 기존과 동일하게 플러그인 리소스 사용
4. **명시적 표시** — 로컬 리소스를 사용할 때 로그로 알림

### Resolution 순서

모든 리소스 해석에 동일한 2단계 fallback chain 적용:

```
1. 프로젝트 로컬:  {project-root}/.claude/{resource-type}/{name}
2. 플러그인:       {plugin-root}/{resource-type}/{name}
```

### 리소스별 구체 경로

| 리소스 | Step 1 (프로젝트 로컬) | Step 2 (플러그인 fallback) |
|--------|----------------------|--------------------------|
| Agent | `.claude/agents/{name}.md` | `{plugin-root}/agents/{name}.md` |
| Skill | `.claude/skills/{name}/SKILL.md` | `{plugin-root}/skills/{name}/SKILL.md` |
| Workflow YAML | `.claude/workflows/{name}.yaml` | `{plugin-root}/skills/workflow/{name}.yaml` |

### 로컬 디렉토리 구조

프로젝트에서 확장 시 사용하는 디렉토리:

```
project-root/
  .claude/
    agents/                    # 커스텀 에이전트 프롬프트
      payment-specialist.md
      code-refactor-master.md  # 오버라이드
    skills/                    # 커스텀 cross-cutting 스킬
      security-rules/
        SKILL.md
    workflows/                 # 커스텀 워크플로우 YAML
      data-migration.yaml
    project-config.json        # 기존
    workflow-state.json        # 기존
    knowledge-graph.json       # 기존
```

## Rejected Alternatives

| 대안 | 기각 이유 |
|------|----------|
| `project-config.json`에 경로 매핑 설정 | 설정 복잡도 증가. 파일 존재만으로 자동 인식이 더 단순 |
| `extends` 키워드로 플러그인 리소스 상속 | 마크다운 프롬프트에서 상속 개념이 부자연스러움. 전체 오버라이드가 더 명확 |
| 프로젝트 루트에 `agents/`, `skills/` 직접 배치 | `.claude/` 네임스페이스 밖이라 다른 도구와 충돌 가능 |
| 환경 변수로 경로 주입 | 프로젝트마다 설정 필요, zero-config 원칙 위반 |

## Architecture

### Resolution 흐름

```
[Orchestrator: resolve resource]
       |
       v
  .claude/{type}/{name} 존재?
       |
      YES → 로컬 리소스 사용
       |    [workflow] Using local agent: .claude/agents/payment-specialist.md
       |
      NO → {plugin-root}/{type}/{name} 존재?
       |
      YES → 플러그인 리소스 사용 (기존 동작)
       |
      NO → 에러: "Agent '{name}' not found in local or plugin paths"
```

### SKILL.md 변경 지점

`skills/workflow/SKILL.md`에서 수정이 필요한 섹션:

#### 1. Path Discovery 섹션에 프로젝트 루트 추가

현재:
```
Plugin root (for reading agents):
!`echo ${CLAUDE_PLUGIN_ROOT:-...}`

This skill's directory (for reading workflow YAMLs):
!`echo ${CLAUDE_SKILL_DIR}`
```

변경 후:
```
Plugin root (for reading agents):
!`echo ${CLAUDE_PLUGIN_ROOT:-...}`

Project root (for reading local overrides):
!`echo ${CLAUDE_PROJECT_ROOT:-.}`

This skill's directory (for reading workflow YAMLs):
!`echo ${CLAUDE_SKILL_DIR}`
```

#### 2. Resource Resolution 섹션 신규 추가

Path Discovery 다음에 새 섹션 추가:

```markdown
## Resource Resolution

리소스 해석 시 프로젝트 로컬을 먼저 탐색하고, 없으면 플러그인으로 fallback한다.

### resolve-agent(name)
1. Check `{project-root}/.claude/agents/{name}.md`
2. Fallback: `{plugin-root}/agents/{name}.md`
3. Not found → error

### resolve-skill(name)
1. Check `{project-root}/.claude/skills/{name}/SKILL.md`
2. Fallback: `{plugin-root}/skills/{name}/SKILL.md`
3. Not found → error

### resolve-workflow(name)
1. Check `{project-root}/.claude/workflows/{name}.yaml`
2. Fallback: `{plugin-root}/skills/workflow/{name}.yaml`
3. Not found → error

로컬 리소스를 사용할 때 알림:
    [workflow] Using local {type}: .claude/{type-path}/{name}
```

#### 3. 기존 해석 지점 수정 (4곳)

| 섹션 | 현재 | 변경 |
|------|------|------|
| `type: agent` (라인 258-259) | `Read {plugin-root}/agents/{agent-name}.md` | `resolve-agent({agent-name})` |
| Cross-Cutting Rules (라인 360) | `Read {plugin-root}/skills/{name}/SKILL.md` | `resolve-skill({name})` |
| Enforcement (라인 384) | `Read {plugin-root}/skills/{skill-name}/SKILL.md` | `resolve-skill({skill-name})` |
| Available Workflows (라인 23) | `이 스킬 디렉토리의 *.yaml 스캔` | `프로젝트 로컬 + 스킬 디렉토리 모두 스캔, 이름 충돌 시 로컬 우선` |

#### 4. Available Workflows 병합 로직

```
1. Scan {project-root}/.claude/workflows/*.yaml → local workflows
2. Scan {CLAUDE_SKILL_DIR}/*.yaml → plugin workflows
3. Merge: 같은 파일명이면 local 우선, 나머지는 합집합
4. 목록 표시 시 로컬 워크플로우에 (local) 표시:

   사용 가능한 워크플로우:
     1. feature-dev — 기능 개발 워크플로우
     2. data-migration (local) — 데이터 마이그레이션
```

## Scope and Constraints

### In Scope

- 에이전트 프롬프트 fallback 해석
- Cross-cutting 스킬 fallback 해석
- 워크플로우 YAML fallback 해석 + 병합
- 로컬 리소스 사용 시 로그 출력
- `.gitignore` 업데이트 (`.claude/skills/`는 이미 포함, `.claude/agents/`와 `.claude/workflows/` 추가 필요 여부 확인)

### Out of Scope

- 에이전트/스킬 프롬프트의 상속/부분 오버라이드 (전체 파일 교체만)
- 로컬 리소스 유효성 검증 (스키마 체크 등)
- GUI/CLI를 통한 로컬 리소스 scaffolding
- 로컬 워크플로우 YAML에서 커스텀 condition check 추가

### Constraints

- `skills/workflow/SKILL.md` 단일 파일 수정 (+ `.gitignore` 가능)
- 에이전트 프롬프트, YAML 파일은 변경하지 않음
- `.claude/` 디렉토리 내 기존 파일(project-config, workflow-state, knowledge-graph)과 충돌 없음
- 로컬 리소스가 없으면 기존과 100% 동일하게 동작 (하위 호환)

## Risk Areas

| 리스크 | 영향 | 완화 |
|--------|------|------|
| 로컬 에이전트 품질 불안정 | 프롬프트가 불완전하면 에이전트 성능 저하 | 로그로 로컬 사용 알림, 문제 시 삭제하면 플러그인 fallback |
| 워크플로우 YAML 이름 충돌 | 로컬이 플러그인을 무조건 덮어씀 | `(local)` 표시로 사용자 인지, 의도적 오버라이드만 허용 |
| `.claude/` 디렉토리 비대화 | agents/skills/workflows 추가로 디렉토리 복잡도 증가 | 선택적 — 필요한 프로젝트만 사용 |
| 플러그인 업데이트 시 로컬 오버라이드와 괴리 | 플러그인 에이전트가 개선되어도 로컬 오버라이드가 구버전 유지 | 문서화로 사용자 주의 안내 |

## Success Criteria

1. 프로젝트에 `.claude/agents/test-agent.md`를 두면 워크플로우에서 해당 에이전트가 사용됨
2. `.claude/agents/`가 없으면 기존과 동일하게 플러그인 에이전트 사용 (하위 호환)
3. `.claude/workflows/custom.yaml`을 두면 `/workflow` 목록에 `(local)` 표시와 함께 나타남
4. 로컬 리소스 사용 시 `[workflow] Using local agent: ...` 로그 출력
5. 플러그인 에이전트와 동일한 이름의 로컬 에이전트를 두면 로컬이 우선
6. `.claude/skills/my-rule/SKILL.md`를 두면 cross-cutting에서 참조 가능

## Decision Summary

| Decision | Rationale |
|----------|-----------|
| Project-first (로컬 우선) | 프로젝트 특화 요구가 범용 플러그인보다 구체적이므로 우선 |
| Zero-config (파일 존재 = 자동 인식) | 설정 파일 추가 없이 디렉토리 규약으로 해결 |
| 전체 파일 오버라이드 (상속 없음) | 마크다운 프롬프트에서 부분 상속은 복잡도 대비 가치 낮음 |
| `.claude/workflows/` 별도 디렉토리 | `.claude/skills/workflow/`는 플러그인 구조와 혼동, 독립 네임스페이스가 명확 |
| 로그 출력 필수 | 어떤 리소스가 사용되는지 투명하게 보여야 디버깅 가능 |
