#!/usr/bin/env node
/**
 * CCH HUD - Claude Code Harness Statusline
 * Reads CCH framework state and displays status elements.
 *
 * Output format:
 *   [CCH:code] Healthy | WI:w-p0(doing) | DOT:off
 *
 * Config: ~/.claude/hud/cch-hud-config.json
 */

import { existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";
import { execSync } from "node:child_process";
import https from "node:https";
import { join, dirname, basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// --- Read stdin (session context from Claude Code) ---
let _stdinData = {};
try {
  const raw = readFileSync(0, "utf8").trim();
  if (raw) {
    _stdinData = JSON.parse(raw);
  }
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
    showMode: true,
    showHealth: true,
    showWorkItem: true,
    showDot: true,
    showLastActivity: true,
    showSummary: true,
    showPhase: false,
    cchStateDir: ".claude/cch",
  };
  try {
    if (existsSync(configPath)) {
      const raw = JSON.parse(readFileSync(configPath, "utf8"));
      return { ...defaults, ...raw };
    }
  } catch { /* use defaults */ }
  return defaults;
}

// --- CCH State Readers ---
function readFile(path) {
  try {
    return existsSync(path) ? readFileSync(path, "utf8").trim() : "";
  } catch { return ""; }
}

function findCchStateDir() {
  // Try CWD first, then walk up to find .claude/cch
  const candidates = [
    join(process.cwd(), ".claude", "cch"),
    join(process.env.CCH_STATE_DIR || ""),
  ];
  for (const dir of candidates) {
    if (dir && existsSync(dir)) return dir;
  }
  return "";
}

function getCchMode(stateDir) {
  const mode = readFile(join(stateDir, "mode"));
  if (!mode) return null;
  const colors = { plan: c.magenta, code: c.cyan, tool: c.yellow, swarm: c.green };
  const color = colors[mode] || c.white;
  return `${c.bold}[CCH:${color}${mode}${c.reset}${c.bold}]${c.reset}`;
}

function getCchHealth(stateDir) {
  const health = readFile(join(stateDir, "health"));
  if (!health) return null;
  const reason = readFile(join(stateDir, "health_reason"));
  const colors = { Healthy: c.green, Degraded: c.yellow, Blocked: c.red };
  const color = colors[health] || c.dim;
  let label = `${color}${health}${c.reset}`;
  if (health === "Degraded" && reason) {
    const shortReason = reason.split(",")[0].split(":")[0];
    label += `${c.dim}(${shortReason})${c.reset}`;
  }
  return label;
}

function getActiveWorkItem(stateDir) {
  const workDir = join(stateDir, "work-items");
  if (!existsSync(workDir)) return null;

  try {
    const items = readdirSync(workDir);
    for (const item of items) {
      const todoFile = join(workDir, item, "todo.yaml");
      if (!existsSync(todoFile)) continue;
      const content = readFileSync(todoFile, "utf8");
      const statusMatch = content.match(/^status:\s*(.+)$/m);
      if (statusMatch && statusMatch[1].trim() === "doing") {
        return `${c.cyan}WI:${item}${c.dim}(doing)${c.reset}`;
      }
    }
  } catch { /* ignore */ }
  return null;
}

function getLastActivity(stateDir) {
  const raw = readFile(join(stateDir, "last_activity"));
  if (!raw) return null;
  const maxLen = 30;
  if (raw.startsWith("done: ")) {
    const text = raw.slice(6);
    const display = text.length > maxLen ? text.slice(0, maxLen - 1) + "\u2026" : text;
    return `${c.green}ok:${c.reset}${c.dim}${display}${c.reset}`;
  }
  const display = raw.length > maxLen ? raw.slice(0, maxLen - 1) + "\u2026" : raw;
  return `${c.yellow}>>${c.reset} ${display}`;
}

/** Read Q&A summary from per-session directory, fallback to global, then most recent session */
function getLastSummaryLines(stateDir, sessionId) {
  const candidates = [];

  // 1. Per-session file (preferred)
  if (sessionId) {
    candidates.push(join(stateDir, "sessions", sessionId, "last_summary"));
  }

  // 2. Global fallback
  candidates.push(join(stateDir, "last_summary"));

  // 3. Any existing session summary (last resort)
  const sessionsDir = join(stateDir, "sessions");
  if (existsSync(sessionsDir)) {
    try {
      const dirs = readdirSync(sessionsDir);
      for (const dir of dirs) {
        const summaryPath = join(sessionsDir, dir, "last_summary");
        if (existsSync(summaryPath)) {
          candidates.push(summaryPath);
        }
      }
    } catch { /* ignore */ }
  }

  // Try each candidate in order
  for (const filePath of candidates) {
    const raw = readFile(filePath);
    if (!raw) continue;

    const lines = raw.split("\n");
    const q = (lines[0] || "").trim();
    const a = (lines[1] || "").trim();
    const result = [];
    if (q) result.push(`${c.cyan}Q:${c.reset} ${q}`);
    if (a && a !== "done") {
      result.push(`${c.green}A:${c.reset} ${a}`);
    } else if (a === "done") {
      result.push(`${c.green}A:${c.reset} ${c.dim}done${c.reset}`);
    }
    if (result.length > 0) return result;
  }

  return null;
}

/** Cleanup stale session directories (older than 24 hours) */
function cleanupStaleSessions(stateDir, currentSessionId) {
  const sessionsDir = join(stateDir, "sessions");
  if (!existsSync(sessionsDir)) return;
  const maxAgeMs = 24 * 60 * 60 * 1000;
  const now = Date.now();
  try {
    const dirs = readdirSync(sessionsDir);
    for (const dir of dirs) {
      if (dir === "default") continue;
      if (currentSessionId && dir === currentSessionId) continue;
      const dirPath = join(sessionsDir, dir);
      try {
        const dirStat = statSync(dirPath);
        if (now - dirStat.mtimeMs > maxAgeMs) {
          rmSync(dirPath, { recursive: true });
        }
      } catch { /* ignore */ }
    }
  } catch { /* ignore */ }
}

function getProjectName() {
  const cwd = process.cwd();
  // Try package.json name first
  const pkgPath = join(cwd, "package.json");
  try {
    if (existsSync(pkgPath)) {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
      if (pkg.name) return `${c.bold}${c.white}${pkg.name}${c.reset}`;
    }
  } catch { /* fallback to dirname */ }
  // Fallback to directory name
  return `${c.bold}${c.white}${basename(cwd)}${c.reset}`;
}

function getGitBranch() {
  try {
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 3000,
    }).toString().trim();
    if (!branch) return null;
    return `${c.magenta}${branch}${c.reset}`;
  } catch { return null; }
}

function getWorktreeInfo() {
  try {
    const gitDir = execSync("git rev-parse --git-dir", {
      stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
    }).toString().trim();
    const commonDir = execSync("git rev-parse --git-common-dir", {
      stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
    }).toString().trim();

    const resolvedGitDir = resolve(gitDir);
    const resolvedCommonDir = resolve(commonDir);

    // git-dir !== git-common-dir means we're in a worktree
    if (resolvedGitDir !== resolvedCommonDir) {
      const toplevel = execSync("git rev-parse --show-toplevel", {
        stdio: ["pipe", "pipe", "pipe"], timeout: 3000,
      }).toString().trim();
      const wtName = basename(toplevel);
      return `${c.yellow}wt:${wtName}${c.reset}`;
    }
  } catch { /* not in a git repo */ }
  return null;
}

function getDotStatus(stateDir) {
  const enabled = readFile(join(stateDir, "dot_enabled"));
  if (enabled === "true") {
    return `${c.green}DOT:on${c.reset}`;
  }
  return `${c.dim}DOT:off${c.reset}`;
}

// --- Rate Limit API ---
const RATE_CACHE_PATH = join(process.env.HOME || "", ".claude", "hud", ".rate-limit-cache.json");
const RATE_CACHE_TTL_MS = 30_000; // 30s

function readRateCache() {
  try {
    if (!existsSync(RATE_CACHE_PATH)) return null;
    const raw = JSON.parse(readFileSync(RATE_CACHE_PATH, "utf8"));
    return raw;
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
  // 1. macOS Keychain
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
  // 2. File fallback
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
  return new Promise((resolve) => {
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
    }, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        if (res.statusCode === 200) {
          try { resolve(JSON.parse(data)); } catch { resolve(null); }
        } else { resolve(null); }
      });
    });
    req.on("error", () => resolve(null));
    req.on("timeout", () => { req.destroy(); resolve(null); });
    req.end();
  });
}

function parseRateLimits(resp) {
  const fh = resp?.five_hour?.utilization;
  const wk = resp?.seven_day?.utilization;
  if (fh == null && wk == null) return null;
  const clamp = (v) => (v == null || !isFinite(v)) ? 0 : Math.max(0, Math.min(100, v));
  return {
    fiveHourPercent: clamp(fh),
    weeklyPercent: clamp(wk),
    fiveHourResetsAt: resp?.five_hour?.resets_at || null,
    weeklyResetsAt: resp?.seven_day?.resets_at || null,
  };
}

async function getRateLimitData() {
  // Check cache
  const cache = readRateCache();
  if (cache && (Date.now() - cache.timestamp < RATE_CACHE_TTL_MS) && !cache.error) {
    return cache.data;
  }

  // Fetch fresh data
  const creds = getOAuthCredentials();
  if (!creds?.accessToken) {
    // No creds: use stale cache if available
    return cache?.data || null;
  }

  const resp = await fetchRateLimits(creds.accessToken);
  if (!resp) {
    writeRateCache(cache?.data || null, true);
    return cache?.data || null;
  }

  const parsed = parseRateLimits(resp);
  writeRateCache(parsed);
  return parsed;
}

// --- Token Usage ---
async function getTokenUsage(stdinData) {
  const parts = [];

  const bar = (pct) => {
    const width = 8;
    const filled = Math.round((pct / 100) * width);
    const empty = width - filled;
    let color = c.green;
    if (pct >= 90) color = c.red;
    else if (pct >= 70) color = c.yellow;
    return `${c.dim}[${c.reset}${color}${"█".repeat(filled)}${c.dim}${"░".repeat(empty)}${c.reset}${c.dim}]${c.reset}`;
  };

  const pctColor = (pct) => pct >= 90 ? c.red : pct >= 70 ? c.yellow : c.green;

  // 1. Rate limits from API (with cache)
  try {
    const data = await getRateLimitData();
    if (data) {
      const fh = data.fiveHourPercent ?? 0;
      const wk = data.weeklyPercent ?? 0;

      const resetInfo = (isoStr) => {
        if (!isoStr) return "";
        const d = new Date(isoStr);
        const now = new Date();
        const diffMs = d - now;
        if (diffMs <= 0) return "";
        const h = Math.floor(diffMs / 3600000);
        const m = Math.floor((diffMs % 3600000) / 60000);
        if (h > 0) return `${h}h${m}m`;
        return `${m}m`;
      };

      const fhReset = resetInfo(data.fiveHourResetsAt);
      const wkReset = resetInfo(data.weeklyResetsAt);

      parts.push(`${c.dim}5h${c.reset}${bar(fh)}${pctColor(fh)}${fh}%${c.reset}${fhReset ? `${c.dim}(${fhReset})${c.reset}` : ""} ${c.dim}wk${c.reset}${bar(wk)}${pctColor(wk)}${wk}%${c.reset}${wkReset ? `${c.dim}(${wkReset})${c.reset}` : ""}`);
    }
  } catch { /* rate limit unavailable */ }

  return parts.length ? parts.join(" ") : null;
}

// --- Main ---
async function main() {
  const config = loadConfig();
  const stateDir = findCchStateDir();
  const sep = ` ${c.dim}|${c.reset} `;

  // --- Line 1: project_name | branch ---
  const line1Parts = [];

  if (config.showProjectName) {
    line1Parts.push(getProjectName());
  }

  if (config.showGitBranch) {
    const branch = getGitBranch();
    if (branch) line1Parts.push(branch);
  }

  if (config.showWorktree) {
    const wt = getWorktreeInfo();
    if (wt) line1Parts.push(wt);
  }

  process.stdout.write(`${line1Parts.join(sep)}\n`);

  // --- Line 2: limit | ctx | execution_info ---
  const line2Parts = [];

  // Rate limits
  if (config.showTokenUsage) {
    const usage = await getTokenUsage(_stdinData);
    if (usage) line2Parts.push(usage);
  }

  // Context window & cost
  if (config.showTokenUsage) {
    const ctxParts = [];
    const ctxBar = (pct) => {
      const width = 8;
      const filled = Math.round((pct / 100) * width);
      const empty = width - filled;
      let color = c.green;
      if (pct >= 90) color = c.red;
      else if (pct >= 70) color = c.yellow;
      return `${c.dim}[${c.reset}${color}${"█".repeat(filled)}${c.dim}${"░".repeat(empty)}${c.reset}${c.dim}]${c.reset}`;
    };
    const ctxPctColor = (pct) => pct >= 90 ? c.red : pct >= 70 ? c.yellow : c.green;

    const ctx = _stdinData?.context_window;
    if (ctx?.used_percentage != null) {
      const pct = Math.round(ctx.used_percentage);
      ctxParts.push(`${c.dim}ctx${c.reset}${ctxBar(pct)}${ctxPctColor(pct)}${pct}%${c.reset}`);
    }
    const cost = _stdinData?.cost?.total_cost_usd;
    if (cost != null && cost > 0) {
      ctxParts.push(`${c.dim}$${cost.toFixed(2)}${c.reset}`);
    }
    if (ctxParts.length) line2Parts.push(ctxParts.join(" "));
  }

  // Execution info (mode, health, work item, dot, activity)
  if (stateDir) {
    const execParts = [];
    if (config.showMode) {
      const mode = getCchMode(stateDir);
      if (mode) execParts.push(mode);
    }
    if (config.showHealth) {
      const health = getCchHealth(stateDir);
      if (health) execParts.push(health);
    }
    if (config.showWorkItem) {
      const wi = getActiveWorkItem(stateDir);
      if (wi) execParts.push(wi);
    }
    if (config.showDot) {
      const dot = getDotStatus(stateDir);
      if (dot) execParts.push(dot);
    }
    if (!config.showSummary && config.showLastActivity) {
      const activity = getLastActivity(stateDir);
      if (activity) execParts.push(activity);
    }
    if (execParts.length > 0) {
      line2Parts.push(execParts.join(" "));
    }
  }

  // Phase
  if (config.showPhase && stateDir) {
    const phase = readFile(join(stateDir, "phase"));
    if (phase) line2Parts.push(`${c.yellow}phase:${phase}${c.reset}`);
  }

  if (line2Parts.length > 0) {
    process.stdout.write(`${line2Parts.join(sep)}\n`);
  }

  // Periodic cleanup of stale session directories
  if (stateDir) cleanupStaleSessions(stateDir, _stdinData.session_id || "");
}

main();
