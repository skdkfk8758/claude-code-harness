---
name: git-convention
description: Cross-cutting rule for commit message convention and timing. Injected into implementation agents to enforce consistent git practices.
user-invocable: false
allowed-tools: Read, Bash
---

# Git Convention (Cross-Cutting Rule)

This skill is NOT invoked directly. It is injected into agent prompts via `cross-cutting` in workflow YAML.

## Config Loading

Read project-level git settings from:
!`echo "${CLAUDE_PROJECT_ROOT:-.}/.claude/project-config.json"`

If the file does not exist, use defaults below.

## Commit Message Format

### Conventional Commits (default)

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Rules

1. **type** — must be one of the allowed types from project config:
   `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`, `perf`, `style`, `build`

2. **scope** — required (unless overridden in project config)
   - Use the module, component, or directory name most relevant to the change
   - For cross-module changes, use the highest-level common scope (e.g., `project`, `core`)
   - Examples: `feat(auth)`, `fix(api)`, `refactor(utils)`

3. **description** — imperative mood, lowercase, no period
   - Good: `add login endpoint`
   - Bad: `Added login endpoint.`

4. **body** — optional, explain WHY not WHAT (the diff shows WHAT)

5. **breaking changes** — use `!` after scope: `feat(api)!: change response format`

### Workflow-to-Type Mapping

| Workflow | Primary type | Common alternates |
|----------|-------------|-------------------|
| feature-dev | `feat` | `test`, `docs`, `refactor` |
| bugfix | `fix` | `test` |
| refactor | `refactor` | `test`, `chore` |
| quick-fix | `fix` or `feat` | `chore`, `docs` |

## Commit Command Template

When committing, agents MUST use this exact pattern:

```bash
# 1. Stage task-relevant files only
git add <changed-files>

# 2. Commit with pre-built message (DO NOT freestyle)
git commit -m "<type>(<scope>): <description>"
```

### Pre-Commit Validation (agent self-check)

Before running `git commit`, verify ALL of the following. If any fails, fix before committing:

1. Tests pass: `npm test` / `pytest` / equivalent
2. Message format: `<type>(<scope>): <description>`
3. Type is valid (from project config `allowedTypes`)
4. Scope is specific — NOT generic (`misc`, `stuff`, `various`)
5. Description: imperative, lowercase, no period, < 72 chars
6. Only task-relevant files staged: `git diff --cached --name-only`

If unsure about scope, derive from the primary directory of changed files:
- `src/auth/login.ts` changed → scope = `auth`
- `src/api/routes.ts` + `src/api/middleware.ts` → scope = `api`
- Multiple unrelated directories → use the highest common parent or the most significant module

### Commit Message Examples (copy these patterns)

**Single-package:**
```
feat(auth): add OAuth2 login flow
fix(parser): handle null input in tokenizer
refactor(utils): extract validation helpers
test(auth): add login edge case coverage
chore(deps): bump axios to 1.6.0
docs(api): update endpoint documentation
feat(api)!: change response format
```

**Monorepo** (when `release.monorepo` is `true` in project config):
```
feat(core/auth): add OAuth2 login flow
fix(cli/parser): handle empty input
refactor(shared/utils): extract validation helpers
```
In monorepo mode, scope format is `{package}/{module}`. The first segment identifies the package for release attribution.

## Commit Timing

### Per-Task Commit (default)

After completing each task:

1. Run tests to confirm passing state
2. Stage only the files changed for that task: `git add <changed-files>`
3. Build commit message using the template above
4. Commit
5. Do NOT batch multiple tasks into one commit
6. Do NOT commit partial/broken state

## Anti-Patterns

| Anti-Pattern | Why Bad | Instead |
|-------------|---------|---------|
| `fix: fix` | No information | `fix(parser): handle null input in tokenizer` |
| `WIP`, `temp`, `asdf` | Pollutes history | Commit only when task is complete |
| `feat: implement tasks 1-5` | Too broad | One commit per task |
| `chore: update` | Vague | `chore(deps): bump axios to 1.6.0` |
| Committing `.env`, logs | Security/noise | Check `.gitignore` before staging |

## Domain Context

**방법론 근거**: Conventional Commits는 Angular 커밋 컨벤션에서 파생되어 [conventionalcommits.org](https://www.conventionalcommits.org/)에서 표준화된 스펙이다. 구조화된 커밋 메시지는 자동 버전 관리(Semantic Versioning), 체인지로그 생성, 코드 리뷰 효율화를 가능하게 한다.

**핵심 원리**: 커밋 메시지는 "미래의 나"와 "동료"를 위한 문서다. type은 변경의 성격을, scope은 영향 범위를, description은 의도를 전달한다.

### Further Reading
- [Conventional Commits Spec v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- Chris Beams, [How to Write a Git Commit Message](https://cbea.ms/git-commit/) — 7가지 커밋 메시지 규칙
- Semantic Versioning, [semver.org](https://semver.org/) — type과 버전 번호의 관계

## Enforcement Verification

When this skill is used with `enforcement: enforce` in a workflow step, the orchestrator verifies compliance by checking commits made during the step. The following checks are performed automatically:

### Pre-Step Setup
Record the commit hash before dispatching the agent: `git rev-parse HEAD`

### Evidence Required
1. **Commit format**: Each commit message matches `<type>(<scope>): <description>`
2. **Valid type**: Type is in the allowed list from project config
3. **Scope present**: If `scopeRequired` is true in project config
4. **Granularity**: Number of commits roughly matches number of tasks completed

### Verification Command
```bash
git log --oneline {pre-step-hash}..HEAD
```

### Pass Criteria
- All commits match conventional format
- Scope is specific (not generic like `misc`, `stuff`)

### Failure Response
Convention violations are reported as warnings to the user (NOT automatically fixed — rebase/amend is risky):
```
[workflow] git-convention 위반 감지:
  - {commit-hash}: "{message}" — {violation-reason}
수동으로 수정하시겠습니까? (무시하고 계속 진행할 수도 있습니다)
```
User chooses: fix manually / ignore and continue.
Result recorded in state as `"git-convention": "warning_issued"` or `"passed"`.
