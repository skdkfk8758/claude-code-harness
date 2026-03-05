#!/usr/bin/env node
/**
 * CCH HUD - Claude Code Harness Statusline (v3)
 * Reads v3 workflow state and displays status elements.
 *
 * Output format:
 *   Line 1: project-name | branch | worktree
 *   Line 2: rate-limits | context | workflow-status
 *
 * Config: hud/cch-hud-config.json (relative to plugin root)
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { execSync } from "node:child_process";
import https from "node:https";
import { join, dirname, basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// --- Read stdin (session context from Claude Code) ---
let _stdinData = {};
try {
  const raw = readFileSync(0, "utf8").trim();
  if (raw) _stdinData = JSON.parse(raw);
} catch { /* stdin may be empty or unavailable */ }

// --- ANSI colors ---
const c = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  magenta: "\x1b[35m",
  white: "\x1b[37m",
};

// --- Config ---
function loadConfig() {
  const configPath = join(__dirname, "cch-hud-config.json");
  const defaults = {
    showProjectName: true,
    showGitBranch: true,
    showWorktree: true,
    showWorkflow: true,
    showTokenUsage: true,
  };
  try {
    if (existsSync(configPath)) {
      return { ...defaults, ...JSON.parse(readFileSync(configPath, "utf8")) };
    }
  } catch { /* use defaults */ }
  return defaults;
}

// --- Utility ---
function readFile(path) {
  try {
    return existsSync(path) ? readFileSync(path, "utf8").trim() : "";
  } catch { return ""; }
}

// --- Project / Git ---
function getProjectName() {
  const cwd = process.cwd();
  const pkgPath = join(cwd, "package.json");
  try {
    if (existsSync(pkgPath)) {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
      if (pkg.name) return `${c.bold}${c.white}${pkg.name}${c.reset}`;
    }
  } catch { /* fallback */ }
  return `${c.bold}${c.white}${basename(cwd)}${c.reset}`;
}

function getGitBranch() {
  try {
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
    }).toString().trim();
    return branch ? `${c.magenta}${branch}${c.reset}` : null;
  } catch { return null; }
}

function getWorktreeInfo() {
  try {
    const gitDir = resolve(execSync("git rev-parse --git-dir", {
      stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
    }).toString().trim());
    const commonDir = resolve(execSync("git rev-parse --git-common-dir", {
      stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
    }).toString().trim());

    if (gitDir !== commonDir) {
      const toplevel = execSync("git rev-parse --show-toplevel", {
        stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
      }).toString().trim();
      return `${c.yellow}wt:${basename(toplevel)}${c.reset}`;
    }
  } catch { /* not in git repo */ }
  return null;
}

// --- v3 Workflow State ---
function getWorkflowStatus() {
  const statePath = join(process.cwd(), ".claude", "workflow-state.json");
  const raw = readFile(statePath);
  if (!raw) return `${c.dim}WF:none${c.reset}`;

  try {
    const state = JSON.parse(raw);
    const wf = state.workflow || "?";
    const name = state.name || "";
    const currentStep = state.currentStep || 0;

    // Count total steps and find current step info
    const steps = state.steps || {};
    const stepIds = Object.keys(steps);
    const total = stepIds.length || "?";

    // Find current step status
    let currentId = "";
    let currentStatus = "";
    for (const [id, info] of Object.entries(steps)) {
      if (info.status === "in-progress") {
        currentId = id;
        currentStatus = "in-progress";
        break;
      }
    }

    // If no in-progress, find the last completed to show next
    if (!currentId) {
      let lastCompleted = 0;
      for (const [id, info] of Object.entries(steps)) {
        if (info.status === "completed") lastCompleted++;
      }
      if (lastCompleted >= stepIds.length) {
        return `${c.green}WF:${wf}${c.dim}(${name})${c.reset} ${c.green}✓ done${c.reset}`;
      }
      currentId = stepIds[lastCompleted] || "";
      currentStatus = "pending";
    }

    // Determine step type indicator
    const stepColor = currentStatus === "in-progress" ? c.cyan : c.yellow;
    const stepNum = currentStep || (stepIds.indexOf(currentId) + 1);

    return `${c.bold}WF:${c.cyan}${wf}${c.reset}${c.dim}(${name})${c.reset} ${stepColor}${stepNum}/${total}${c.reset} ${c.white}${currentId}${c.reset}`;
  } catch {
    return `${c.yellow}WF:error${c.reset}`;
  }
}

// --- Rate Limit API ---
const RATE_CACHE_PATH = join(process.env.HOME || "", ".claude", "hud", ".rate-limit-cache.json");
const RATE_CACHE_TTL_MS = 30_000;

function readRateCache() {
  try {
    if (!existsSync(RATE_CACHE_PATH)) return null;
    return JSON.parse(readFileSync(RATE_CACHE_PATH, "utf8"));
  } catch { return null; }
}

function writeRateCache(data, error = false) {
  try {
    const dir = dirname(RATE_CACHE_PATH);
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    writeFileSync(RATE_CACHE_PATH, JSON.stringify({ timestamp: Date.now(), data, error }, null, 2));
  } catch { /* ignore */ }
}

function getOAuthCredentials() {
  if (process.platform === "darwin") {
    try {
      const raw = execSync(
        '/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null',
        { encoding: "utf8", timeout: 2000 }
      ).trim();
      if (raw) {
        const parsed = JSON.parse(raw);
        const creds = parsed.claudeAiOauth || parsed;
        if (creds.accessToken) return creds;
      }
    } catch { /* keychain not available */ }
  }
  try {
    const credPath = join(process.env.HOME || "", ".claude", ".credentials.json");
    if (!existsSync(credPath)) return null;
    const parsed = JSON.parse(readFileSync(credPath, "utf8"));
    const creds = parsed.claudeAiOauth || parsed;
    if (creds.accessToken) return creds;
  } catch { /* ignore */ }
  return null;
}

function fetchRateLimits(accessToken) {
  return new Promise((res) => {
    const req = https.request({
      hostname: "api.anthropic.com",
      path: "/api/oauth/usage",
      method: "GET",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "anthropic-beta": "oauth-2025-04-20",
        "Content-Type": "application/json",
      },
      timeout: 3000,
    }, (resp) => {
      let data = "";
      resp.on("data", (chunk) => { data += chunk; });
      resp.on("end", () => {
        if (resp.statusCode === 200) {
          try { res(JSON.parse(data)); } catch { res(null); }
        } else { res(null); }
      });
    });
    req.on("error", () => res(null));
    req.on("timeout", () => { req.destroy(); res(null); });
    req.end();
  });
}

async function getRateLimitData() {
  const cache = readRateCache();
  if (cache && (Date.now() - cache.timestamp < RATE_CACHE_TTL_MS) && !cache.error) {
    return cache.data;
  }

  const creds = getOAuthCredentials();
  if (!creds?.accessToken) return cache?.data || null;

  const resp = await fetchRateLimits(creds.accessToken);
  if (!resp) {
    writeRateCache(cache?.data || null, true);
    return cache?.data || null;
  }

  const fh = resp?.five_hour?.utilization;
  const wk = resp?.seven_day?.utilization;
  const clamp = (v) => (v == null || !isFinite(v)) ? 0 : Math.max(0, Math.min(100, v));
  const parsed = (fh == null && wk == null) ? null : {
    fiveHourPercent: clamp(fh),
    weeklyPercent: clamp(wk),
    fiveHourResetsAt: resp?.five_hour?.resets_at || null,
    weeklyResetsAt: resp?.seven_day?.resets_at || null,
  };
  writeRateCache(parsed);
  return parsed;
}

// --- Token / Context Display ---
function bar(pct) {
  const width = 8;
  const filled = Math.round((pct / 100) * width);
  const empty = width - filled;
  const color = pct >= 90 ? c.red : pct >= 70 ? c.yellow : c.green;
  return `${c.dim}[${c.reset}${color}${"█".repeat(filled)}${c.dim}${"░".repeat(empty)}${c.reset}${c.dim}]${c.reset}`;
}

function pctColor(pct) { return pct >= 90 ? c.red : pct >= 70 ? c.yellow : c.green; }

function resetInfo(isoStr) {
  if (!isoStr) return "";
  const diffMs = new Date(isoStr) - new Date();
  if (diffMs <= 0) return "";
  const h = Math.floor(diffMs / 3600000);
  const m = Math.floor((diffMs % 3600000) / 60000);
  return h > 0 ? `${h}h${m}m` : `${m}m`;
}

async function getTokenUsage() {
  const parts = [];

  // Rate limits
  try {
    const data = await getRateLimitData();
    if (data) {
      const fh = data.fiveHourPercent ?? 0;
      const wk = data.weeklyPercent ?? 0;
      const fhR = resetInfo(data.fiveHourResetsAt);
      const wkR = resetInfo(data.weeklyResetsAt);
      parts.push(
        `${c.dim}5h${c.reset}${bar(fh)}${pctColor(fh)}${fh}%${c.reset}${fhR ? `${c.dim}(${fhR})${c.reset}` : ""}` +
        ` ${c.dim}wk${c.reset}${bar(wk)}${pctColor(wk)}${wk}%${c.reset}${wkR ? `${c.dim}(${wkR})${c.reset}` : ""}`
      );
    }
  } catch { /* rate limit unavailable */ }

  // Context window & cost
  const ctxParts = [];
  const ctx = _stdinData?.context_window;
  if (ctx?.used_percentage != null) {
    const pct = Math.round(ctx.used_percentage);
    ctxParts.push(`${c.dim}ctx${c.reset}${bar(pct)}${pctColor(pct)}${pct}%${c.reset}`);
  }
  const cost = _stdinData?.cost?.total_cost_usd;
  if (cost != null && cost > 0) {
    ctxParts.push(`${c.dim}$${cost.toFixed(2)}${c.reset}`);
  }
  if (ctxParts.length) parts.push(ctxParts.join(" "));

  return parts.length ? parts.join(" ") : null;
}

// --- Main ---
async function main() {
  const config = loadConfig();
  const sep = ` ${c.dim}|${c.reset} `;

  // Line 1: project | branch | worktree
  const line1 = [];
  if (config.showProjectName) line1.push(getProjectName());
  if (config.showGitBranch) {
    const branch = getGitBranch();
    if (branch) line1.push(branch);
  }
  if (config.showWorktree) {
    const wt = getWorktreeInfo();
    if (wt) line1.push(wt);
  }
  process.stdout.write(`${line1.join(sep)}\n`);

  // Line 2: usage | workflow
  const line2 = [];
  if (config.showTokenUsage) {
    const usage = await getTokenUsage();
    if (usage) line2.push(usage);
  }
  if (config.showWorkflow) {
    line2.push(getWorkflowStatus());
  }
  if (line2.length > 0) {
    process.stdout.write(`${line2.join(sep)}\n`);
  }
}

main();
