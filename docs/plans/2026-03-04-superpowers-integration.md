# Superpowers Integration Analysis

**Date:** 2026-03-04
**Source:** `github.com/obra/superpowers` (cloned at `.claude/cch/sources/superpowers/`)
**Purpose:** Inventory all superpowers skills, create CCH wrappers, and recommend workflow integration.

---

## 1. Superpowers Skills Inventory

Superpowers provides 12 skills across three categories: workflow orchestration, quality enforcement, and git workflow.

### Workflow Orchestration

| Superpowers Skill | CCH Wrapper | Purpose |
|---|---|---|
| `brainstorming` | `cch-sp-brainstorm` | Design-first dialogue before any code |
| `writing-plans` | `cch-sp-write-plan` | Produces bite-sized TDD implementation plans |
| `executing-plans` | `cch-sp-execute-plan` | Batch plan execution with checkpoint reviews |
| `subagent-driven-development` | `cch-sp-subagent-dev` | Per-task subagents with two-stage review |
| `dispatching-parallel-agents` | `cch-sp-parallel-agents` | Concurrent agents for independent problems |

### Quality Enforcement

| Superpowers Skill | CCH Wrapper | Purpose |
|---|---|---|
| `test-driven-development` | `cch-sp-tdd` | Red-green-refactor discipline |
| `systematic-debugging` | `cch-sp-debug` | Four-phase root-cause-first debugging |
| `verification-before-completion` | `cch-sp-verify` | Evidence before any completion claim |
| `requesting-code-review` | `cch-sp-code-review` | Dispatch code-reviewer subagent |
| `receiving-code-review` | `cch-sp-receive-review` | Technical evaluation of incoming review |

### Git Workflow

| Superpowers Skill | CCH Wrapper | Purpose |
|---|---|---|
| `using-git-worktrees` | `cch-sp-git-worktree` | Isolated workspace creation with safety checks |
| `finishing-a-development-branch` | `cch-sp-finish-branch` | Test-verify → 4-option completion flow |

### Meta / Not Wrapped

| Superpowers Skill | Status | Reason |
|---|---|---|
| `using-superpowers` | Not wrapped | Meta-skill for superpowers-native environments only |
| `writing-skills` | Not wrapped | Used for authoring skills, not for CCH users |

---

## 2. Skill-by-Skill Analysis

### cch-sp-brainstorm
- **Purpose:** Mandatory design dialogue before any implementation. Asks one question at a time, proposes 2-3 approaches, gets user approval, writes design doc.
- **Ideal use case:** Starting any feature, component, or behavioral change. Especially valuable for ambiguous or cross-cutting changes.
- **Hard gate:** Zero code until user approves design. No exceptions.
- **Output:** `docs/plans/YYYY-MM-DD-<topic>-design.md` + hand-off to `cch-sp-write-plan`.
- **CCH integration:** Entry point to the full plan/code workflow. Should be invoked at the start of every non-trivial feature request.

### cch-sp-write-plan
- **Purpose:** Converts an approved design into a comprehensive implementation plan with exact file paths, failing test code, and commit commands.
- **Ideal use case:** After `cch-sp-brainstorm` approves a design. Also useful for complex bug fixes or refactors that need a structured approach.
- **Output:** `docs/plans/YYYY-MM-DD-<feature>.md` with TDD task structure.
- **CCH integration:** Plan-bridge (`scripts/plan-bridge.mjs`) auto-detects documents in `docs/plans/` — plans created here are immediately visible to the bridge pipeline.

### cch-sp-execute-plan
- **Purpose:** Executes a plan in a separate session with batches of 3 tasks and human review checkpoints between batches.
- **Ideal use case:** When the user wants to stay in the review loop between task batches, or for large plans where context isolation between sessions is desirable.
- **CCH integration:** Natural fit for the `code` mode. Requires `cch-sp-git-worktree` first. Ends with `cch-sp-finish-branch`.

### cch-sp-subagent-dev
- **Purpose:** Executes a plan in the current session. Fresh subagent per task, spec compliance review, then code quality review after each task.
- **Ideal use case:** When you want fast iteration without session handoffs. Best for plans with 3-8 independent tasks.
- **Quality gates:** Two-stage review catches spec drift and code quality issues before they compound.
- **CCH integration:** Strongest quality-per-task guarantee of any execution skill. Pairs well with `cch-gp-prd` → plan-bridge → `cch-sp-subagent-dev` pipeline.

### cch-sp-debug
- **Purpose:** Enforces four-phase debugging (root cause → pattern analysis → hypothesis → implementation). No fixes without root cause first.
- **Ideal use case:** Any bug, test failure, or unexpected behavior. Especially important under time pressure (when guessing is most tempting).
- **Iron law:** If 3+ fixes have failed, STOP and question the architecture.
- **CCH integration:** Should be invoked any time the user reports a bug or test failure. Pairs with `cch-sp-tdd` for the failing test and `cch-sp-verify` for the fix verification.

### cch-sp-tdd
- **Purpose:** Red-green-refactor discipline. No production code before a failing test. Delete code written before tests — no "keep as reference."
- **Ideal use case:** Every new feature, bugfix, and refactor. No exceptions.
- **CCH integration:** Foundation skill used inside `cch-sp-subagent-dev` (subagents follow TDD per task) and `cch-sp-debug` (Phase 4 implementation).

### cch-sp-verify
- **Purpose:** Run verification commands and show output before any success claim, commit, or PR. "Should work" is not evidence.
- **Ideal use case:** Before every completion claim, commit, and PR creation.
- **CCH integration:** Natural complement to `cch-commit` and `cch-pr`. Should be invoked before those skills to ensure claims are backed by evidence.

### cch-sp-git-worktree
- **Purpose:** Create isolated git worktrees with directory priority logic, gitignore safety verification, and clean baseline test confirmation.
- **Ideal use case:** Before executing any implementation plan. Prevents committing worktree contents accidentally.
- **CCH integration:** Required prerequisite for `cch-sp-subagent-dev` and `cch-sp-execute-plan`. Pairs with `cch-sp-finish-branch` for cleanup.

### cch-sp-finish-branch
- **Purpose:** Verify tests pass → present 4 structured options (merge/PR/keep/discard) → execute choice → clean worktree.
- **Ideal use case:** After all plan tasks are complete and verified.
- **CCH integration:** Terminal step in every plan execution workflow. Integrates naturally with `cch-pr` for Option 2 (push + PR).

### cch-sp-code-review
- **Purpose:** Dispatch a code-reviewer subagent using the superpowers template. Mandatory after each task in subagent-driven development.
- **Ideal use case:** After each implementation task, after major features, and before merge to main.
- **CCH integration:** Used internally by `cch-sp-subagent-dev`. Also useful standalone after ad-hoc implementation sessions.

### cch-sp-receive-review
- **Purpose:** Technical evaluation of incoming review feedback. Forbids performative agreement. Verify before implement.
- **Ideal use case:** When receiving PR review comments or feedback from agents/humans.
- **CCH integration:** Companion to `cch-sp-code-review`. Also pairs with `cch-pr` — after a PR is created, use this to handle review comments.

### cch-sp-parallel-agents
- **Purpose:** Dispatch one agent per independent problem domain and run them concurrently. For 2+ unrelated failures or tasks.
- **Ideal use case:** 3+ test files failing with different root causes; multiple independent subsystems broken; parallel research tasks.
- **CCH integration:** Natural fit for `cch-team` workflows. Complements `cch-rf-swarm` (which uses ruflo topology) with a simpler, direct parallel dispatch approach.

---

## 3. Mode Assignments

### plan mode
Skills that produce designs and plans — high deliberation, no implementation.

| Skill | Rationale |
|---|---|
| `cch-sp-brainstorm` | Core entry point for plan mode: design-first, no code |
| `cch-sp-write-plan` | Produces the implementation plan consumed by code mode |

### code mode
Skills that execute plans and implement features.

| Skill | Rationale |
|---|---|
| `cch-sp-execute-plan` | Batch execution with human checkpoints — core code mode skill |
| `cch-sp-subagent-dev` | Same-session execution with automatic review — premium code mode |
| `cch-sp-git-worktree` | Required prerequisite for all execution |
| `cch-sp-finish-branch` | Required completion step for all execution |
| `cch-sp-tdd` | Foundation discipline for all implementation |
| `cch-sp-verify` | Gate before every completion claim |

### on-demand (any mode)
Utility skills invoked on-demand during any mode.

| Skill | Rationale |
|---|---|
| `cch-sp-debug` | Invoked on any bug/failure regardless of current mode |
| `cch-sp-code-review` | On-demand review dispatching |
| `cch-sp-receive-review` | On-demand review evaluation |
| `cch-sp-parallel-agents` | On-demand parallel dispatch for independent tasks |
| `cch-sp-subagent-dev` | Per-task subagent orchestration with quality gates |

---

## 4. Recommended Profile Updates

> **Note:** Do not modify `profiles/` files directly — these are recommendations only.

### profiles/plan.md (or equivalent)
Add to available skills:
```
- cch-sp-brainstorm  # invoke before entering code mode
- cch-sp-write-plan  # produces plan consumed by code mode
```

### profiles/code.md (or equivalent)
Add to available skills:
```
- cch-sp-git-worktree    # required before execution
- cch-sp-execute-plan    # parallel session execution
- cch-sp-subagent-dev    # same-session execution (preferred)
- cch-sp-finish-branch   # required after execution
- cch-sp-tdd             # required during implementation
- cch-sp-verify          # required before completion claims
- cch-sp-code-review     # after each task
- cch-sp-receive-review  # when review feedback arrives
```

### profiles/tool.md or profiles/default.md
Add to available skills:
```
- cch-sp-debug            # any bug or failure
- cch-sp-parallel-agents  # independent parallel tasks
```

---

## 5. Workflow Examples

### Full Feature Pipeline (plan → code → PR)

```
User: "Add rate limiting to the API"

1. cch-sp-brainstorm        → design dialogue → approved design doc
2. cch-sp-write-plan        → docs/plans/2026-03-04-rate-limiting.md
3. cch-sp-git-worktree      → isolated workspace on feature/rate-limiting
4. cch-sp-subagent-dev      → executes plan, per-task review loops
   └─ cch-sp-tdd            →   (used by each subagent)
   └─ cch-sp-code-review    →   (after each task)
5. cch-sp-verify            → confirm all tests pass
6. cch-sp-finish-branch     → option 2: push + PR
7. cch-pr                   → PR created (or finish-branch handles it)
```

### Bug Fix Pipeline

```
User: "Tests failing after the cache refactor"

1. cch-sp-debug             → four-phase root cause investigation
   └─ cch-sp-parallel-agents →  (if 3+ independent failures found)
2. cch-sp-tdd               → write failing test reproducing the bug
3. [implement fix]
4. cch-sp-verify            → confirm tests pass, no regressions
5. cch-commit               → commit the fix
```

### Parallel Multi-Subsystem Investigation

```
User: "6 test failures across 3 files after the refactor"

1. cch-sp-parallel-agents
   ├─ Agent 1: fix auth.test.ts (timing issues)
   ├─ Agent 2: fix cache.test.ts (event structure)
   └─ Agent 3: fix api.test.ts (async ordering)
2. Review all summaries for conflicts
3. Run full test suite
4. cch-sp-verify            → confirm clean
```

### Plan-Bridge Integration

```
1. cch-sp-brainstorm        → design approved
2. cch-sp-write-plan        → docs/plans/2026-03-04-feature.md
   [plan-bridge.mjs auto-detects new file]
3. plan-bridge generates execution context
4. cch-sp-subagent-dev      → executes the plan
```

### Chaining with Existing CCH Skills

```
# Research → Design → Implement
cch-gp-research  →  cch-sp-brainstorm  →  cch-sp-write-plan  →  cch-sp-subagent-dev

# PRD → Plan → Execute
cch-gp-prd  →  cch-sp-write-plan  →  cch-sp-git-worktree  →  cch-sp-execute-plan  →  cch-sp-finish-branch  →  cch-pr

# SPARC-style with superpowers quality gates
cch-rf-sparc  +  cch-sp-tdd  +  cch-sp-verify  (inject quality gates into each SPARC phase)
```

---

## 6. Key Observations

### What Superpowers Adds That CCH Lacked
1. **Design gate before code** (`cch-sp-brainstorm`) — CCH had no enforced design-first step.
2. **Two-stage task review** (`cch-sp-subagent-dev`) — spec compliance then code quality, not just quality.
3. **Systematic debugging discipline** (`cch-sp-debug`) — four-phase enforcement with "3+ fixes = architectural problem" heuristic.
4. **Worktree safety** (`cch-sp-git-worktree`) — gitignore verification before creation.
5. **Structured branch completion** (`cch-sp-finish-branch`) — exactly 4 options, typed confirmation for discard.

### Overlap with Existing CCH Skills
| Superpowers | Existing CCH | Notes |
|---|---|---|
| `cch-sp-parallel-agents` | `cch-rf-swarm`, `cch-team` | Superpowers version is simpler (no ruflo), existing versions have topology options |
| `cch-sp-subagent-dev` | `cch-rf-sparc` | SPARC has 5 fixed phases; subagent-dev is flexible per-task |
| `cch-sp-finish-branch` | `cch-pr` | Finish-branch handles the full decision tree; cch-pr is PR-only |
| `cch-sp-verify` | implicit in `cch-commit` | Verify is more explicit and enforceable |

## TODO

### High Priority (즉시 적용)
- [ ] `cch-sp-brainstorm` CCH 워크플로우 진입점으로 통합 — 비사소한 기능 요청 시 자동 호출
- [ ] `cch-sp-debug` 버그/테스트 실패 시 자동 호출 연동
- [ ] `cch-sp-tdd` 구현 시 red-green-refactor 강제
- [ ] `cch-sp-verify` `cch-commit`, `cch-pr` 전 필수 호출로 설정

### Medium Priority (워크플로우 완성)
- [ ] `cch-sp-write-plan` plan-bridge 파이프라인에 통합
- [ ] `cch-sp-subagent-dev` per-task 서브에이전트 + 2단계 리뷰 실행 경로 구성
- [ ] `cch-sp-git-worktree` 실행 계획 전 필수 전제조건으로 연결

### Lower Priority (기존 CCH 스킬과 중복)
- [ ] `cch-sp-parallel-agents` cch-team/cch-rf-swarm과 역할 정리
- [ ] `cch-sp-finish-branch` cch-pr과 통합 또는 역할 분리
- [ ] `cch-sp-execute-plan` subagent-dev와 선택 기준 문서화
- [ ] `cch-sp-code-review` / `cch-sp-receive-review` 리뷰 품질 게이트 구성

### 프로파일 업데이트
- [ ] `profiles/plan.json`에 `cch-sp-brainstorm`, `cch-sp-write-plan` 추가
- [ ] `profiles/code.json`에 실행 스킬 8개 추가 (git-worktree, execute-plan, subagent-dev, finish-branch, tdd, verify, code-review, receive-review)
- [ ] `profiles/code.json`에 on-demand 스킬 `cch-sp-debug`, `cch-sp-parallel-agents` 추가

---

### Recommended Priority for Integration
High priority (immediate value, no overlap):
1. `cch-sp-brainstorm` — design gate prevents wasted implementation
2. `cch-sp-debug` — systematic debugging discipline
3. `cch-sp-tdd` — TDD enforcement
4. `cch-sp-verify` — evidence before claims

Medium priority (workflow completeness):
5. `cch-sp-write-plan` — structured plan output
6. `cch-sp-subagent-dev` — high-quality execution
7. `cch-sp-git-worktree` — isolation safety

Lower priority (already covered by existing CCH skills):
8. `cch-sp-parallel-agents` — overlaps with cch-team/cch-rf-swarm
9. `cch-sp-finish-branch` — overlaps with cch-pr
10. `cch-sp-execute-plan` — alternative to subagent-dev
11. `cch-sp-code-review` / `cch-sp-receive-review` — nice-to-have quality gates
