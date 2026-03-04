#!/usr/bin/env bash
# Layer 1: Contract - slash command 계약/인자/매핑 검증

CCH="bash $ROOT_DIR/bin/cch"

# Setup first
$CCH setup &>/dev/null

# --- cch-setup ---
out="$($CCH setup 2>&1)"
assert_contains "setup: outputs version" "Setting up" "$out"
assert_contains "setup: creates state dir" "State dir" "$out"

# --- cch-mode ---
out="$($CCH mode code 2>&1)"
assert_contains "mode code: accepted" "Mode changed" "$out"

out="$($CCH mode plan 2>&1)"
assert_contains "mode plan: accepted" "Mode changed" "$out"

out="$($CCH mode tool 2>&1)"
assert_contains "mode tool: accepted" "Mode changed" "$out"

out="$($CCH mode swarm 2>&1)"
assert_contains "mode swarm: accepted" "Mode changed" "$out"

# Invalid mode
out="$($CCH mode invalid 2>&1)" || true
assert_contains "mode invalid: rejected" "ERROR" "$out"

# No argument = show current
out="$($CCH mode 2>&1)"
assert_contains "mode (no arg): shows current" "Current mode" "$out"

# --- cch-status ---
out="$($CCH doctor --summary 2>&1)"
assert_contains "doctor: shows version" "Version" "$out"
assert_contains "doctor: shows mode" "Mode" "$out"
assert_contains "doctor: shows health" "Health" "$out"
assert_contains "doctor: shows DOT" "DOT" "$out"

# --- cch-dot ---
$CCH mode code &>/dev/null
out="$($CCH dot on 2>&1)"
assert_contains "dot on: accepted in code mode" "DOT experiment: ON" "$out"

out="$($CCH dot off 2>&1)"
assert_contains "dot off: accepted" "DOT experiment: OFF" "$out"

$CCH mode plan &>/dev/null
out="$($CCH dot on 2>&1)" || true
assert_contains "dot on: rejected in plan mode" "ERROR" "$out"

# --- cch-update ---
out="$($CCH update check 2>&1)"
assert_contains "update check: shows version" "Current version" "$out"
