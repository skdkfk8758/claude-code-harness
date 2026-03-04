#!/usr/bin/env node
/**
 * Plan Bridge Integration Test
 *
 * Simulates the full ExitPlanMode → plan-bridge.mjs flow:
 * 1. Creates a temporary plan document
 * 2. Pipes ExitPlanMode input to plan-bridge.mjs
 * 3. Verifies execution-plan.json was created
 * 4. Verifies the output JSON has correct additionalContext
 *
 * Run: node tests/integration/plan-bridge-e2e.test.mjs
 */

import { strict as assert } from "node:assert";
import { mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, utimesSync } from "node:fs";
import { join } from "node:path";
import { execSync } from "node:child_process";

const CWD = process.cwd();
const PLANS_DIR = join(CWD, "docs", "plans");
const STATE_DIR = join(CWD, ".claude", "cch");
const EXEC_PLAN_FILE = join(STATE_DIR, "execution-plan.json");

const today = new Date().toISOString().slice(0, 10);
const TEST_PLAN_FILE = join(PLANS_DIR, `${today}-bridge-test.md`);

// --- Setup ---
function setup() {
  mkdirSync(PLANS_DIR, { recursive: true });
  writeFileSync(
    TEST_PLAN_FILE,
    `# Plan: bridge-test

> Created: ${today}

## Goal
통합 테스트용 브릿지 검증

## Approach
- [ ] 첫 번째 작업
- [ ] 두 번째 작업

## Acceptance Criteria
- [ ] 브릿지가 정상 동작
`,
    "utf8"
  );

  // Set mtime to a future time so findTodayPlan() picks this file over any
  // other today-dated plan files that already exist.
  const futureTime = new Date(Date.now() + 60_000);
  utimesSync(TEST_PLAN_FILE, futureTime, futureTime);

  // Clean previous execution plan
  rmSync(EXEC_PLAN_FILE, { force: true });
}

// --- Teardown ---
function teardown() {
  rmSync(TEST_PLAN_FILE, { force: true });
  rmSync(EXEC_PLAN_FILE, { force: true });
  rmSync(join(STATE_DIR, "work-items", "bridge-test"), { recursive: true, force: true });
}

// --- Test ---
function testBridgeFlow() {
  setup();

  try {
    const input = JSON.stringify({ tool_name: "ExitPlanMode" });
    const output = execSync(
      `echo '${input}' | node scripts/plan-bridge.mjs`,
      { cwd: CWD, timeout: 10000, encoding: "utf8" }
    );

    const result = JSON.parse(output.trim());

    // 1. continue is true
    assert.equal(result.continue, true, "continue should be true");

    // 2. additionalContext contains activation marker
    const ctx = result.hookSpecificOutput?.additionalContext || "";
    assert.ok(ctx.includes("[CCH BRIDGE ACTIVATED]"), "should contain ACTIVATED marker");
    assert.ok(ctx.includes("bridge-test"), "should contain work_id");
    assert.ok(ctx.includes("/cch-team"), "should contain pipeline trigger");

    // 3. execution-plan.json was created
    assert.ok(existsSync(EXEC_PLAN_FILE), "execution-plan.json should exist");

    const execPlan = JSON.parse(readFileSync(EXEC_PLAN_FILE, "utf8"));
    assert.equal(execPlan.version, "1");
    assert.equal(execPlan.work_id, "bridge-test");
    assert.equal(execPlan.goal, "통합 테스트용 브릿지 검증");
    assert.equal(execPlan.tasks.length, 2);
    assert.equal(execPlan.pipeline, "cch-team");
    assert.equal(execPlan.status, "ready");

    // G13: branch field in execution-plan.json
    assert.ok(execPlan.branch, "execution-plan should have branch field");
    assert.equal(execPlan.branch, "feat/bridge-test", "branch should be feat/<work_id>");

    console.log("  PASS: testBridgeFlow");
  } finally {
    teardown();
  }
}

function testNonExitPlanMode() {
  const input = JSON.stringify({ tool_name: "Write" });
  const output = execSync(
    `echo '${input}' | node scripts/plan-bridge.mjs`,
    { cwd: CWD, timeout: 5000, encoding: "utf8" }
  );

  const result = JSON.parse(output.trim());
  assert.equal(result.continue, true);
  assert.ok(!result.hookSpecificOutput, "should not have hookSpecificOutput for non-ExitPlanMode");

  console.log("  PASS: testNonExitPlanMode");
}

// Verify plan-bridge handles ExitPlanMode from a cwd with no docs/plans/ gracefully.
// It should still return { continue: true } without crashing.
function testNoPlanFileGraceful() {
  // Run the bridge from a temp directory that has no docs/plans/ directory,
  // so findTodayPlan() finds nothing and the bridge falls back gracefully.
  const tmpCwd = join(STATE_DIR, "tmp-nocwd-" + Date.now());
  mkdirSync(tmpCwd, { recursive: true });

  const input = JSON.stringify({ tool_name: "ExitPlanMode" });
  try {
    const output = execSync(
      `echo '${input}' | node ${JSON.stringify(join(CWD, "scripts/plan-bridge.mjs"))}`,
      { cwd: tmpCwd, timeout: 10000, encoding: "utf8" }
    );
    const result = JSON.parse(output.trim());
    assert.equal(result.continue, true, "continue should be true even when no plan file exists");
    // When no plan is found, bridge should not inject CCH activation context
    const ctx = result.hookSpecificOutput?.additionalContext || "";
    assert.ok(!ctx.includes("[CCH BRIDGE ACTIVATED]"), "should not inject ACTIVATED marker when no plan found");
  } finally {
    rmSync(tmpCwd, { recursive: true, force: true });
  }

  console.log("  PASS: testNoPlanFileGraceful");
}

// Verify execution-plan.json has all required fields per the schema.
function testExecutionPlanSchema() {
  setup();

  try {
    const input = JSON.stringify({ tool_name: "ExitPlanMode" });
    execSync(
      `echo '${input}' | node scripts/plan-bridge.mjs`,
      { cwd: CWD, timeout: 10000, encoding: "utf8" }
    );

    assert.ok(existsSync(EXEC_PLAN_FILE), "execution-plan.json should exist");

    const plan = JSON.parse(readFileSync(EXEC_PLAN_FILE, "utf8"));

    // Required top-level fields
    const required = ["version", "work_id", "goal", "tasks", "pipeline", "status", "branch"];
    for (const field of required) {
      assert.ok(field in plan, `execution-plan.json missing required field: ${field}`);
    }

    // tasks must be an array
    assert.ok(Array.isArray(plan.tasks), "tasks must be an array");

    // status must be 'ready'
    assert.equal(plan.status, "ready", "status must be 'ready'");

    // pipeline must be 'cch-team'
    assert.equal(plan.pipeline, "cch-team", "pipeline must be 'cch-team'");

    // branch must follow feat/<work_id> convention
    assert.match(plan.branch, /^feat\//, "branch must start with feat/");

  } finally {
    teardown();
  }

  console.log("  PASS: testExecutionPlanSchema");
}

console.log("plan-bridge integration tests:");
testBridgeFlow();
testNonExitPlanMode();
testNoPlanFileGraceful();
testExecutionPlanSchema();
console.log("All plan-bridge integration tests passed.");
