---
name: tdd
description: Use when implementing any feature or bugfix, before writing implementation code. Enforces red-green-refactor cycle. No production code without a failing test first.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Test-Driven Development (Cross-Cutting)

This skill applies to ALL implementation work. It is not optional.

## The Rule

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**

If you find yourself writing production code before a test exists, STOP. Delete the production code. Write the test first.

## RED-GREEN-REFACTOR Cycle

### RED: Write a failing test
1. Write the smallest test that describes the desired behavior
2. Run it — it MUST fail
3. If it passes without new code, the test is wrong (testing something already implemented)
4. The failure message should clearly describe what's missing

### GREEN: Write minimal code to pass
1. Write the MINIMUM code to make the test pass
2. Do not write "good" code — write passing code
3. Run the test — it MUST pass now
4. If it still fails, fix the code (not the test)

### REFACTOR: Clean up
1. Now improve the code quality
2. Run tests after each refactoring step — they must stay green
3. Remove duplication, improve naming, extract abstractions
4. Only refactor if there's a clear benefit

## Test Structure: AAA Pattern

Every test follows three phases separated by blank lines:

| Phase | What | Example |
|-------|------|---------|
| **Arrange** | Set up test data, mocks, fixtures | `const user = createTestUser()` |
| **Act** | Execute the code under test | `const result = await service.getUser(id)` |
| **Assert** | Verify expected outcome | `expect(result.name).toBe('test')` |

If a single test has multiple Act/Assert blocks, split it into separate tests.

## Test Naming Convention

Pattern: `test_<what>_<when>_<expected>` (or framework equivalent)

| Bad | Good |
|-----|------|
| `test1`, `it works` | `test_create_user_with_valid_data_returns_user` |
| `test_service` | `test_get_user_when_not_found_raises_404` |
| `should work correctly` | `adds_two_positive_numbers_returns_sum` |

The name must describe the behavior under test — not the implementation detail.

## Anti-Patterns to Avoid

| Anti-Pattern | What to do instead |
|-------------|-------------------|
| Writing tests after implementation | Delete impl, write test first |
| Testing implementation details (mocking internals) | Test behavior and outcomes |
| Test that always passes | Verify it fails without the feature |
| Copying test code everywhere | Extract test utilities, use fixtures |
| Testing trivial getters/setters | Test meaningful behavior |
| One giant test per feature | Many small focused tests |
| Ignoring/skipping failing tests | Fix or remove them |
| Testing only the happy path | Test error cases, edge cases, boundary conditions |
| No test structure (wall of code) | Separate Arrange/Act/Assert with blank lines |
| Vague test names (`test1`, `it works`) | Use `test_<what>_<when>_<expected>` pattern |

## Common Rationalizations (and why they're wrong)

| Rationalization | Why it's wrong | What to do |
|----------------|----------------|-----------|
| "This is too simple to test" | Simple code breaks too. If it's worth writing, it's worth testing | Write the test — it'll be fast if it's truly simple |
| "I'll write tests after" | You won't. And you'll write tests that pass, not tests that verify | Write the test NOW, before the code |
| "The test is obvious, I'll just write the code" | The test enforces the contract. Obvious code still needs a contract | Write the obvious test first |
| "I need to see the code shape first" | TDD shapes the code. Code-first shapes tests to match implementation | Let the test drive the design |
| "Testing this would require too much setup" | Complex setup = poor design. Refactor to make it testable | Simplify the interface, then test |
| "I'm just refactoring, no new tests needed" | Refactoring without tests is gambling | Ensure existing tests cover it, or add tests first |
| "This is a prototype / spike" | Spikes explore; they don't ship. If it ships, it needs tests | Mark it explicitly as spike, rewrite with TDD for production |
| "The type system catches this" | Types catch type errors, not logic errors | Test the behavior, not just the types |

## Good vs Bad Examples

### BAD: Test written after implementation
```typescript
// ❌ Wrote the function first, then "verified" it works
function add(a: number, b: number) { return a + b; }

// Test added after — just mirrors the implementation
test('add works', () => {
  expect(add(1, 2)).toBe(3);  // This tells you nothing you didn't already know
});
```

### GOOD: Test drives the implementation
```typescript
// ✅ Step 1 (RED): Write the test FIRST — no add() exists yet
test('adds two positive numbers', () => {
  expect(add(1, 2)).toBe(3);
});
test('handles negative numbers', () => {
  expect(add(-1, -2)).toBe(-3);
});
test('handles zero', () => {
  expect(add(0, 5)).toBe(5);
});
// Run → all FAIL (add is not defined)

// ✅ Step 2 (GREEN): Write minimum code to pass
function add(a: number, b: number): number {
  return a + b;
}
// Run → all PASS
```

### BAD: Testing implementation details
```typescript
// ❌ Tightly coupled to internal implementation
test('uses cache map internally', () => {
  const service = new UserService();
  service.getUser('123');
  expect(service['_cache'].has('123')).toBe(true);  // Breaks if cache impl changes
});
```

### GOOD: Testing behavior
```typescript
// ✅ Tests observable behavior, not internals
test('returns same user on repeated calls without extra fetch', () => {
  const service = new UserService(mockFetcher);
  await service.getUser('123');
  await service.getUser('123');
  expect(mockFetcher.callCount).toBe(1);  // Behavior: only fetches once
});
```

## Red Flags

Stop immediately if you notice:
- Writing production code and thinking "I'll add tests in a minute"
- A test file that was created AFTER the source file
- Tests that only test the happy path
- `test.skip()` or `xit()` anywhere in the codebase
- Test names that don't describe behavior ("test1", "it works")

## Enforcement Verification

When this skill is used with `enforcement: enforce` in a workflow step, the orchestrator verifies compliance by reading the agent's output. The following checks are performed automatically:

### Evidence Required
1. **RED phase**: Agent output must contain failing test output (test runner error/failure messages)
2. **GREEN phase**: Agent output must contain passing test output after implementation
3. **Cycle completeness**: Each task must show both RED and GREEN evidence in sequence

### Pass Criteria
- At least one RED-GREEN cycle per task is evidenced in agent output
- Test runner output (not just assertions in code) is present

### Failure Response
If evidence is missing, re-dispatch the agent with:
```
TDD 규칙 미준수: RED-GREEN-REFACTOR 사이클 증거가 부족합니다.
각 태스크에 대해 (1) 실패하는 테스트 실행 결과, (2) 통과하는 테스트 실행 결과를 포함하여 재보고하세요.
```

## Domain Context

**방법론 근거**: Test-Driven Development는 Kent Beck이 *Test-Driven Development: By Example* (2002)에서 체계화한 소프트웨어 개발 방법론이다. "테스트가 설계를 주도한다"는 핵심 원칙은 이후 Extreme Programming, Continuous Delivery 등의 기반이 되었다.

**핵심 원리**: RED-GREEN-REFACTOR 사이클은 단순한 테스트 작성 순서가 아니라, 코드 설계를 점진적으로 발견하는 프로세스다. 실패하는 테스트가 인터페이스를 정의하고, 최소 구현이 계약을 충족하며, 리팩토링이 설계를 개선한다.

### Further Reading
- Kent Beck, *Test-Driven Development: By Example* (Addison-Wesley, 2002)
- Martin Fowler, [Is TDD Dead?](https://martinfowler.com/articles/is-tdd-dead/) — TDD의 한계와 적용 범위에 대한 균형 잡힌 논의
- Robert C. Martin, *Clean Code* Ch.9 — Unit Tests 작성 원칙
- Gerard Meszaros, *xUnit Test Patterns* — AAA 패턴, 테스트 더블, 테스트 냄새의 체계적 분류

## Integration with Workflow

When executing tasks from a task plan:
1. Each task's TDD Steps define the test to write
2. Write exactly that test first (RED)
3. Implement exactly what the task specifies (GREEN)
4. Refactor only within task scope (REFACTOR)
5. Move to next task only when current is green
