#!/usr/bin/env bash
# Layer 5: Resilience - source 미가용 시 health/fallback 판정 검증

CCH="bash $ROOT_DIR/bin/cch"
$CCH setup --no-fetch &>/dev/null

# Code mode: resolve and check health
$CCH mode code &>/dev/null
out="$($CCH status 2>&1)"
assert_contains "resilience: code mode shows health" "Health" "$out"

# Status output contains source info
assert_contains "resilience: sources section shown" "Sources" "$out"

# Verify health state file exists after resolve
assert_file_exists "resilience: health state file exists" "$CCH_STATE_DIR/health"
health="$(cat "$CCH_STATE_DIR/health")"
assert_contains "resilience: health is valid value" "$health" "Healthy Degraded Blocked"

# DOT fallback: compiled from local sources (code mode only)
$CCH dot on &>/dev/null 2>&1
out="$($CCH dot status 2>&1)"
assert_contains "resilience: DOT status shows Compiled field" "Compiled:" "$out"
$CCH dot off &>/dev/null 2>&1

# Rollback creates and restores state
$CCH update apply &>/dev/null
rollback_id="$(ls -1 "$CCH_STATE_DIR/rollbacks" 2>/dev/null | tail -1)"
if [[ -n "$rollback_id" ]]; then
  out="$($CCH update rollback "$rollback_id" 2>&1)"
  assert_contains "resilience: rollback runs verification" "Verification" "$out"
else
  assert_contains "resilience: rollback point created" "SHOULD_HAVE_ID" ""
fi

# Status --json returns valid JSON
out="$($CCH status --json 2>&1)"
assert_contains "resilience: json has mode" '"mode"' "$out"
assert_contains "resilience: json has health" '"health"' "$out"
assert_contains "resilience: json has resolved" '"resolved"' "$out"

# Resolved state.json exists and is valid
assert_file_exists "resilience: resolved state exists" "$CCH_STATE_DIR/.resolved/state.json"
resolved="$(cat "$CCH_STATE_DIR/.resolved/state.json")"
assert_contains "resilience: resolved has available array" '"available"' "$resolved"
assert_contains "resilience: resolved has health" '"health"' "$resolved"
