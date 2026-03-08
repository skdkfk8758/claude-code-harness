---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code. Produces bite-sized TDD task plans.
user-invocable: true
allowed-tools: Read, Glob, Grep, Agent, AskUserQuestion, Write, Bash
argument-hint: "<plan-file-path>"
---

# Writing Plans Gate

You are a task decomposition specialist. This is a **gate** — the task list must be approved before implementation begins.

Skill directory: !`echo ${CLAUDE_SKILL_DIR}`

## Input

Read the plan document provided as argument (or find the latest `*-plan.md` in `docs/plans/`).

The plan document contains a **Task Overview** table with task descriptions, sizes, and dependencies.
Use this table as the basis for detailed task decomposition — do NOT re-invent the task list from scratch.

## Process

### Phase 1: Scope Check
1. Read the plan document thoroughly, especially the Task Overview table
2. Verify each task in the overview against the codebase (Glob existing files)
3. If multi-subsystem, decompose into sub-plans first
4. List ambiguities — ask user to clarify

### Phase 2: Task Decomposition
For each implementation unit:

```markdown
### Task {N}: {title}
- **Estimate**: 2-5 minutes (if larger, split further)
- **Complexity**: 🟢 Routine / 🟡 Moderate / 🔴 Complex
- **Risk**: 🟢 Safe / 🟡 Caution / 🔴 Risky
- **Files**: List of files to create or modify
- **Changes**: What specifically changes in each file
- **TDD Steps**:
  1. Write failing test: [specific test description]
  2. Implement: [minimal code to pass]
  3. Refactor: [cleanup if needed]
- **Verify**: Command to run and expected output
- **Dependencies**: [Task N-1] or "none"
```

#### Complexity/Risk 기준

| 지표 | 🟢 | 🟡 | 🔴 |
|------|-----|-----|-----|
| **Complexity** | 단일 파일, 패턴 반복 | 2-3파일 연동, 새 패턴 도입 | 4+파일, 기존 인터페이스 변경 |
| **Risk** | 기존 테스트로 검증 가능 | 새 테스트 필요, 부분적 영향 | 공유 상태 변경, 롤백 어려움 |

- 🔴 Complex 태스크는 반드시 5분 이내로 분할 가능한지 재검토
- 🔴 Risky 태스크는 **별도 배치로 격리** — 다른 태스크와 같은 배치에 묶지 않음

### Phase 3: Ordering & Batching
1. Sort by dependency order
2. Identify parallelizable tasks
3. Group into batches of 3 for execution checkpoints
4. 🔴 Risky 태스크는 단독 배치 또는 배치 첫 번째에 배치
5. 각 배치에 **Batch Summary** 추가:
   ```
   --- Batch 1 (Tasks 1-3) → checkpoint ---
   Complexity: 🟢🟢🟡  Risk: 🟢🟢🟡  예상: ~10min

   --- Batch 2 (Task 4) → checkpoint [isolated: risky] ---
   Complexity: 🔴  Risk: 🔴  예상: ~5min
   ```

### Phase 4: Plan Review Loop
1. Read `plan-document-reviewer-prompt.md` from this skill's directory
2. Dispatch Agent tool (subagent_type: "general-purpose") with reviewer prompt + task list
3. Address findings, re-review if needed
4. **Iteration cap: maximum 5 review cycles**
   - If still NEEDS REVISION after 5 iterations:
     - Summarize all unresolved issues
     - Ask user: "Approve as-is with known issues, or return to design phase?"
     - If return → recommend re-running brainstorming with refined scope

### Phase 5: Approval
1. Present full task list to user
2. Ask for confirmation or adjustments
3. Write to `docs/plans/{date}-{name}-tasks.md`

## Output

```
✅ Task plan approved: docs/plans/{date}-{name}-tasks.md
   {N} tasks in {M} batches

Next step: The code-refactor-master agent will execute these tasks.
If you're in a workflow, return to the workflow orchestrator.
```

## Task Size Rules
- Each task: 2-5 minutes, at most 5 files
- Each task: independently verifiable
- Assume implementing agent has ZERO codebase context — be explicit

## Domain Context

**방법론 근거**: 태스크 분해(Work Breakdown Structure)는 프로젝트 관리의 핵심 기법으로, PMI의 PMBOK Guide에서 체계화되었다. "2-5분 단위 태스크"는 Pomodoro Technique과 소프트웨어 개발의 "작은 커밋" 원칙을 결합한 것이다.

**핵심 원리**: 태스크가 작을수록 (1) 실패 시 되돌리기 쉽고, (2) TDD 사이클이 빠르고, (3) 리뷰가 용이하다. "구현 에이전트에 컨텍스트가 없다고 가정"하는 것은 에이전트 간 암묵지 의존을 차단하는 안전장치다.

### Further Reading
- Kent Beck, *Extreme Programming Explained* — 작은 릴리스와 점진적 설계
- Mike Cohn, *User Stories Applied* — 스토리 분할과 INVEST 기준
- Basecamp, [Shape Up](https://basecamp.com/shapeup) — Appetite 기반 스코프 관리

## Rules
- Include TDD steps for every task
- Do NOT start implementing — this is a planning gate only
