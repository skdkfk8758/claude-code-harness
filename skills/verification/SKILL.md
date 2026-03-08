---
name: verification
description: Use before claiming any work is complete, fixed, or passing. Run verification commands and confirm output before any success claim, commit, or PR creation.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Verification Gate (Cross-Cutting)

This skill applies to ALL workflow steps. No completion claim without fresh verification evidence.

## The Rule

**NEVER claim something works, passes, or is fixed without:**
1. Running the actual verification command
2. Reading the actual output
3. Confirming the output matches expectations

## IDENTIFY-RUN-READ-VERIFY-CLAIM Protocol

### 1. IDENTIFY
What needs verification?
- Test suite passing
- Build succeeding
- Specific behavior working
- No regressions introduced

### 2. RUN
Execute the actual command. Not from memory. Not from assumption.
```bash
# Examples
npm test
npm run build
pytest -v
go test ./...
```

### 3. READ
Read the complete output. Do not skim. Look for:
- Failure messages hidden in passing output
- Warnings that indicate problems
- Skipped tests
- Partial passes

### 4. VERIFY
Confirm the output matches expectations:
- All tests pass (not just "most")
- Build has zero errors AND zero warnings (unless pre-existing)
- Specific behavior actually works (not just compiles)

### 5. CLAIM
Only now may you claim success.

## Common Failures

Things that look like "passing" but aren't:

| Failure Mode | What it looks like | How to catch it |
|-------------|-------------------|----------------|
| Silent test skip | "47 passed" but 3 were silently skipped | Check total count matches expected |
| Warning-as-error | Build "succeeds" with deprecation warnings | Read full output, not just exit code |
| Partial suite | Only unit tests ran, integration tests didn't | Run ALL test suites, not just the fast one |
| Stale build | Tests pass on old build artifact | Clean build before testing |
| Wrong environment | Tests pass locally but CI will fail | Check env-specific config (NODE_ENV, etc.) |
| Snapshot drift | Snapshot tests auto-update and "pass" | Review snapshot changes in git diff |
| Flaky pass | Test passes this time but fails 30% of the time | Run suspicious tests 3x if uncertain |

## Rationalization Prevention

These are NOT acceptable substitutes for running commands:

| Rationalization | Why it's wrong |
|----------------|----------------|
| "It should work because..." | Should != does |
| "I'm confident that..." | Confidence != evidence |
| "The logic is correct" | Logic != execution |
| "I just changed one line" | One line can break everything |
| "Tests were passing before" | Before != after your changes |
| "A partial check is enough" | Partial != complete |
| "The type system guarantees it" | Types don't catch runtime behavior |
| "I've done this a hundred times" | Experience doesn't prevent mistakes — evidence does |

## Red Flags

If you catch yourself doing any of these, you are about to make a false claim:
- Saying "tests pass" without a terminal command in this session
- Saying "build succeeds" without running the build
- Saying "fixed" without re-running the failing scenario
- Committing without running the test suite after your final change
- Claiming "no regressions" without running the full suite
- Using results from a PREVIOUS session as evidence for THIS session

## Enforcement Verification

When this skill is used with `enforcement: enforce` in a workflow step, the orchestrator verifies compliance by reading the agent's output. The following checks are performed automatically:

### Evidence Required
1. **Command execution**: Agent output must contain actual test/build command execution (terminal output with pass/fail counts)
2. **Result confirmation**: Output must show explicit pass/fail status, not just "tests pass" text without evidence

### Pass Criteria
- Test runner output with pass/fail counts is present in agent output
- No unchecked failures or skipped suites

### Failure Response
If evidence is missing, re-dispatch the agent with:
```
verification 규칙 미준수: 테스트/빌드 실행 증거가 부족합니다.
실제 명령을 실행하고, 전체 출력 결과를 포함하여 재보고하세요.
```

## Domain Context

**방법론 근거**: "증거 기반 검증"은 Continuous Delivery(Jez Humble & David Farley, 2010)의 핵심 원칙이다. 모든 변경은 자동화된 파이프라인을 통해 검증되어야 하며, "작동한다고 생각하는 것"과 "작동한다는 증거가 있는 것"은 근본적으로 다르다.

**핵심 원리**: 인간의 확증 편향(confirmation bias)은 "방금 고친 코드가 작동할 것"이라는 믿음을 만든다. IDENTIFY-RUN-READ-VERIFY-CLAIM 프로토콜은 이 편향을 구조적으로 차단한다.

### Further Reading
- Jez Humble & David Farley, *Continuous Delivery* (Addison-Wesley, 2010) — 배포 파이프라인과 검증 자동화
- Michael Bolton, [Testing vs. Checking](https://www.developsense.com/blog/2009/08/testing-vs-checking/) — 기계적 확인과 탐색적 테스트의 구분

## Rules
- This is not optional — it applies to every agent and skill
- If you cannot run verification (no test command, no build), state that explicitly instead of claiming success
- Fresh evidence means from THIS session, after YOUR changes — not cached results
- When in doubt, run it again — verification is cheap, false claims are expensive
