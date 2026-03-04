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
import { join } from "node:path";
import { execSync } from "node:child_process";
import { parsePlanDocument } from "./lib/plan-parser.mjs";
import { buildBridgeOutput, BRIDGE_REASONS } from "./lib/bridge-output.mjs";

const CCH_ROOT = process.env.CLAUDE_PLUGIN_ROOT || process.cwd();
const CCH_STATE_DIR = join(process.cwd(), ".claude", "cch");
const PLANS_DIR = join(process.cwd(), "docs", "plans");
const EXEC_PLAN_FILE = join(CCH_STATE_DIR, "execution-plan.json");
const CMD_TIMEOUT = 800; // 4 cmds × 1.6s = 6.4s max (closer to 5s hook budget)

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

  const matched = files.filter((f) => f.startsWith(today) && f.endsWith(".md"));
  if (matched.length === 0) return null;
  if (matched.length === 1) {
    return { name: matched[0], path: join(PLANS_DIR, matched[0]) };
  }

  // Multiple candidates — stat to pick the most recent
  const candidates = matched
    .map((f) => {
      const fullPath = join(PLANS_DIR, f);
      return { name: f, path: fullPath, mtime: statSync(fullPath).mtimeMs };
    })
    .sort((a, b) => b.mtime - a.mtime);

  return candidates[0];
}

/**
 * G8: Infer branch type from plan filename via substring matching.
 * Default: "feat"
 */
const BRANCH_TYPE_PATTERNS = [
  [/-(bug)?fix|-hotfix/, "fix"],
  [/-refactor/, "refactor"],
  [/-docs/, "docs"],
  [/-chore/, "chore"],
];

function inferBranchType(planFilename) {
  const name = planFilename.toLowerCase();
  const match = BRANCH_TYPE_PATTERNS.find(([pattern]) => pattern.test(name));
  return match ? match[1] : "feat";
}

/**
 * G9: Run cch CLI commands individually, collecting per-command results.
 * Returns array of { cmd, ok, error? } objects for warning visibility.
 */
function runCchBatch(argsList) {
  const cchBin = join(CCH_ROOT, "bin", "cch");
  const results = [];
  for (const args of argsList) {
    try {
      const stdout = execSync(`bash "${cchBin}" ${args}`, {
        timeout: CMD_TIMEOUT * 2,
        cwd: process.cwd(),
        stdio: "pipe",
        shell: true,
        encoding: "utf8",
      });
      results.push({ cmd: args, ok: true, output: stdout });
    } catch (err) {
      results.push({ cmd: args, ok: false, error: err.stderr?.trim() || err.message });
    }
  }
  return results;
}

function main() {
  try {
    // Read stdin (hook provides tool context)
    const input = JSON.parse(readFileSync(0, "utf8"));
    const toolName = input.tool_name || "";

    // Defense-in-depth: hooks.json matcher already filters for ExitPlanMode,
    // but guard here in case this script is invoked outside the hook system.
    if (toolName !== "ExitPlanMode") {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    // Step 1: Find today's plan document
    const planFile = findTodayPlan();
    if (!planFile) {
      console.log(JSON.stringify(buildBridgeOutput(null, { success: false, reason: BRIDGE_REASONS.NO_PLAN_FOUND })));
      return;
    }

    // Step 2: Parse plan document
    const content = readFileSync(planFile.path, "utf8");
    const parsed = parsePlanDocument(content, planFile.name);
    parsed.plan_file = `docs/plans/${planFile.name}`;

    // Step 3: Validate — not an empty template
    if (parsed.is_empty_template) {
      console.log(JSON.stringify(buildBridgeOutput(parsed, { success: false, reason: BRIDGE_REASONS.EMPTY_TEMPLATE })));
      return;
    }

    // Step 4: Validate — has tasks
    if (parsed.tasks.length === 0) {
      console.log(JSON.stringify(buildBridgeOutput(parsed, { success: false, reason: BRIDGE_REASONS.NO_TASKS })));
      return;
    }

    // Step 5: Infer branch info (G8, G10)
    const branchType = inferBranchType(planFile.name);
    const branchName = `${branchType}/${parsed.work_id}`;

    // Step 6: Build execution plan JSON (G13: branch field)
    const execPlan = {
      version: "1",
      created_at: new Date().toISOString(),
      work_id: parsed.work_id,
      plan_file: parsed.plan_file,
      status: "ready",
      goal: parsed.goal,
      branch: branchName,
      tasks: parsed.tasks.map((t, i) => ({ id: i + 1, ...t })),
      acceptance_criteria: parsed.acceptance_criteria,
      changed_files: parsed.changed_files,
      pipeline: "cch-team",
      mode: "code",
    };

    // Step 7: Save execution-plan.json
    mkdirSync(CCH_STATE_DIR, { recursive: true });
    writeFileSync(EXEC_PLAN_FILE, JSON.stringify(execPlan, null, 2), "utf8");
    // Step 8: Create bead (primary) + branch + switch mode
    const beadsResults = runCchBatch([
      `beads create "${parsed.goal}" --priority 1 --labels "plan:${parsed.work_id}"`,
    ]);
    if (beadsResults[0]?.ok) {
      const beadMatch = (beadsResults[0].output || "").match(/cch-[a-z0-9]+/);
      if (beadMatch) {
        execPlan.bead_id = beadMatch[0];
        writeFileSync(EXEC_PLAN_FILE, JSON.stringify(execPlan, null, 2), "utf8");
      }
    }

    const batchResults = runCchBatch([
      `branch create "${branchType}" "${parsed.work_id}"`,
      "mode code",
    ]);

    // G9: Collect warnings from failed commands
    const warnings = [...beadsResults, ...batchResults].filter((r) => !r.ok);

    // Step 9: Output additionalContext with pipeline trigger
    console.log(JSON.stringify(buildBridgeOutput(parsed, { success: true }, warnings)));
  } catch {
    // Never block tool execution
    console.log(JSON.stringify({ continue: true }));
  }
}

main();
