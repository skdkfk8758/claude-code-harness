# Workflow Extension — Strategic Plan

## Overview

워크플로우 오케스트레이터의 리소스 해석에 프로젝트 로컬 fallback chain을 추가한다.
`skills/workflow/SKILL.md` 단일 파일 수정으로, 프로젝트별 커스텀 에이전트/스킬/워크플로우를
`.claude/` 디렉토리에 두면 자동으로 인식되게 한다.

## Architecture Impact

### 수정 대상 파일 (1개)

| 파일 | 변경 내용 |
|------|----------|
| `skills/workflow/SKILL.md` | Path Discovery 확장, Resource Resolution 섹션 추가, 기존 해석 지점 4곳 수정, Available Workflows 병합 로직 |

### 변경 없음

- 에이전트 프롬프트 (`agents/*.md`) — 변경 없음
- 워크플로우 YAML 6종 — 변경 없음
- 기타 스킬 (`skills/*/SKILL.md`) — 변경 없음
- `.claude/project-config.json` — 변경 없음

## Implementation Strategy

### Phase 구조

단일 파일의 마크다운 섹션 수정이므로 3 Phase로 순차 진행.

### Phase 1: Path Discovery + Resource Resolution 섹션 추가

**작성 내용:**
1. Path Discovery에 프로젝트 루트 경로 추가
2. Resource Resolution 섹션 신규 작성:
   - `resolve-agent(name)` — `.claude/agents/{name}.md` → `{plugin-root}/agents/{name}.md`
   - `resolve-skill(name)` — `.claude/skills/{name}/SKILL.md` → `{plugin-root}/skills/{name}/SKILL.md`
   - `resolve-workflow(name)` — `.claude/workflows/{name}.yaml` → `{plugin-root}/skills/workflow/{name}.yaml`
   - 로컬 리소스 사용 시 로그 출력 규칙

**삽입 위치:**
- Path Discovery 섹션 내부에 프로젝트 루트 추가
- Path Discovery와 Available Workflows 사이에 Resource Resolution 섹션 삽입

### Phase 2: 기존 해석 지점 수정

**수정 대상 4곳:**
1. `### type: agent` — `Read {plugin-root}/agents/...` → `resolve-agent()` 호출
2. `## Cross-Cutting Rules` — `Read {plugin-root}/skills/...` → `resolve-skill()` 호출
3. `### Enforcement Verification` — `Read {plugin-root}/skills/...` → `resolve-skill()` 호출
4. `## Available Workflows` — 로컬 + 플러그인 병합 스캔 로직

### Phase 3: .gitignore 확인 및 문서 정리

**확인 내용:**
- `.claude/agents/`가 `.gitignore`에 포함되어야 하는지 결정
  - 커스텀 에이전트는 프로젝트 특화이므로 **git 추적 대상** (`.gitignore`에 추가 불필요)
  - `.claude/skills/`는 이미 `.gitignore`에 포함되어 있음 → 로컬 스킬도 동일하게 무시됨
  - `.claude/workflows/`는 git 추적 대상 (팀 공유 가능)
- `.gitignore`에서 `.claude/skills/` 항목의 의도 재검토

### 권장 구현 순서

```
Phase 1 (Resolution 정의) → Phase 2 (기존 지점 수정) → Phase 3 (gitignore/문서)
```

## Verification Strategy

### Phase 1 검증
- SKILL.md에 `## Resource Resolution` 섹션이 존재하는지 확인
- `resolve-agent`, `resolve-skill`, `resolve-workflow` 3개 함수가 정의되어 있는지 확인

### Phase 2 검증
- `type: agent` 섹션에서 `resolve-agent` 참조 확인
- Cross-Cutting Rules에서 `resolve-skill` 참조 확인
- Available Workflows에서 병합 로직 확인

### Phase 3 검증
- `.gitignore` 상태 확인

### 통합 검증 (수동)
1. `.claude/agents/test.md` 생성 후 워크플로우에서 해당 에이전트 해석 가능한지 시나리오 확인
2. 로컬 리소스 없을 때 기존과 동일하게 동작하는지 확인
3. `.claude/workflows/custom.yaml` 생성 후 `/workflow` 목록에 `(local)` 표시되는지 확인

## Rollback Plan

- `skills/workflow/SKILL.md`의 변경을 git revert하면 완전 복원
- 프로젝트 로컬 디렉토리(`.claude/agents/` 등)는 삭제해도 기능 영향 없음
- Phase별 독립 revert 가능
