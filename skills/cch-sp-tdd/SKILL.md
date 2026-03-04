---
name: cch-sp-tdd
description: Use when implementing any feature or bugfix, before writing implementation code. Enforces red-green-refactor cycle. No production code without a failing test first.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
argument-hint: <feature or bugfix description>
---

# cch-sp-tdd

Test-Driven Development: write the failing test first, watch it fail, write minimal code to pass, refactor. No exceptions.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers test-driven-development skill. Follow it exactly:

**IRON LAW: No production code without a failing test first.**

**RED — Write Failing Test**
- Write one minimal test describing the desired behavior.
- One behavior per test, clear descriptive name, real code (no mocks unless unavoidable).

**Verify RED — Watch It Fail (MANDATORY)**
- Run the test. Confirm it fails.
- Confirm it fails because the feature is missing (not a syntax error).
- If it passes immediately: you are testing existing behavior. Fix the test.

**GREEN — Minimal Code**
- Write the simplest code that makes the test pass.
- No extra features, no refactoring of adjacent code, no YAGNI violations.

**Verify GREEN — Watch It Pass (MANDATORY)**
- Run the test. Confirm it passes.
- Confirm all other tests still pass.

**REFACTOR**
- Remove duplication, improve names, extract helpers.
- Keep all tests green. Do not add new behavior.

**Repeat** for the next behavior.

### If You Wrote Code Before the Test
Delete it. Start over. Do not keep it as "reference." Delete means delete.

### Key Rules
- "I'll write tests after" is rationalization. Tests-after prove nothing.
- "Tests after achieve the same goals" is false — tests-after verify what you built, not what was required.
- "Already manually tested" is insufficient — automated tests are systematic and re-runnable.

## Integration

**Required by:** `cch-sp-subagent-dev` — subagents should use TDD for each task.

**Required by:** `cch-sp-debug` — for writing the failing test case in Phase 4.

**Source skill:** `superpowers:test-driven-development` at `.claude/cch/sources/superpowers/skills/test-driven-development/SKILL.md`
