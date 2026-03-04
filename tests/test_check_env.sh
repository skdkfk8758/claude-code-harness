#!/usr/bin/env bash
# Layer 2: check-env - scripts/check-env.mjs 환경 스캔 및 출력 검증

CHECK_ENV="node $ROOT_DIR/scripts/check-env.mjs"

# --- CLI mode (--cli flag) ---
out="$($CHECK_ENV --cli 2>&1)"
assert_contains "check-env cli: shows header" "CCH Environment Check" "$out"
assert_contains "check-env cli: shows tier" "Tier:" "$out"
assert_contains "check-env cli: shows plugins line" "Plugins:" "$out"
assert_contains "check-env cli: shows mcp servers line" "MCP Servers:" "$out"
assert_contains "check-env cli: shows capabilities section" "Capabilities:" "$out"

# --- Tier state is written ---
tier_file="$CCH_STATE_DIR/tier"
assert_file_exists "check-env cli: tier state file created" "$tier_file"
tier_value="$(cat "$tier_file" | tr -d '[:space:]')"
assert_contains "check-env cli: tier is a number" "$tier_value" "0 1 2"

# --- Hook mode (piped stdin, non-TTY) ---
hook_out="$(echo '{}' | $CHECK_ENV 2>&1)"
assert_contains "check-env hook: output is JSON with continue" '"continue":true' "$hook_out"
assert_contains "check-env hook: has hookSpecificOutput" '"hookSpecificOutput"' "$hook_out"
assert_contains "check-env hook: has hookEventName" '"UserPromptSubmit"' "$hook_out"
assert_contains "check-env hook: has additionalContext" '"additionalContext"' "$hook_out"
assert_contains "check-env hook: context contains CCH ENV" "CCH ENV" "$hook_out"
assert_contains "check-env hook: context contains Tier" "Tier" "$hook_out"

# --- Plugin detection with mock directory ---
MOCK_HOME="$(mktemp -d)"
MOCK_CACHE="$MOCK_HOME/.claude/plugins/cache"
mkdir -p "$MOCK_CACHE/test-marketplace/test-plugin/1.0.0/skills"

plugin_out="$(HOME="$MOCK_HOME" $CHECK_ENV --cli 2>&1)"
assert_contains "check-env plugin: detects mock plugin" "test-plugin" "$plugin_out"
assert_contains "check-env plugin: shows version" "1.0.0" "$plugin_out"

# --- No plugins = shows 'none' ---
EMPTY_HOME="$(mktemp -d)"
mkdir -p "$EMPTY_HOME/.claude/plugins/cache"

noplugin_out="$(HOME="$EMPTY_HOME" $CHECK_ENV --cli 2>&1)"
assert_contains "check-env no-plugin: shows none for plugins" "none" "$noplugin_out"

# --- MCP server detection with mock config ---
MOCK_MCP_HOME="$(mktemp -d)"
mkdir -p "$MOCK_MCP_HOME/.claude"
cat > "$MOCK_MCP_HOME/.claude/mcp.json" <<'MCPJSON'
{
  "mcpServers": {
    "mock-serena": { "command": "npx serena" },
    "mock-context7": { "command": "npx context7" }
  }
}
MCPJSON

mcp_out="$(HOME="$MOCK_MCP_HOME" $CHECK_ENV --cli 2>&1)"
assert_contains "check-env mcp: detects serena server" "mock-serena" "$mcp_out"
assert_contains "check-env mcp: detects context7 server" "mock-context7" "$mcp_out"

# --- No MCP config = shows 'none' ---
nomcp_out="$(HOME="$EMPTY_HOME" $CHECK_ENV --cli 2>&1)"
assert_contains "check-env no-mcp: shows none for mcp" "none" "$nomcp_out"

# --- Capabilities section lists manifest sources ---
cap_out="$($CHECK_ENV --cli 2>&1)"
assert_contains "check-env caps: lists superpowers" "superpowers" "$cap_out"

# --- Hook mode context format: pipe-separated ---
hook_ctx="$(echo '{}' | $CHECK_ENV 2>&1)"
assert_contains "check-env hook-fmt: pipe-separated context" "|" "$hook_ctx"
assert_contains "check-env hook-fmt: Plugins in context" "Plugins:" "$hook_ctx"
assert_contains "check-env hook-fmt: MCP in context" "MCP:" "$hook_ctx"

# Cleanup mock directories
rm -rf "$MOCK_HOME" "$EMPTY_HOME" "$MOCK_MCP_HOME" 2>/dev/null
