---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior. Enforces root cause investigation before any fix is proposed.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion, Write
argument-hint: "<error-description>"
---

# Systematic Debugging Gate

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

You MUST complete all 4 phases before proposing any fix. Do not skip phases. Do not guess.

## Phase 1: Root Cause Investigation

### Gather Evidence
1. Read the exact error message (full stack trace, not summary)
2. Reproduce the error — run the failing command yourself
3. Identify the boundary: where does correct behavior end and incorrect behavior begin?
4. Check recent changes: `git log --oneline -10` and `git diff`
5. **Complete Enumeration** — 관련 증거를 모두 나열. "기타 요인도 있을 수 있음", "등등" 금지. 열거하지 않은 것은 조사하지 않은 것

### Trace the Flow
1. Start from the error location and trace backwards
2. Read each function in the call chain
3. Check inputs and outputs at each boundary
4. Add diagnostic logging if needed (remove before fixing)

### Rule Out Common Causes
- Stale cache / stale build
- Environment mismatch
- Missing dependency
- Race condition
- Wrong branch / uncommitted changes

## Phase 2: Pattern Analysis

1. Search for similar errors in the codebase: `Grep` for error message fragments
2. Check git history for related fixes: `git log --all --grep="<keyword>"`
3. Look for known patterns:
   - Off-by-one errors
   - Null/undefined propagation
   - Async timing issues
   - Import/export mismatches

## Phase 3: Hypothesis Formation

1. Form a specific hypothesis: "The bug is caused by X because Y"
2. Design a verification test: "If my hypothesis is correct, then Z should happen"
3. Run the verification test
4. If hypothesis is wrong, return to Phase 1 with new evidence

## Phase 4: Targeted Fix

1. Fix ONLY what the root cause analysis identified
2. Follow TDD: write a test that reproduces the bug FIRST
3. Apply the minimal fix
4. Verify the test passes
5. Run the full test suite for regressions
6. Document: what was the root cause and why the fix works

## Output

Write investigation results to `docs/plans/{date}-{name}-investigation.md`:
- Error description and reproduction steps
- Root cause analysis
- Hypothesis and verification
- Fix applied and test evidence

## Escalation: 3+ Fixes Failed → Question Architecture

If you have attempted **3 or more fixes** and the bug persists:

1. **STOP fixing.** The problem is likely architectural, not local
2. Step back and ask:
   - Is the component doing too much?
   - Is there a hidden dependency or coupling?
   - Is the data model wrong?
   - Are we fighting the framework instead of using it?
3. Present an architecture-level analysis to the user before any more fix attempts
4. Consider whether a larger refactoring is needed instead of a point fix

## Red Flags

Stop and reassess your approach if you notice:
- Fix attempt #3 — you're likely missing the real cause
- Fixing a fix — if your fix needs a fix, your mental model is wrong
- "It works on my machine" — environment is part of the system
- The bug moves around — each fix causes a new failure elsewhere
- You're adding special cases — the abstraction is wrong
- The fix requires understanding 5+ files — the coupling is the bug
- You want to add a try/catch to "handle" the error — suppression is not fixing

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "Let me just try this quick fix" | Quick fixes without understanding cause bigger problems |
| "I think I know what's wrong" | Thinking != knowing. Run the investigation |
| "The error message tells me exactly what to fix" | Error messages describe symptoms, not root causes |
| "This worked before, so the new code must be wrong" | Correlation != causation. Investigate both sides |
| "I'll just revert the last change" | If you don't understand why it broke, it'll break again |

## Quick Reference

```
Bug reported → Phase 1 (investigate) → Phase 2 (patterns)
            → Phase 3 (hypothesis)  → Phase 4 (targeted fix)
            → If fix fails, back to Phase 1
            → If 3+ fails, ESCALATE to architecture review
```

## Domain Context

**방법론 근거**: 체계적 디버깅은 Andreas Zeller의 *Why Programs Fail* (2009)에서 정립된 과학적 디버깅 방법론에 기반한다. "관찰 → 가설 → 실험 → 검증"의 과학적 방법을 소프트웨어 결함 분석에 적용한다.

**핵심 원리**: 버그의 증상(symptom)과 근본원인(root cause)은 다르다. 증상만 보고 수정하면 같은 결함이 다른 형태로 재발한다. Phase 1-3의 조사 과정이 "진짜 원인"을 찾는 유일한 경로다.

### Further Reading
- Andreas Zeller, *Why Programs Fail: A Guide to Systematic Debugging* (Morgan Kaufmann, 2009)
- David J. Agans, *Debugging: The 9 Indispensable Rules* — 실무 디버깅 9원칙
- Julia Evans, [Debugging Zine](https://wizardzines.com/zines/debugging/) — 시각적 디버깅 가이드
- Google SRE Book, Ch.12 [Effective Troubleshooting](https://sre.google/sre-book/effective-troubleshooting/) — 대규모 시스템 장애 분석 프레임워크

## Rules
- NEVER skip to Phase 4 — even if you "know" the fix
- NEVER apply a fix without a reproduction test
- NEVER suppress an error to make it go away
- If you cannot determine root cause after Phase 2, ask the user for guidance
- If 3+ fix attempts fail, STOP and escalate — the bug is architectural
