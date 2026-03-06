# Workflow Extension — Context & Decisions

## Background

CCH는 플러그인으로 설치되어 다양한 프로젝트에서 사용된다.
현재 워크플로우의 모든 리소스(에이전트, 스킬, YAML)가 플러그인 캐시 내부에서만 해석되어,
프로젝트별 커스텀 에이전트나 워크플로우를 추가할 수 없다.

## Key Decisions

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Fallback chain (로컬 → 플러그인) | 가장 단순하고 직관적. 파일 존재 여부로 자동 결정 | Config 기반 매핑: 설정 복잡도 증가 |
| Project-first (로컬 우선) | 프로젝트 특화 요구가 범용보다 구체적 | Plugin-first: 오버라이드 의도에 반함 |
| Zero-config | 디렉토리 규약으로 해결, 별도 설정 불필요 | project-config에 paths 추가: 불필요한 복잡도 |
| 전체 파일 오버라이드 | 마크다운 프롬프트에서 부분 상속은 비현실적 | extends 키워드: 파싱 복잡도 과대 |
| `.claude/workflows/` 별도 디렉토리 | 플러그인의 `skills/workflow/`와 혼동 방지 | `.claude/skills/workflow/`: 이미 `.gitignore`에 포함되어 추적 불가 |

## Technical Context

### 보존해야 할 API 계약

| 계약 | 상세 |
|------|------|
| 플러그인 리소스 해석 | 로컬 리소스가 없으면 기존과 100% 동일 |
| Agent dispatch 구조 | resolve 함수가 경로만 바꿀 뿐, dispatch 로직은 그대로 |
| Cross-cutting 주입 | resolve-skill로 경로만 변경, 주입 포맷은 동일 |
| workflow-state.json | 변경 없음 |
| YAML step 정의 | 변경 없음 — 에이전트/스킬 이름은 그대로, 해석 경로만 변경 |

### .gitignore 고려사항

현재 `.gitignore`:
```
.claude/skills/          ← 이미 무시됨
.claude/settings.local.json
.claude/workflow-state.json
.claude/knowledge-graph.json
```

확장 후 고려:
- `.claude/agents/` → **git 추적** (팀 공유 가능, 프로젝트 특화 에이전트)
- `.claude/skills/` → **이미 무시됨** — 로컬 스킬도 무시됨. 이것이 의도적인지 재검토 필요
- `.claude/workflows/` → **git 추적** (팀 공유 가능, 커스텀 워크플로우)

**`.claude/skills/` 문제**: 현재 `.claude/skills/`가 `.gitignore`에 있어서 로컬 cross-cutting 스킬을 git으로 추적할 수 없다. 두 가지 옵션:
1. `.claude/skills/`를 `.gitignore`에서 제거하고 개별 파일만 무시 → 기존 동작 변경 위험
2. 로컬 스킬을 `.claude/skills/` 대신 별도 경로(예: `.claude/local-skills/`)에 배치 → 경로 분리로 해결
3. 현 상태 유지 — 로컬 스킬은 git 추적 불필요한 것만 사용 (개인 설정)

→ **결정: 현 상태 유지**. 로컬 스킬은 `.claude/skills/`에 두되 git 추적은 프로젝트별 `.gitignore` 설정에 위임. CCH 자체 리포에서는 이미 무시됨.

## Open Questions

| # | 질문 | 영향 |
|---|------|------|
| 1 | 로컬 에이전트가 플러그인 에이전트의 I/O 계약을 깨뜨리면? | 워크플로우 실패. 문서화로 가이드하되 런타임 검증은 Out of Scope |
| 2 | 로컬 워크플로우 YAML에서 로컬 에이전트를 참조할 때 해석이 일관적인가? | 해석 함수가 동일하므로 문제 없음 |
