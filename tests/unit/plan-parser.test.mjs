#!/usr/bin/env node
/**
 * plan-parser unit tests
 * Run: node tests/unit/plan-parser.test.mjs
 */

import { strict as assert } from "node:assert";
import { parsePlanDocument } from "../../scripts/lib/plan-parser.mjs";

// --- Test fixtures ---

const FULL_PLAN = `# Plan: login-feature

> Created: 2026-03-03
> Work Item: login-feature
> Status: draft

## Goal
사용자 로그인 기능 구현

## Context
JWT 기반 인증 시스템 필요

## Approach

### Phase 1
- [ ] 로그인 API 엔드포인트 구현
- [ ] JWT 토큰 발급 로직
- [x] DB 스키마 설계

### Phase 2
- [ ] 비밀번호 해싱

## Risks
보안 취약점 주의

## Acceptance Criteria
- [ ] 로그인 성공 시 JWT 반환
- [ ] 잘못된 비밀번호 시 401 응답
- [x] DB 연결 확인

## 예상 변경 파일
- \`src/auth/login.ts\`
- \`src/middleware/jwt.ts\`

## Notes
추가 메모
`;

const EMPTY_TEMPLATE = `# Plan: general

> Created: 2026-03-03
> Work Item: general
> Status: draft

## Goal
<!-- What is the objective of this plan? -->

## Context
<!-- Current state, constraints, dependencies -->

## Approach
<!-- Step-by-step approach -->

### Phase 1
- [ ] Step 1

## Acceptance Criteria
- [ ] Criterion 1
`;

const MINIMAL_PLAN = `# Plan: quick-fix

## Goal
버그 수정

- [ ] 파일 A 수정
`;

// --- Tests ---

function testFullPlan() {
  const result = parsePlanDocument(FULL_PLAN, "2026-03-03-login-feature.md");

  assert.equal(result.work_id, "login-feature");
  assert.equal(result.goal, "사용자 로그인 기능 구현");
  assert.equal(result.tasks.length, 4);
  assert.equal(result.tasks[0].description, "로그인 API 엔드포인트 구현");
  assert.equal(result.tasks[0].done, false);
  assert.equal(result.tasks[2].description, "DB 스키마 설계");
  assert.equal(result.tasks[2].done, true);
  assert.equal(result.acceptance_criteria.length, 3);
  assert.equal(result.acceptance_criteria[0], "로그인 성공 시 JWT 반환");
  assert.deepEqual(result.changed_files, ["src/auth/login.ts", "src/middleware/jwt.ts"]);

  console.log("  PASS: testFullPlan");
}

function testEmptyTemplate() {
  const result = parsePlanDocument(EMPTY_TEMPLATE, "2026-03-03-general.md");

  assert.equal(result.work_id, "general");
  assert.equal(result.goal, "");
  assert.equal(result.is_empty_template, true);

  console.log("  PASS: testEmptyTemplate");
}

function testMinimalPlan() {
  const result = parsePlanDocument(MINIMAL_PLAN, "2026-03-03-quick-fix.md");

  assert.equal(result.work_id, "quick-fix");
  assert.equal(result.goal, "버그 수정");
  assert.equal(result.tasks.length, 1);
  assert.deepEqual(result.changed_files, []);

  console.log("  PASS: testMinimalPlan");
}

function testWorkIdExtraction() {
  // 날짜 prefix 제거
  const r1 = parsePlanDocument("## Goal\ntest", "2026-03-03-my-feature.md");
  assert.equal(r1.work_id, "my-feature");

  // 날짜 prefix 없으면 확장자만 제거
  const r2 = parsePlanDocument("## Goal\ntest", "some-plan.md");
  assert.equal(r2.work_id, "some-plan");

  // 복합 slug
  const r3 = parsePlanDocument("## Goal\ntest", "2026-03-03-w-p0-core-stability.md");
  assert.equal(r3.work_id, "w-p0-core-stability");

  console.log("  PASS: testWorkIdExtraction");
}

// --- Run ---
console.log("plan-parser tests:");
testFullPlan();
testEmptyTemplate();
testMinimalPlan();
testWorkIdExtraction();
console.log("All plan-parser tests passed.");
