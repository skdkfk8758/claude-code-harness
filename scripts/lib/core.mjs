/**
 * CCH Core Module
 * JSON parsing, state management, and manifest utilities for bin/cch bridge calls.
 *
 * Usage from bash:
 *   node scripts/lib/core.mjs <action> [args...]
 *
 * Actions:
 *   read-manifest              — Read and parse capabilities.json
 *   read-state <key>           — Read state value from .claude/cch/<key>
 *   write-state <key> <value>  — Write state value
 *   status-json                — Generate full status JSON output
 *   tier                       — Calculate and output current tier
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "fs";
import { execSync } from "child_process";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const CCH_ROOT = join(__dirname, "..", "..");
const STATE_DIR = process.env.CCH_STATE_DIR || ".claude/cch";
const MANIFEST_PATH = join(CCH_ROOT, "manifests", "capabilities.json");

// --- State helpers ---

export function readState(key) {
  const file = join(STATE_DIR, key);
  try {
    return readFileSync(file, "utf8").trim();
  } catch {
    return "";
  }
}

export function writeState(key, value) {
  const file = join(STATE_DIR, key);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, value + "\n");
}

// --- Manifest ---

export function readManifest() {
  try {
    return JSON.parse(readFileSync(MANIFEST_PATH, "utf8"));
  } catch {
    return { schema_version: 2, sources: {}, error_codes: {} };
  }
}

// --- Tier ---

export function calculateTier() {
  let tier = 0;

  // Check superpowers plugin
  const spDir = join(
    process.env.HOME || "",
    ".claude/plugins/cache/superpowers-marketplace"
  );
  if (existsSync(spDir)) {
    tier = 1;
  }

  // Check MCP servers
  if (tier >= 1) {
    const mcpConfig = join(process.env.HOME || "", ".claude/mcp.json");
    try {
      const config = JSON.parse(readFileSync(mcpConfig, "utf8"));
      if (Object.keys(config.mcpServers || {}).length > 0) {
        tier = 2;
      }
    } catch {
      // No MCP config or parse error
    }
  }

  return tier;
}

// --- Status JSON ---

export function buildStatusJson() {
  const mode = readState("mode") || "code";
  const health = readState("health") || "Unknown";
  const healthReason = readState("health_reason") || "";
  const tier = readState("tier") || String(calculateTier());

  // Reason codes
  const reasonCodes = healthReason ? healthReason.split(",") : [];

  // Branch info
  let branchName = null;
  let workId = null;
  try {
    branchName = execSync("git rev-parse --abbrev-ref HEAD 2>/dev/null", {
      encoding: "utf8",
    }).trim();
  } catch {
    // not in git repo
  }

  // Beads work items
  let workItems = [];
  try {
    const output = execSync("bash bin/cch beads list --json 2>/dev/null", {
      encoding: "utf8",
      cwd: CCH_ROOT,
    });
    workItems = JSON.parse(output);
  } catch {
    // beads not available
  }

  // Plans
  let plans = [];
  try {
    const plansDir = join(CCH_ROOT, "docs", "plans");
    if (existsSync(plansDir)) {
      plans = readdirSync(plansDir).filter((f) => f.endsWith(".md"));
    }
  } catch {
    // plans dir not found
  }

  return {
    version: "0.2.0",
    mode,
    tier: parseInt(tier, 10),
    health,
    reason_codes: reasonCodes,
    branch: branchName,
    work_id: workId,
    work_items: workItems,
    plans,
  };
}

// --- CLI entry point (only when run directly) ---

const isDirectRun = process.argv[1]?.endsWith("core.mjs");
const action = isDirectRun ? process.argv[2] : undefined;

switch (action) {
  case "read-manifest":
    console.log(JSON.stringify(readManifest(), null, 2));
    break;

  case "read-state":
    console.log(readState(process.argv[3] || ""));
    break;

  case "write-state":
    writeState(process.argv[3] || "", process.argv[4] || "");
    break;

  case "status-json":
    console.log(JSON.stringify(buildStatusJson(), null, 2));
    break;

  case "tier":
    console.log(calculateTier());
    break;

  default:
    if (action) {
      console.error(`Unknown action: ${action}`);
      process.exit(1);
    }
    // If imported as module, do nothing
    break;
}
