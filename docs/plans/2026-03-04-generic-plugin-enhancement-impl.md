# Generic Plugin Enhancement System — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** CCH Tier 시스템을 generic화하여 어떤 플러그인이든 설치되면 자동으로 인식되게 한다.

**Architecture:** `calculateTier()`를 하드코딩에서 dynamic plugin cache 스캔으로 변경. `checkEnv()`에 auto-register 로직 추가로 capabilities.json에 없는 플러그인도 동적 등록. 기존 Enhancement 섹션은 그대로 유지.

**Tech Stack:** Bash (bin/cch), Node.js ESM (scripts/lib/core.mjs, scripts/check-env.mjs), Node.js built-in test runner

---

### Task 1: Generic `calculateTier()` in core.mjs

**Files:**
- Modify: `scripts/lib/core.mjs:56-82` (calculateTier function)
- Test: `tests/unit/core-tier.test.mjs`

**Step 1: Write the failing test**

Create `tests/unit/core-tier.test.mjs`:

```javascript
import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, rmSync, writeFileSync, existsSync } from "fs";
import { join } from "path";

// We test calculateTier() by manipulating HOME to a temp directory
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

// Dynamic import to pick up env changes
async function freshCalculateTier() {
  // Force re-evaluation by importing with cache-bust query
  const mod = await import(`../../scripts/lib/core.mjs?t=${Date.now()}_${Math.random()}`);
  return mod.calculateTier();
}

describe("calculateTier", () => {
  before(setupHome);
  after(teardownHome);

  it("returns 0 when no plugins installed", async () => {
    const tier = await freshCalculateTier();
    assert.equal(tier, 0);
  });

  it("returns 1 when superpowers plugin is installed", async () => {
    const pluginDir = join(TEST_HOME, ".claude/plugins/cache/superpowers-marketplace/superpowers/1.0.0");
    mkdirSync(pluginDir, { recursive: true });
    const tier = await freshCalculateTier();
    assert.equal(tier, 1);
    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });

  it("returns 1 when any non-superpowers plugin is installed", async () => {
    const pluginDir = join(TEST_HOME, ".claude/plugins/cache/gptaku-plugins/kkirikkiri/0.8.0");
    mkdirSync(pluginDir, { recursive: true });
    const tier = await freshCalculateTier();
    assert.equal(tier, 1);
    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });

  it("returns 2 when plugin + MCP servers exist", async () => {
    const pluginDir = join(TEST_HOME, ".claude/plugins/cache/gptaku-plugins/kkirikkiri/0.8.0");
    mkdirSync(pluginDir, { recursive: true });
    const mcpDir = join(TEST_HOME, ".claude");
    writeFileSync(join(mcpDir, "mcp.json"), JSON.stringify({
      mcpServers: { "test-server": { command: "echo" } }
    }));
    const tier = await freshCalculateTier();
    assert.equal(tier, 2);
    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });
});
```

**Step 2: Run test to verify it fails**

Run: `node --test tests/unit/core-tier.test.mjs`
Expected: FAIL — "returns 1 when any non-superpowers plugin is installed" fails (gets 0 instead of 1)

**Step 3: Write minimal implementation**

Replace `calculateTier()` in `scripts/lib/core.mjs:56-82`:

```javascript
export function calculateTier() {
  let tier = 0;

  // Check any installed plugin (generic detection)
  const cacheDir = join(process.env.HOME || "", ".claude/plugins/cache");
  if (existsSync(cacheDir)) {
    try {
      const marketplaces = readdirSync(cacheDir);
      const hasPlugins = marketplaces.some((mp) => {
        const mpDir = join(cacheDir, mp);
        try {
          return readdirSync(mpDir).length > 0;
        } catch {
          return false;
        }
      });
      if (hasPlugins) tier = 1;
    } catch {
      // Permission or access errors
    }
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
```

**Step 4: Run test to verify it passes**

Run: `node --test tests/unit/core-tier.test.mjs`
Expected: PASS — all 4 tests pass

**Step 5: Commit**

```bash
git add scripts/lib/core.mjs tests/unit/core-tier.test.mjs
git commit -m "feat: generic calculateTier() — detect any plugin, not just superpowers"
```

**의존:** 없음

---

### Task 2: Generic `_calculate_tier()` in bin/cch

**Files:**
- Modify: `bin/cch:86-108` (_calculate_tier function)
- Test: `tests/test_contract.sh` (기존 + 추가)

**Step 1: Write the failing test**

Append to `tests/test_contract.sh`:

```bash
# --- Tier detection (generic) ---
# _calculate_tier is internal, so test via 'cch setup' output
# The real assertion is that Tier is detected regardless of which plugin exists.
# Since we can't mock the filesystem in bash, verify the existing contract still holds:
out="$($CCH setup 2>&1)"
assert_contains "setup: tier is numeric" "Tier detected:" "$out"
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/test.sh contract`
Expected: PASS (this is a contract test — should pass before and after change)

**Step 3: Write minimal implementation**

Replace `_calculate_tier()` in `bin/cch` (lines 91-108):

```bash
# --- Tier System ---
# Tier 0: CCH core only (no plugins)
# Tier 1: CCH + any plugin (superpowers, gptaku, etc.)
# Tier 2: CCH + any plugin + extensions (MCP, etc.)

_calculate_tier() {
  local tier=0

  # Check any installed plugin (generic detection)
  local cache_dir="$HOME/.claude/plugins/cache"
  if [[ -d "$cache_dir" ]]; then
    local plugin_count
    plugin_count=$(find "$cache_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$plugin_count" -gt 0 ]]; then
      tier=1
    fi
  fi

  # Check additional extensions (MCP servers, etc.)
  if [[ $tier -ge 1 ]]; then
    local mcp_config="$HOME/.claude/mcp.json"
    if [[ -f "$mcp_config" ]] && command -v node &>/dev/null; then
      local server_count
      server_count=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('$mcp_config','utf8'));console.log(Object.keys(c.mcpServers||{}).length)}catch{console.log(0)}" 2>/dev/null || echo "0")
      if [[ "$server_count" -gt 0 ]]; then
        tier=2
      fi
    fi
  fi

  echo "$tier"
}
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/test.sh contract`
Expected: PASS — existing contract tests + new tier assertion pass

**Step 5: Commit**

```bash
git add bin/cch tests/test_contract.sh
git commit -m "feat: generic _calculate_tier() in bin/cch — detect any plugin"
```

**의존:** 없음

---

### Task 3: Auto-register capabilities in check-env.mjs

**Files:**
- Modify: `scripts/check-env.mjs:77-95` (checkEnv function)
- Test: `tests/unit/check-env.test.mjs`

**Step 1: Write the failing test**

Create `tests/unit/check-env.test.mjs`:

```javascript
import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, rmSync, writeFileSync } from "fs";
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
  const mod = await import(`../../scripts/check-env.mjs?t=${Date.now()}_${Math.random()}`);
  return mod.checkEnv();
}

describe("checkEnv auto-register", () => {
  before(setupHome);
  after(teardownHome);

  it("auto-registers unknown plugins in capabilities", async () => {
    // Create a fake plugin that's NOT in capabilities.json
    const pluginDir = join(TEST_HOME, ".claude/plugins/cache/test-marketplace/test-plugin/1.0.0/skills");
    mkdirSync(pluginDir, { recursive: true });

    const env = await freshCheckEnv();

    // Should be in capabilities with auto_detected flag
    assert.ok(env.capabilities["test-plugin"], "test-plugin should be in capabilities");
    assert.equal(env.capabilities["test-plugin"].auto_detected, true);
    assert.equal(env.capabilities["test-plugin"].detected, true);
    assert.equal(env.capabilities["test-plugin"].type, "plugin");

    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });

  it("keeps static capabilities.json entries for known plugins", async () => {
    // Create superpowers plugin (which IS in capabilities.json)
    const pluginDir = join(TEST_HOME, ".claude/plugins/cache/superpowers-marketplace/superpowers/4.0.0/skills");
    mkdirSync(pluginDir, { recursive: true });

    const env = await freshCheckEnv();

    // superpowers should be from static config, NOT auto_detected
    assert.ok(env.capabilities["superpowers"], "superpowers should be in capabilities");
    assert.equal(env.capabilities["superpowers"].detected, true);
    assert.equal(env.capabilities["superpowers"].auto_detected, undefined);

    rmSync(join(TEST_HOME, ".claude"), { recursive: true, force: true });
  });
});
```

**Step 2: Run test to verify it fails**

Run: `node --test tests/unit/check-env.test.mjs`
Expected: FAIL — "test-plugin should be in capabilities" assertion fails

**Step 3: Write minimal implementation**

Replace `checkEnv()` in `scripts/check-env.mjs:77-95`:

```javascript
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
```

**Step 4: Run test to verify it passes**

Run: `node --test tests/unit/check-env.test.mjs`
Expected: PASS — both tests pass

**Step 5: Commit**

```bash
git add scripts/check-env.mjs tests/unit/check-env.test.mjs
git commit -m "feat: auto-register unknown plugins in capabilities"
```

**의존:** Task 1 (calculateTier 변경이 check-env.mjs에 import됨)

---

### Task 4: Full integration test

**Files:**
- Test: `tests/test_contract.sh` (기존 tier assertion 검증)
- Test: all node unit tests

**Step 1: Run full test suite**

Run: `bash scripts/test.sh all`
Expected: All layers pass, including contract, node_unit

**Step 2: Run check-env CLI to verify output**

Run: `node scripts/check-env.mjs --cli`
Expected: Output shows all installed plugins (superpowers, kkirikkiri, claude-code-harness) with detected capabilities

**Step 3: Verify tier state**

Run: `bash bin/cch setup && bash bin/cch status`
Expected: Tier >= 1 (reflecting installed plugins)

**Step 4: Commit (no changes expected — verification only)**

If any test fixes needed, commit them:
```bash
git add -A
git commit -m "test: verify generic plugin enhancement integration"
```

**의존:** Task 1, Task 2, Task 3
