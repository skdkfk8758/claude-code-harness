# CCH 전체 프로젝트 정리 — 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 스킬 래퍼 23개 정리, 코드 결함 6건 수정, 파일 위생 정리, git 동기화

**Architecture:** marketplace repo(별도 git)가 스킬 canonical. repo는 네이티브 스킬 18개 원본. marketplace 변경 후 commit, repo 변경은 별도 commit.

**Tech Stack:** bash, git, gh CLI

**Marketplace:** `/Users/carpdm/.claude/plugins/marketplaces/claude-code-harness-marketplace/`
**Repo:** `/Users/carpdm/Workspace/Github/claude-code-harness/`

---

## Phase 1: Git 위생 (Repo)

### Task 1: Untracked 파일 커밋 + push

**Files:**
- Add: `docs/plans/2026-03-04-skill-dedup-design.md`
- Add: `docs/plans/2026-03-04-skill-dedup-impl.md`
- Add: `docs/plans/2026-03-04-generic-plugin-enhancement-design.md`
- Add: `docs/plans/2026-03-04-generic-plugin-enhancement-impl.md`
- Add: `docs/plans/2026-03-04-todo-removal-design.md`
- Add: `docs/plans/2026-03-04-todo-removal-impl.md`
- Add: `docs/diagrams/cch-skill-ecosystem.excalidraw`
- Modify: `docs/diagrams/cch-workflows.md`
- Modify: `.beads/issues.jsonl`

**Step 1: 파일 스테이징**
```bash
cd /Users/carpdm/Workspace/Github/claude-code-harness
git add docs/plans/2026-03-04-skill-dedup-design.md \
        docs/plans/2026-03-04-skill-dedup-impl.md \
        docs/plans/2026-03-04-generic-plugin-enhancement-design.md \
        docs/plans/2026-03-04-generic-plugin-enhancement-impl.md \
        docs/plans/2026-03-04-todo-removal-design.md \
        docs/plans/2026-03-04-todo-removal-impl.md \
        docs/diagrams/cch-skill-ecosystem.excalidraw \
        docs/diagrams/cch-workflows.md \
        .beads/issues.jsonl
```

**Step 2: 커밋**
```bash
git commit -m "docs: add plan documents and diagrams from current session"
```

**Step 3: Push**
```bash
git push origin feat/initial-codebase-and-beads-migration
```

**Step 4: 검증**
Run: `git status --short`
Expected: 빈 출력 (clean working tree)

**의존:** 없음

---

## Phase 2: 코드 결함 수정 (Marketplace)

### Task 2: cch-plan notepad 참조 제거

**Files:**
- Modify: `marketplace/skills/cch-plan/SKILL.md` (lines 24-26)

**Step 1: notepad 섹션 제거**
`cch-plan/SKILL.md`의 Guidelines > Notepad Wisdom 섹션 전체를 삭제:
```
AS-IS (lines 22-26):
### Notepad Wisdom
- 작업 시작 전 `notepad_read`로 이전 세션의 컨텍스트를 확인한다.
- 중요한 설계 결정이나 발견사항은 `notepad_write_working`으로 기록한다.
- 반복적으로 사용되는 패턴이나 규칙은 `notepad_write_manual`로 영구 저장한다.

TO-BE: (삭제)
```

**Step 2: 검증**
Run: `grep -n "notepad" marketplace/skills/cch-plan/SKILL.md`
Expected: 매칭 없음

**Step 3: 커밋** (marketplace repo)
```bash
git commit -am "fix(skills): remove non-existent notepad_* references from cch-plan"
```

**의존:** 없음

---

### Task 3: cch-commit oh-my-claudecode 참조 수정

**Files:**
- Modify: `marketplace/skills/cch-commit/SKILL.md` (line 121)

**Step 1: subagent_type 수정**
```
AS-IS (line 121):
   - subagent_type: `oh-my-claudecode:code-simplifier`

TO-BE:
   - subagent_type: `general-purpose`
```

**Step 2: 검증**
Run: `grep "oh-my-claudecode" marketplace/skills/cch-commit/SKILL.md`
Expected: 매칭 없음

**Step 3: 커밋** (marketplace repo)
```bash
git commit -am "fix(skills): replace invalid oh-my-claudecode subagent type in cch-commit"
```

**의존:** 없음

---

### Task 4: cch-pinchtab oh-my-claudecode 참조 수정

**Files:**
- Modify: `marketplace/skills/cch-pinchtab/SKILL.md` (lines 98, 115, 219, 286)

**Step 1: 모든 oh-my-claudecode 참조를 general-purpose로 교체**
4개 위치:
- L98: `oh-my-claudecode:qa-tester` → `general-purpose`
- L115: `oh-my-claudecode:scientist` → `general-purpose`
- L219: `oh-my-claudecode:deep-executor` → `general-purpose`
- L286: `oh-my-claudecode:scientist` → `general-purpose`

**Step 2: 검증**
Run: `grep "oh-my-claudecode" marketplace/skills/cch-pinchtab/SKILL.md`
Expected: 매칭 없음

**Step 3: 커밋** (marketplace repo)
```bash
git commit -am "fix(skills): replace invalid oh-my-claudecode subagent types in cch-pinchtab"
```

**의존:** 없음

---

## Phase 3: cch-sp-* 전체 삭제 (Marketplace, 8개)

### Task 5: cch-sp-* 삭제 전 참조 수집

**Step 1: 전체 교차 참조 스캔**
```bash
cd /Users/carpdm/.claude/plugins/marketplaces/claude-code-harness-marketplace
grep -r "cch-sp-debug\|cch-sp-tdd\|cch-sp-execute-plan\|cch-sp-subagent-dev\|cch-sp-finish-branch\|cch-sp-git-worktree\|cch-sp-parallel-agents\|cch-sp-receive-review" skills/ --include="*.md" -l
```

Expected 결과 (이전 분석 기반):
- `cch-sp-debug/SKILL.md` — self + references cch-sp-tdd, cch-verify
- `cch-sp-tdd/SKILL.md` — self
- `cch-sp-execute-plan/SKILL.md` — self + references cch-sp-git-worktree, cch-sp-finish-branch
- `cch-sp-subagent-dev/SKILL.md` — self + references cch-sp-git-worktree, cch-sp-finish-branch
- `cch-sp-finish-branch/SKILL.md` — self + references cch-sp-execute-plan, cch-sp-subagent-dev, cch-sp-git-worktree
- `cch-sp-git-worktree/SKILL.md` — self + references cch-sp-finish-branch
- `cch-sp-parallel-agents/SKILL.md` — self + references cch-sp-debug
- `cch-sp-receive-review/SKILL.md` — self + references cch-review

**Step 2: 비-sp 스킬의 참조 확인**
이전에 cch-sp-debug의 cch-verify 참조는 이미 수정됨. cch-sp-receive-review의 cch-review 참조도 수정됨.
나머지 참조는 모두 cch-sp-* 간 상호 참조 → 함께 삭제되므로 dangling ref 없음.

**의존:** 없음

---

### Task 6: cch-sp-* 8개 일괄 삭제

**Files:**
- Delete: `marketplace/skills/cch-sp-debug/`
- Delete: `marketplace/skills/cch-sp-tdd/`
- Delete: `marketplace/skills/cch-sp-execute-plan/`
- Delete: `marketplace/skills/cch-sp-subagent-dev/`
- Delete: `marketplace/skills/cch-sp-finish-branch/`
- Delete: `marketplace/skills/cch-sp-git-worktree/`
- Delete: `marketplace/skills/cch-sp-parallel-agents/`
- Delete: `marketplace/skills/cch-sp-receive-review/`

**Step 1: 삭제**
```bash
cd /Users/carpdm/.claude/plugins/marketplaces/claude-code-harness-marketplace
rm -rf skills/cch-sp-debug skills/cch-sp-tdd skills/cch-sp-execute-plan \
       skills/cch-sp-subagent-dev skills/cch-sp-finish-branch skills/cch-sp-git-worktree \
       skills/cch-sp-parallel-agents skills/cch-sp-receive-review
```

**Step 2: 검증**
Run: `ls skills/ | wc -l`
Expected: 39 (47 - 8)

Run: `ls skills/ | grep "cch-sp-"`
Expected: 매칭 없음

**Step 3: dangling reference 검사**
```bash
grep -r "cch-sp-" skills/ --include="*.md"
```
Expected: 매칭 없음

**Step 4: 커밋** (marketplace repo)
```bash
git add -A skills/cch-sp-*
git commit -m "refactor(skills): remove all cch-sp-* wrappers (broken prerequisites, absorbed into native skills)"
```

**의존:** Task 5

---

## Phase 4: cch-gp-* 확실 중복 삭제 (Marketplace, 3개)

### Task 7: cch-gp-prd, cch-gp-pumasi, cch-gp-team 삭제

**Files:**
- Delete: `marketplace/skills/cch-gp-prd/`
- Delete: `marketplace/skills/cch-gp-pumasi/`
- Delete: `marketplace/skills/cch-gp-team/`

**Step 1: 참조 확인**
```bash
grep -r "cch-gp-prd\|cch-gp-pumasi\|cch-gp-team" skills/ --include="*.md" -l
```
Expected: 자기 자신만 매칭 (이전 분석에서 모두 orphan 확인됨)

**Step 2: 삭제**
```bash
rm -rf skills/cch-gp-prd skills/cch-gp-pumasi skills/cch-gp-team
```

**Step 3: 검증**
Run: `ls skills/ | wc -l`
Expected: 36 (39 - 3)

**Step 4: 커밋** (marketplace repo)
```bash
git add -A skills/cch-gp-prd skills/cch-gp-pumasi skills/cch-gp-team
git commit -m "refactor(skills): remove duplicate gptaku wrappers (prd→cch-plan, pumasi/team→cch-team)"
```

**의존:** Task 6

---

## Phase 5: cch-rf-* 확실 중복 삭제 (Marketplace, 4개)

### Task 8: cch-rf-doctor, cch-rf-hive, cch-rf-sparc, cch-rf-swarm 삭제

**Files:**
- Delete: `marketplace/skills/cch-rf-doctor/`
- Delete: `marketplace/skills/cch-rf-hive/`
- Delete: `marketplace/skills/cch-rf-sparc/`
- Delete: `marketplace/skills/cch-rf-swarm/`

**Step 1: 참조 확인**
```bash
grep -r "cch-rf-doctor\|cch-rf-hive\|cch-rf-sparc\|cch-rf-swarm" skills/ --include="*.md" -l
```
Expected: 자기 자신만 매칭

**Step 2: 삭제**
```bash
rm -rf skills/cch-rf-doctor skills/cch-rf-hive skills/cch-rf-sparc skills/cch-rf-swarm
```

**Step 3: 검증**
Run: `ls skills/ | wc -l`
Expected: 32 (36 - 4)

Run: `ls skills/ | grep "cch-rf-"`
Expected: cch-rf-memory, cch-rf-security만 남음 (2개)

**Step 4: 커밋** (marketplace repo)
```bash
git add -A skills/cch-rf-doctor skills/cch-rf-hive skills/cch-rf-sparc skills/cch-rf-swarm
git commit -m "refactor(skills): remove redundant ruflo wrappers (doctor→status, hive→full-pipeline, sparc→plan+team, swarm→team)"
```

**의존:** Task 7

---

## Phase 6: 파일 정리 (Repo + Marketplace)

### Task 9: Repo 파일 정리

**Files:**
- Delete: `docs/plans/2026-03-04-general.md` (빈 템플릿)
- Delete: `.beads/interactions.jsonl` (0바이트, git tracked)
- Modify: `scripts/test.sh` (stale test layers 제거)

**Step 1: 빈 파일 삭제**
```bash
cd /Users/carpdm/Workspace/Github/claude-code-harness
rm docs/plans/2026-03-04-general.md
rm .beads/interactions.jsonl
```

**Step 2: scripts/test.sh stale 레이어 정리**

Line 4:
```
AS-IS: # Layers: contract, agent, skill, workflow, resilience, all
TO-BE: # Layers: contract, skill, workflow, resilience, branch, cch_init, beads, all
```

Line 147:
```
AS-IS: for l in contract agent skill workflow resilience branch source_types vendor_integration cch_init arch_tdd beads; do
TO-BE: for l in contract skill workflow resilience branch cch_init beads; do
```

**Step 3: 검증**
Run: `bash scripts/test.sh all 2>&1 | tail -5`
Expected: 테스트 실행 성공 (SKIP 없음)

**Step 4: 커밋** (repo)
```bash
git add docs/plans/2026-03-04-general.md .beads/interactions.jsonl scripts/test.sh
git commit -m "chore: remove empty files, clean stale test layer references"
```

**의존:** Task 1

---

## Phase 7: Marketplace PR + 최종 검증

### Task 10: Marketplace 전체 dangling reference 검사 + PR

**Step 1: 최종 dangling reference 전체 검사**
```bash
cd /Users/carpdm/.claude/plugins/marketplaces/claude-code-harness-marketplace
grep -rE "cch-sp-|cch-gp-(prd|pumasi|team)|cch-rf-(doctor|hive|sparc|swarm)|oh-my-claudecode|notepad_|TodoWrite" skills/ --include="*.md"
```
Expected: 매칭 없음

**Step 2: 최종 스킬 수 확인**
Run: `ls skills/ | wc -l`
Expected: 32

**Step 3: 스킬 목록 출력**
```bash
ls skills/
```
Expected 32개:
```
cch-arch-guide    cch-gp-docs       cch-gp-research      cch-init          cch-lsp        cch-plan     cch-pt-report   cch-review     cch-status  cch-todo
cch-commit        cch-gp-git-learn  cch-gp-skill-builder  cch-init-docs     cch-mode       cch-pr       cch-pt-test     cch-rf-memory  cch-sync    cch-verify
cch-excalidraw    cch-gp-mentor     cch-hud               cch-init-scaffold cch-pinchtab   cch-pt-infra cch-setup       cch-rf-security cch-team
cch-full-pipeline cch-gp-playground                        cch-init-scan
```

**Step 4: PR 생성** (marketplace repo)
```bash
git push -u origin feat/full-cleanup
gh pr create --title "refactor: comprehensive skill cleanup and code defect fixes" --base main
```

**의존:** Task 8, Task 9

---

## 요약

| Phase | Task | 대상 | 변경 |
|-------|------|------|------|
| 1 | 1 | Repo | git 위생: 7 untracked 커밋 + push |
| 2 | 2 | Marketplace | cch-plan notepad 참조 제거 |
| 2 | 3 | Marketplace | cch-commit oh-my-claudecode 수정 |
| 2 | 4 | Marketplace | cch-pinchtab oh-my-claudecode 수정 (4곳) |
| 3 | 5 | Marketplace | cch-sp-* 교차 참조 스캔 |
| 3 | 6 | Marketplace | cch-sp-* 8개 삭제 (47→39) |
| 4 | 7 | Marketplace | cch-gp-prd/pumasi/team 삭제 (39→36) |
| 5 | 8 | Marketplace | cch-rf-doctor/hive/sparc/swarm 삭제 (36→32) |
| 6 | 9 | Repo | 빈 파일 삭제 + test.sh 정리 |
| 7 | 10 | Marketplace | 최종 검증 + PR |

**최종 결과:** Marketplace **47 → 32** (15개 삭제), 코드 결함 6건 수정, 파일 정리 3건
