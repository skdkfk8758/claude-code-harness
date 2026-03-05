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

## Process

### Phase 1: Scope Check
1. Read the plan document thoroughly
2. If multi-subsystem, decompose into sub-plans first
3. Map the file structure affected (Glob existing files)
4. List ambiguities — ask user to clarify

### Phase 2: Task Decomposition
For each implementation unit:

```markdown
### Task {N}: {title}
- **Estimate**: 2-5 minutes (if larger, split further)
- **Files**: List of files to create or modify
- **Changes**: What specifically changes in each file
- **TDD Steps**:
  1. Write failing test: [specific test description]
  2. Implement: [minimal code to pass]
  3. Refactor: [cleanup if needed]
- **Verify**: Command to run and expected output
- **Dependencies**: [Task N-1] or "none"
```

### Phase 3: Ordering & Batching
1. Sort by dependency order
2. Identify parallelizable tasks
3. Group into batches of 3 for execution checkpoints:
   ```
   --- Batch 1 (Tasks 1-3) → checkpoint ---
   --- Batch 2 (Tasks 4-6) → checkpoint ---
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

## Rules
- Include TDD steps for every task
- Do NOT start implementing — this is a planning gate only
