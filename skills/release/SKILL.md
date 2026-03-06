---
name: cch-release
description: Use when creating a release. Generates changelog from conventional commits, bumps version, creates git tag and GitHub Release.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Write
argument-hint: "[patch|minor|major] or [version]"
---

# Release Skill

Create releases with automated changelog, version bump, tag, and GitHub Release.

## Config Loading

Read release settings from:
!`echo "${CLAUDE_PROJECT_ROOT:-.}/.claude/project-config.json"`

## Input Resolution

입력을 다음 우선순위로 해석:

1. **정확한 인자** — `patch`, `minor`, `major`, `1.3.0` → 즉시 Phase 2로
2. **자연어** — 아래 NL 맵으로 버전 타입 매칭 후 실행
3. **인자 없음** — Phase 2에서 커밋 분석 후 자동 제안

### NL → Version Type Map

| 자연어 키워드 | 매핑 |
|--------------|------|
| 패치, 버그 수정 릴리즈, hotfix, 핫픽스 | `patch` |
| 마이너, 기능 추가 릴리즈, 피처 릴리즈 | `minor` |
| 메이저, 브레이킹, 대규모, 주요 | `major` |
| 버전 + 숫자 (예: "1.3.0으로") | 해당 버전 직접 사용 |

## Process

### Phase 0: Mode Detection

Read `release.monorepo` from project config:

- **`false`** (default) → Single-package mode. Proceed to Phase 1.
- **`true`** → Monorepo mode. See [Monorepo Release](#monorepo-release) section.

### Phase 1: Pre-flight Check

1. Verify on main branch: `git branch --show-current`
   - If not on main, ask: "Release는 main 브랜치에서 진행합니다. main으로 전환할까요?"
2. Verify working tree is clean: `git status --porcelain`
   - If dirty, STOP: "커밋되지 않은 변경사항이 있습니다. 먼저 정리해주세요."
3. Verify all tests pass
4. Get current version using `release.versionFile` from project config:
   - `"auto"` → detect in order: `package.json` → `pyproject.toml` → `version.txt` → latest git tag
   - Explicit path (e.g., `"package.json"`) → read version from that file only
   - If none found, ask user for current version and which file to use
   - Save detected file to avoid re-detection in later phases

### Phase 2: Version Determination

If argument provided (patch/minor/major):
- Apply semver bump automatically

If specific version provided (e.g., `1.3.0`):
- Use as-is

If no argument:
1. Analyze commits since last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
2. Suggest based on conventional commits:
   - Has `feat!:` or `BREAKING CHANGE` → suggest **major**
   - Has `feat:` → suggest **minor**
   - Only `fix:`, `chore:`, etc. → suggest **patch**
3. Present suggestion and let user confirm/override

Display: `Current: v{current} → Next: v{next}`

### Phase 3: Changelog Generation

1. Collect commits since last tag:
   ```bash
   git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --format="%H %s"
   ```

2. Parse conventional commit messages and group by type using `typeToSection` from config.
   CHANGELOG 및 릴리즈 노트는 한글로 작성:
   ```markdown
   ## [1.3.0] - 2026-03-06

   ### 새 기능
   - **auth**: OAuth2 로그인 플로우 추가 (#12)
   - **api**: 속도 제한 엔드포인트 추가 (#15)

   ### 버그 수정
   - **parser**: tokenizer에서 null 입력 처리 (#14)

   ### 리팩토링
   - **utils**: validation 헬퍼 추출 (#13)
   ```

   Type → 한글 섹션 매핑:
   | Type | 한글 섹션 |
   |------|----------|
   | feat | 새 기능 |
   | fix | 버그 수정 |
   | refactor | 리팩토링 |
   | perf | 성능 개선 |
   | docs | 문서 |
   | test | 테스트 |
   | chore | 기타 |
   | ci | CI/CD |

3. If `CHANGELOG.md` exists, prepend new section. If not, create it.

4. Non-conventional commits (no recognized type) → group under "Other Changes"

### Phase 4: Version Bump

Update version in the file determined in Phase 1:
- `package.json`: update `.version` field
- `pyproject.toml`: update `[project].version`
- `version.txt`: replace content

If `release.versionFile` was `"auto"` and multiple candidates exist, ask user which to use and suggest updating config to avoid this next time.

#### Plugin Metadata Sync

프로젝트가 Claude Code 플러그인인 경우 (`.claude-plugin/` 디렉토리 존재 시), 다음 파일의 `version` 필드도 함께 업데이트:

1. `.claude-plugin/plugin.json` → `"version"` 필드
2. `.claude-plugin/marketplace.json` → `plugins[].version` 필드

이 단계를 건너뛰면 플러그인 시스템이 이전 버전으로 인식하므로 **반드시** 동기화해야 한다.

### Phase 5: Commit, Tag, Push

```bash
git add CHANGELOG.md <version-file> .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "$(cat <<'EOF'
chore(release): v{version} 릴리즈

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
git tag -a v{version} -m "v{version} 릴리즈"
```

Ask user: "태그를 push하고 GitHub Release를 생성할까요?"

If yes:
```bash
git push origin main
git push origin v{version}
```

### Phase 6: GitHub Release

If `createGithubRelease` is true in config:

```bash
gh release create v{version} \
  --title "v{version} 릴리즈" \
  --notes-file <temp-release-notes>
```

Release notes = Phase 3의 changelog section content.

### Batch Release (multiple workflows)

When releasing changes from multiple merged PRs/branches:

1. All commits between last tag and HEAD are included automatically
2. Changelog groups them by type regardless of source branch
3. If workflow-state.json files exist for completed workflows, append a summary section:
   ```markdown
   ### Included Workflows
   - feature-dev: "user-auth" — OAuth2 login flow
   - bugfix: "token-expiry" — Fixed token refresh race condition
   ```

## Output

```
Release v{version} completed:
  - CHANGELOG.md updated
  - Version bumped in {file}
  - Tag v{version} created
  - GitHub Release: {url}
```

## Error Handling

| Error | Action |
|-------|--------|
| No conventional commits found | Warn, generate changelog from raw messages |
| gh CLI not installed | Skip GitHub Release, provide manual instructions |
| Push fails | Show error, suggest `git push` manually |
| No version file found | Ask user to specify |

---

## Monorepo Release

When `release.monorepo` is `true` in project config:

### Config

```json
{
  "release": {
    "monorepo": true,
    "packages": [
      {
        "name": "core",
        "path": "packages/core",
        "versionFile": "package.json"
      },
      {
        "name": "cli",
        "path": "packages/cli",
        "versionFile": "package.json"
      }
    ],
    "independentVersioning": true
  }
}
```

| Field | Description |
|-------|-------------|
| `packages` | List of releasable packages |
| `packages[].name` | Package identifier (used in tag: `core@1.2.0`) |
| `packages[].path` | Relative path from repo root |
| `packages[].versionFile` | Version file within the package directory |
| `independentVersioning` | `true`: each package has its own version. `false`: all share one version |

### Monorepo Process

1. **Scope detection**: Identify which packages have changes since last release
   ```bash
   git diff --name-only $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD
   ```
   Filter changed files by each package's `path`

2. **Package selection**: Present changed packages to user
   ```
   변경된 패키지:
     1. core (5 commits)
     2. cli (2 commits)

   릴리즈할 패키지를 선택하세요 (all / 번호):
   ```

3. **Per-package release**: For each selected package, run Phase 2-6 scoped to that package:
   - Changelog: only commits touching `packages/{name}/`
   - Version bump: `packages/{name}/{versionFile}`
   - Tag format: `{name}@{version}` (e.g., `core@1.3.0`)
   - GitHub Release title: `{name} v{version}`

4. **Shared dependencies**: If `independentVersioning` is `false`:
   - All selected packages get the same version
   - Single tag: `v{version}`
   - Single changelog entry

### Monorepo Commit Scope Convention

In monorepo, commit scope should include the package name:
```
feat(core/auth): add login flow
fix(cli/parser): handle empty input
```

The release skill uses the first segment of scope to attribute commits to packages.

## Rules

- NEVER release with failing tests
- NEVER force-push tags
- NEVER skip changelog generation
- Always let user confirm version before proceeding
- Always let user confirm before push/release creation
- In monorepo mode, NEVER release a package without running its tests specifically
