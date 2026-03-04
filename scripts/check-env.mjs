#!/usr/bin/env node
/**
 * CCH Environment Check (LW: replaces HRP 4-Phase scanner)
 *
 * Single-phase environment scan:
 *   1. Check installed plugins (superpowers, etc.)
 *   2. Check MCP server availability
 *   3. Check CLI tools (optional)
 *   4. Determine Tier (0/1/2)
 *   5. Output capabilities summary
 *
 * Can be used as:
 *   - CLI: node scripts/check-env.mjs
 *   - Hook: stdin JSON → stdout hook response
 *   - Module: import { checkEnv } from './check-env.mjs'
 */

import { existsSync, readdirSync, readFileSync } from "fs";
import { join } from "path";
import { calculateTier, writeState, readManifest } from "./lib/core.mjs";

/**
 * Detect installed plugins by scanning the plugin cache directory.
 * @returns {Array<{name: string, version: string, path: string}>}
 */
function detectPlugins() {
  const plugins = [];
  const cacheDir = join(process.env.HOME || "", ".claude/plugins/cache");

  if (!existsSync(cacheDir)) return plugins;

  try {
    for (const marketplace of readdirSync(cacheDir)) {
      const marketDir = join(cacheDir, marketplace);
      for (const pluginName of readdirSync(marketDir)) {
        const pluginDir = join(marketDir, pluginName);
        // Find version directories
        for (const version of readdirSync(pluginDir)) {
          const versionDir = join(pluginDir, version);
          if (existsSync(join(versionDir, "skills"))) {
            plugins.push({ name: pluginName, version, path: versionDir });
          }
        }
      }
    }
  } catch {
    // Permission or access errors
  }

  return plugins;
}

/**
 * Detect MCP servers from configuration.
 * @returns {Array<{name: string, command: string}>}
 */
function detectMcpServers() {
  const servers = [];
  const mcpConfig = join(process.env.HOME || "", ".claude/mcp.json");

  try {
    const config = JSON.parse(readFileSync(mcpConfig, "utf8"));
    for (const [name, server] of Object.entries(config.mcpServers || {})) {
      servers.push({ name, command: server.command || "unknown" });
    }
  } catch {
    // No MCP config
  }

  return servers;
}

/**
 * Run full environment check.
 * @returns {{ tier: number, plugins: Array, mcpServers: Array, capabilities: object }}
 */
export function checkEnv() {
  const plugins = detectPlugins();
  const mcpServers = detectMcpServers();
  const tier = calculateTier();
  const manifest = readManifest();

  // Build capability map from detected sources
  const capabilities = {};

  // 1) Static sources from capabilities.json
  for (const [srcName, srcDef] of Object.entries(manifest.sources || {})) {
    const detected = plugins.some((p) => p.name === srcName);
    capabilities[srcName] = {
      ...srcDef,
      detected,
      tier_contribution: detected ? 1 : 0,
    };
  }

  // 2) Auto-register: plugins not in capabilities.json
  for (const plugin of plugins) {
    if (!capabilities[plugin.name]) {
      capabilities[plugin.name] = {
        type: "plugin",
        description: `Auto-detected plugin: ${plugin.name}@${plugin.version}`,
        required: false,
        detected: true,
        tier_contribution: 1,
        auto_detected: true,
      };
    }
  }

  return { tier, plugins, mcpServers, capabilities };
}

// --- CLI / Hook entry point (only when run directly) ---

const isDirectRun = process.argv[1]?.endsWith("check-env.mjs");
if (!isDirectRun) {
  // Imported as module — skip CLI logic
} else {

const args = process.argv.slice(2);
const isHook = args[0] !== "--cli" && !process.stdin.isTTY;

if (isHook) {
  // Running as hook — read stdin, output hook JSON
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", () => {
    const env = checkEnv();

    // Write tier to state
    writeState("tier", String(env.tier));

    // Build hook response
    const context = [
      `[CCH ENV] Tier ${env.tier}`,
      `Plugins: ${env.plugins.map((p) => p.name).join(", ") || "none"}`,
      `MCP: ${env.mcpServers.map((s) => s.name).join(", ") || "none"}`,
    ].join(" | ");

    console.log(
      JSON.stringify({
        continue: true,
        hookSpecificOutput: {
          hookEventName: "UserPromptSubmit",
          additionalContext: context,
        },
      })
    );
  });
} else {
  // Running as CLI
  const env = checkEnv();
  writeState("tier", String(env.tier));

  console.log("=== CCH Environment Check ===");
  console.log(`Tier: ${env.tier}`);
  console.log(
    `Plugins: ${env.plugins.map((p) => `${p.name}@${p.version}`).join(", ") || "none"}`
  );
  console.log(
    `MCP Servers: ${env.mcpServers.map((s) => s.name).join(", ") || "none"}`
  );
  console.log("\nCapabilities:");
  for (const [name, cap] of Object.entries(env.capabilities)) {
    console.log(
      `  ${cap.detected ? "✓" : "✗"} ${name}: ${cap.description || ""}`
    );
  }
}

} // end isDirectRun guard
