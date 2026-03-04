#!/usr/bin/env bash
# v2 Workflow - setup→mode→status→beads 워크플로우 검증

CCH="bash $ROOT_DIR/bin/cch"

# Full lifecycle
out="$($CCH setup 2>&1)"
assert_contains "workflow: setup succeeds" "Setup complete" "$out"

out="$($CCH mode plan 2>&1)"
assert_contains "workflow: plan mode" "Mode changed" "$out"

out="$($CCH mode code 2>&1)"
assert_contains "workflow: code mode" "Mode changed" "$out"

out="$($CCH status 2>&1)"
assert_contains "workflow: status shows code" "code" "$out"

# --- Plan mode creates plan doc ---
$CCH mode plan &>/dev/null
out="$($CCH status 2>&1)"
assert_contains "workflow: plan mode in status" "plan" "$out"

# --- Back to code ---
$CCH mode code &>/dev/null
out="$($CCH mode 2>&1)"
assert_contains "workflow: back to code" "code" "$out"

# --- Beads workflow ---
out="$(bash "$ROOT_DIR/bin/cch" beads list 2>&1)" || true
assert_not_contains "beads list: no crash" "command not found" "$out"

# --- Status JSON reflects mode ---
$CCH mode code &>/dev/null
out="$($CCH status --json 2>&1)"
assert_contains "status json: reflects code mode" '"code"' "$out"

$CCH mode plan &>/dev/null
out="$($CCH status --json 2>&1)"
assert_contains "status json: reflects plan mode" '"plan"' "$out"

# Reset
$CCH mode code &>/dev/null
