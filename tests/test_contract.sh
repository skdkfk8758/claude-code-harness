#!/usr/bin/env bash
# Layer 1: Contract - v2 bin/cch 명령 계약 검증

CCH="bash $ROOT_DIR/bin/cch"

# Setup first
$CCH setup &>/dev/null

# --- cch setup ---
out="$($CCH setup 2>&1)"
assert_contains "setup: outputs version" "Setting up" "$out"
assert_contains "setup: creates state dir" "State dir" "$out"
assert_contains "setup: detects tier" "Tier detected" "$out"

# --- cch mode ---
out="$($CCH mode code 2>&1)"
assert_contains "mode code: accepted" "Mode changed" "$out"

out="$($CCH mode plan 2>&1)"
assert_contains "mode plan: accepted" "Mode changed" "$out"

# Invalid mode (v2: only plan/code valid)
out="$($CCH mode tool 2>&1)" || true
assert_contains "mode tool: rejected" "ERROR" "$out"

out="$($CCH mode swarm 2>&1)" || true
assert_contains "mode swarm: rejected" "ERROR" "$out"

# No argument = show current
out="$($CCH mode 2>&1)"
assert_contains "mode (no arg): shows current" "Current mode" "$out"

# --- cch status ---
out="$($CCH status 2>&1)"
assert_contains "status: shows version" "Version" "$out"
assert_contains "status: shows mode" "Mode" "$out"
assert_contains "status: shows health" "Health" "$out"
assert_contains "status: shows tier" "Tier" "$out"

# --- cch status --json ---
out="$($CCH status --json 2>&1)"
assert_contains "status --json: has version" "version" "$out"
assert_contains "status --json: has mode" "mode" "$out"
assert_contains "status --json: has tier" "tier" "$out"

# --- cch version ---
out="$($CCH version 2>&1)"
assert_contains "version: outputs version" "cch" "$out"

# --- cch help ---
out="$($CCH help 2>&1)"
assert_contains "help: shows usage" "Usage" "$out"
assert_contains "help: lists setup command" "setup" "$out"
assert_contains "help: lists mode command" "mode" "$out"
assert_contains "help: lists status command" "status" "$out"
