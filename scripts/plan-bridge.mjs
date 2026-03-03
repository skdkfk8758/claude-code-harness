#!/usr/bin/env node
/**
 * CCH Plan Bridge - PostToolUse:ExitPlanMode Hook
 *
 * Automatically bridges the interview/plan phase to execution:
 * 1. Finds today's plan document in docs/plans/
 * 2. Parses it into structured data
 * 3. Saves execution-plan.json
 * 4. Creates work item + transitions to doing
 * 5. Switches mode to code
 * 6. Injects pipeline trigger via additionalContext
 */

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from "node:fs";
import { join, basename } from "node:path";
import { execSync } from "node:child_process";
import { parsePlanDocument } from "./lib/plan-parser.mjs";
import { buildBridgeOutput } from "./lib/bridge-output.mjs";

const CCH_ROOT = process.env.CLAUDE_PLUGIN_ROOT || join(process.cwd());
const CCH_STATE_DIR = join(process.cwd(), ".claude", "cch");
const PLANS_DIR = join(process.cwd(), "docs", "plans");
const EXEC_PLAN_FILE = join(CCH_STATE_DIR, "execution-plan.json");
const CMD_TIMEOUT = 2000; // 2s per shell command

/**
 * Find the most recently modified plan document for today.
 * Pattern: docs/plans/${today}-*.md
 */
function findTodayPlan() {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

  let files;
  try {
    files = readdirSync(PLANS_DIR);
  } catch {
    return null;
  }

  const candidates = files
    .filter((f) => f.startsWith(today) && f.endsWith(".md"))
    .map((f) => ({
      name: f,
      path: join(PLANS_DIR, f),
      mtime: statSync(join(PLANS_DIR, f)).mtimeMs,
    }))
    .sort((a, b) => b.mtime - a.mtime);

  return candidates[0] || null;
}

/**
 * Run a cch CLI command, swallowing errors.
 */
function runCch(args) {
  try {
    execSync(`bash "${join(CCH_ROOT, "bin", "cch")}" ${args}`, {
      timeout: CMD_TIMEOUT,
      cwd: process.cwd(),
      stdio: "pipe",
    });
    return true;
  } catch {
    return false;
  }
}

function main() {
  try {
    // Read stdin (hook provides tool context)
    const input = JSON.parse(readFileSync(0, "utf8"));
    const toolName = input.tool_name || "";

    // Safety check — only run for ExitPlanMode
    if (toolName !== "ExitPlanMode") {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    // Step 1: Find today's plan document
    const planFile = findTodayPlan();
    if (!planFile) {
      console.log(JSON.stringify(buildBridgeOutput(null, { success: false, reason: "no_plan_found" })));
      return;
    }

    // Step 2: Parse plan document
    const content = readFileSync(planFile.path, "utf8");
    const parsed = parsePlanDocument(content, planFile.name);
    parsed.plan_file = `docs/plans/${planFile.name}`;

    // Step 3: Validate — not an empty template
    if (parsed.is_empty_template) {
      console.log(JSON.stringify(buildBridgeOutput(parsed, { success: false, reason: "empty_template" })));
      return;
    }

    // Step 4: Validate — has tasks
    if (parsed.tasks.length === 0) {
      console.log(JSON.stringify(buildBridgeOutput(parsed, { success: false, reason: "no_tasks" })));
      return;
    }

    // Step 5: Build execution plan JSON
    const execPlan = {
      version: "1",
      created_at: new Date().toISOString(),
      work_id: parsed.work_id,
      plan_file: parsed.plan_file,
      status: "ready",
      goal: parsed.goal,
      tasks: parsed.tasks.map((t, i) => ({ id: i + 1, ...t })),
      acceptance_criteria: parsed.acceptance_criteria,
      changed_files: parsed.changed_files,
      pipeline: "cch-team",
      mode: "code",
    };

    // Step 6: Save execution-plan.json
    mkdirSync(CCH_STATE_DIR, { recursive: true });
    writeFileSync(EXEC_PLAN_FILE, JSON.stringify(execPlan, null, 2), "utf8");

    // Step 7: Create work item + transition (ignore if already exists)
    runCch(`work create "${parsed.work_id}" "${parsed.goal}"`);
    runCch(`work transition "${parsed.work_id}" doing`);

    // Step 8: Switch mode to code
    runCch("mode code");

    // Step 9: Output additionalContext with pipeline trigger
    console.log(JSON.stringify(buildBridgeOutput(parsed, { success: true })));
  } catch {
    // Never block tool execution
    console.log(JSON.stringify({ continue: true }));
  }
}

main();
