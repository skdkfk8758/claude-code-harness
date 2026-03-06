# Git Infrastructure Layer Design

## Decision Summary

| # | Item | Decision |
|---|------|----------|
| 1 | Usage scenario | solo / team-local / team-wide |
| 2 | Branch creation | Manual OK, auto optional |
| 3 | Commit convention | Conventional Commits, scope required |
| 4 | PR body | Summary + links from workflow-state |
| 5 | Commit timing | Per task completion |
| 6 | Release | Separate skill |
| 7 | Branch naming | Workflow-type fixed prefix |
| 8 | Release scope | changelog + version bump + tag + GitHub Release |
| 9 | Release unit | Single workflow or batched |
| 10 | Settings | `.claude/project-config.json` |
| 11 | quick-fix branch | Required |

## Architecture

```
[Workflow Layer]       feature-dev / bugfix / refactor / quick-fix
       | calls
[Infrastructure]       branch-check (startup), git-convention (cross-cutting), finishing-branch (PR), release (skill)
       | reads
[Project Settings]     .claude/project-config.json
```

## Components

### 1. `.claude/project-config.json`
Project-level settings. All infrastructure skills read from this file.

### 2. `git-convention` (cross-cutting skill)
Injected into implementation agent prompts. Enforces commit message format and timing.

### 3. Workflow YAML updates
- Branch validation added to workflow orchestrator startup
- `git-convention` added to cross-cutting list of implementation steps

### 4. `finishing-branch` enhancement
- PR body: extract summary/decisions from workflow-state.json + link to plan docs

### 5. `release` skill (new)
- changelog generation from conventional commits
- semver bump (major/minor/patch)
- git tag + GitHub Release creation
