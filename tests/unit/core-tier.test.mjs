import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, rmSync, writeFileSync } from "fs";
import { join } from "path";

const ORIG_HOME = process.env.HOME;
const TEST_HOME = join(import.meta.dirname, ".tmp-tier-test");

function setupHome() {
  rmSync(TEST_HOME, { recursive: true, force: true });
  mkdirSync(TEST_HOME, { recursive: true });
  process.env.HOME = TEST_HOME;
}

function teardownHome() {
  process.env.HOME = ORIG_HOME;
  rmSync(TEST_HOME, { recursive: true, force: true });
}

async function freshCalculateTier() {
  const mod = await import(
    `../../scripts/lib/core.mjs?t=${Date.now()}_${Math.random()}`
  );
  return mod.calculateTier();
}

describe("calculateTier", () => {
  before(setupHome);
  after(teardownHome);

  it("returns 0 when no plugins installed", async () => {
    const tier = await freshCalculateTier();
    assert.equal(tier, 0);
  });

  it("returns 1 when a plugin is installed", async () => {
    const pluginDir = join(
      TEST_HOME,
      ".claude/plugins/cache/test-marketplace/test-plugin/1.0.0"
    );
    mkdirSync(pluginDir, { recursive: true });
    const tier = await freshCalculateTier();
    assert.equal(tier, 1);
    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });

  it("returns 1 when another plugin is installed", async () => {
    const pluginDir = join(
      TEST_HOME,
      ".claude/plugins/cache/another-marketplace/another-plugin/0.8.0"
    );
    mkdirSync(pluginDir, { recursive: true });
    const tier = await freshCalculateTier();
    assert.equal(tier, 1);
    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });

  it("returns 2 when plugin + MCP servers exist", async () => {
    const pluginDir = join(
      TEST_HOME,
      ".claude/plugins/cache/another-marketplace/another-plugin/0.8.0"
    );
    mkdirSync(pluginDir, { recursive: true });
    const mcpDir = join(TEST_HOME, ".claude");
    writeFileSync(
      join(mcpDir, "mcp.json"),
      JSON.stringify({
        mcpServers: { "test-server": { command: "echo" } },
      })
    );
    const tier = await freshCalculateTier();
    assert.equal(tier, 2);
    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });
});
