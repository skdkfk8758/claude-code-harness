#!/usr/bin/env bash
# v2 Resilience - 복구력/결함 허용 검증

CCH="bash $ROOT_DIR/bin/cch"
CCH_STATE_DIR="${CCH_STATE_DIR:-$ROOT_DIR/.claude/cch}"

# Setup first
$CCH setup &>/dev/null

# --- Health state persistence ---
$CCH setup &>/dev/null
health="$(cat "$CCH_STATE_DIR/health" 2>/dev/null)"
assert_equals "setup: health state saved" "Healthy" "$health"

# --- Invalid mode rejected ---
out="$($CCH mode invalid 2>&1)" || true
assert_contains "invalid mode: error shown" "ERROR" "$out"

# --- Status works after bad state ---
echo "garbage" > "$CCH_STATE_DIR/mode"
out="$($CCH status 2>&1)"
assert_contains "status: works with bad mode" "Mode" "$out"

# Reset
$CCH mode code &>/dev/null

# --- Setup is idempotent ---
$CCH setup &>/dev/null
$CCH setup &>/dev/null
out="$($CCH status 2>&1)"
assert_contains "double setup: still healthy" "Healthy" "$out"

# --- Cleanup handles missing dirs ---
out="$($CCH setup 2>&1)"
assert_not_contains "setup: no error on clean state" "ERROR" "$out"

# --- status --json is valid JSON ---
out="$($CCH status --json 2>&1)"
if command -v python3 &>/dev/null; then
  if echo "$out" | python3 -c "import sys,json;json.load(sys.stdin)" 2>/dev/null; then
    assert_equals "status --json: valid JSON" "pass" "pass"
  else
    assert_equals "status --json: valid JSON" "pass" "fail"
  fi
fi
