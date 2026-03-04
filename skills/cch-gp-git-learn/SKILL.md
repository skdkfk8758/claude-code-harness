---
name: cch-gp-git-learn
description: Git/GitHub onboarding with cloud metaphors. 5-stage learning.
user-invocable: true
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: [stage1|stage2|stage3|stage4|stage5|status]
---

# cch-gp-git-learn

Git/GitHub onboarding using cloud metaphors for intuitive learning. Progresses through 5 stages from basics to advanced topics with interactive quizzes and hands-on exercises.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/git-teacher`
4. If either command fails, report the error and stop.

### Execution
1. Parse the stage argument (default: `status` to show current progress).
2. **status**: Check `.claude/cch/git-learn-progress.json` for completed stages. Report current level and next stage.
3. **stage1** — Git Basics (Cloud Storage Metaphor):
   - Explain git init, add, commit using cloud storage analogies.
   - Interactive exercises: create a test repo, make commits.
   - Quiz via AskUserQuestion to verify understanding.
4. **stage2** — Branching (Parallel Universes Metaphor):
   - Explain branches, checkout, merge.
   - Hands-on: create branches, make changes, merge.
   - Quiz.
5. **stage3** — Remote Collaboration (Team Cloud Metaphor):
   - Explain remote, push, pull, fetch.
   - Practice with a local bare repo as remote.
   - Quiz.
6. **stage4** — GitHub Workflows (Social Coding Metaphor):
   - Explain PRs, issues, code review.
   - Walk through creating a PR.
   - Quiz.
7. **stage5** — Advanced (Time Travel Metaphor):
   - Explain rebase, cherry-pick, reflog.
   - Guided exercises with safety nets.
   - Final quiz.
8. Save progress to `.claude/cch/git-learn-progress.json` after each stage completion.
