---
name: cch-sp-debug
description: Use when encountering any bug, test failure, or unexpected behavior. Enforces root cause investigation before any fix is proposed. Four-phase process: root cause, pattern analysis, hypothesis, implementation.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, Edit
argument-hint: <description of bug or failing test>
---

# cch-sp-debug

Systematic debugging: find root cause before fixing. Four phases enforced in order. Random fixes are forbidden.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers systematic-debugging skill. Follow all four phases exactly:

**IRON LAW: No fixes without root cause investigation first.**

**Phase 1: Root Cause Investigation**
- Read error messages completely (stack traces, line numbers, error codes).
- Reproduce the issue consistently.
- Check recent changes (git diff, recent commits, new dependencies).
- For multi-component systems: add diagnostic instrumentation at each layer before proposing fixes.
- Trace data flow backward to the original source.

**Phase 2: Pattern Analysis**
- Find working examples of similar code in the codebase.
- Compare working vs broken — list every difference, however small.
- Understand all dependencies and assumptions.

**Phase 3: Hypothesis and Testing**
- Form a single specific hypothesis: "I think X is the root cause because Y."
- Test with the smallest possible change (one variable at a time).
- If hypothesis fails: form a NEW hypothesis. Do NOT stack fixes.

**Phase 4: Implementation**
- Write a failing test case first (invoke `cch-sp-tdd`).
- Implement the single fix addressing the root cause.
- Verify: test passes, no regressions.
- If 3+ fixes have failed: STOP — this is an architectural problem. Discuss before continuing.

### Stop Signals
If you catch yourself thinking "quick fix for now" or "just try changing X" — STOP. Return to Phase 1.

If 3+ fixes have failed, question the architecture rather than attempting fix #4.

## Integration

**Pairs with:** `cch-sp-tdd` — for creating the failing test case in Phase 4.

**Pairs with:** `cch-verify` — verify the fix before claiming completion.

**Source skill:** `superpowers:systematic-debugging` at `.claude/cch/sources/superpowers/skills/systematic-debugging/SKILL.md`
