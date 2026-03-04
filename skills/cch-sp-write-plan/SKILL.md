---
name: cch-sp-write-plan
description: Use when you have a spec or approved design and need a detailed implementation plan before touching code. Produces bite-sized TDD task plans saved to docs/plans/.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write
argument-hint: <spec or design doc path>
---

# cch-sp-write-plan

Write a comprehensive implementation plan from a spec or approved design. Produces a `docs/plans/YYYY-MM-DD-<feature>.md` file with bite-sized TDD tasks, exact file paths, and complete code snippets.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers writing-plans skill. Follow it exactly:

1. Announce: "I'm using the writing-plans skill to create the implementation plan."
2. Read the design doc or spec provided by the user.
3. Write the plan to `docs/plans/YYYY-MM-DD-<feature-name>.md`.

**Every plan MUST start with this header:**
```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use cch-sp-execute-plan to implement this plan task-by-task.

**Goal:** [One sentence]
**Architecture:** [2-3 sentences]
**Tech Stack:** [Key technologies]

---
```

4. Structure each task with:
   - Exact file paths (create/modify/test)
   - Failing test code
   - Command to verify test fails
   - Minimal implementation code
   - Command to verify test passes
   - Git commit command

5. After saving the plan, offer two execution options:
   - **Subagent-Driven (this session):** invoke `cch-sp-subagent-dev`
   - **Parallel Session:** open new session using `cch-sp-execute-plan`

### Key Rules
- Bite-sized steps: each step is 2-5 minutes of work.
- Complete code in the plan — never "add validation" without showing the code.
- Exact commands with expected output.
- DRY, YAGNI, TDD, frequent commits.

## Integration

**Called after:** `cch-sp-brainstorm` — receives the approved design doc.

**Leads to:** `cch-sp-subagent-dev` (same session) or `cch-sp-execute-plan` (parallel session).

**Source skill:** `superpowers:writing-plans` at `.claude/cch/sources/superpowers/skills/writing-plans/SKILL.md`
