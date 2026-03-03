#!/usr/bin/env node
/**
 * plan-bridge output logic tests
 * Tests the buildBridgeOutput function that creates the hook response.
 * Run: node tests/unit/plan-bridge.test.mjs
 */

import { strict as assert } from "node:assert";
import { buildBridgeOutput } from "../../scripts/lib/bridge-output.mjs";

function testSuccessOutput() {
  const plan = {
    work_id: "login-feature",
    goal: "로그인 기능 구현",
    plan_file: "docs/plans/2026-03-03-login-feature.md",
    tasks: [
      { id: 1, description: "API 구현", done: false },
      { id: 2, description: "테스트 작성", done: false },
    ],
    acceptance_criteria: ["JWT 반환", "401 응답"],
    is_empty_template: false,
  };

  const result = buildBridgeOutput(plan, { success: true });

  assert.equal(result.continue, true);
  const ctx = result.hookSpecificOutput.additionalContext;
  assert.ok(ctx.includes("[CCH BRIDGE ACTIVATED]"));
  assert.ok(ctx.includes("login-feature"));
  assert.ok(ctx.includes("로그인 기능 구현"));
  assert.ok(ctx.includes("/cch-team"));
  assert.ok(ctx.includes("작업 수: 2개"));
  assert.ok(ctx.includes("완료 기준: 2개"));

  console.log("  PASS: testSuccessOutput");
}

function testEmptyTemplateWarning() {
  const plan = {
    work_id: "general",
    goal: "",
    plan_file: "docs/plans/2026-03-03-general.md",
    tasks: [],
    acceptance_criteria: [],
    is_empty_template: true,
  };

  const result = buildBridgeOutput(plan, { success: false, reason: "empty_template" });

  assert.equal(result.continue, true);
  const ctx = result.hookSpecificOutput.additionalContext;
  assert.ok(ctx.includes("[CCH BRIDGE WARNING]"));
  assert.ok(!ctx.includes("/cch-team"));

  console.log("  PASS: testEmptyTemplateWarning");
}

function testNoPlanWarning() {
  const result = buildBridgeOutput(null, { success: false, reason: "no_plan_found" });

  assert.equal(result.continue, true);
  const ctx = result.hookSpecificOutput.additionalContext;
  assert.ok(ctx.includes("[CCH BRIDGE WARNING]"));

  console.log("  PASS: testNoPlanWarning");
}

console.log("bridge-output tests:");
testSuccessOutput();
testEmptyTemplateWarning();
testNoPlanWarning();
console.log("All bridge-output tests passed.");
