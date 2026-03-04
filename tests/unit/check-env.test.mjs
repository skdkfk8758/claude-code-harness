import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";

const ORIG_HOME = process.env.HOME;
const TEST_HOME = join(import.meta.dirname, ".tmp-checkenv-test");

function setupHome() {
  rmSync(TEST_HOME, { recursive: true, force: true });
  mkdirSync(TEST_HOME, { recursive: true });
  process.env.HOME = TEST_HOME;
}

function teardownHome() {
  process.env.HOME = ORIG_HOME;
  rmSync(TEST_HOME, { recursive: true, force: true });
}

async function freshCheckEnv() {
  const mod = await import(
    `../../scripts/check-env.mjs?t=${Date.now()}_${Math.random()}`
  );
  return mod.checkEnv();
}

describe("checkEnv auto-register", () => {
  before(setupHome);
  after(teardownHome);

  it("auto-registers unknown plugins in capabilities", async () => {
    const pluginDir = join(
      TEST_HOME,
      ".claude/plugins/cache/test-marketplace/test-plugin/1.0.0/skills"
    );
    mkdirSync(pluginDir, { recursive: true });

    const env = await freshCheckEnv();

    assert.ok(
      env.capabilities["test-plugin"],
      "test-plugin should be in capabilities"
    );
    assert.equal(env.capabilities["test-plugin"].auto_detected, true);
    assert.equal(env.capabilities["test-plugin"].detected, true);
    assert.equal(env.capabilities["test-plugin"].type, "plugin");

    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });

  it("keeps static capabilities.json entries for known plugins", async () => {
    const pluginDir = join(
      TEST_HOME,
      ".claude/plugins/cache/superpowers-marketplace/superpowers/4.0.0/skills"
    );
    mkdirSync(pluginDir, { recursive: true });

    const env = await freshCheckEnv();

    assert.ok(
      env.capabilities["superpowers"],
      "superpowers should be in capabilities"
    );
    assert.equal(env.capabilities["superpowers"].detected, true);
    assert.equal(env.capabilities["superpowers"].auto_detected, undefined);

    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });
});
