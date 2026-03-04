#!/usr/bin/env bash
# Layer 4: Workflow - setup→plan→code→status→update e2e 검증

CCH="bash $ROOT_DIR/bin/cch"

# Full lifecycle
out="$($CCH setup 2>&1)"
assert_contains "workflow: setup succeeds" "Setup complete" "$out"

out="$($CCH mode plan 2>&1)"
assert_contains "workflow: plan mode" "Mode changed" "$out"

out="$($CCH mode code 2>&1)"
assert_contains "workflow: code mode" "Mode changed" "$out"

out="$($CCH doctor --summary 2>&1)"
assert_contains "workflow: status shows code" "Mode:        code" "$out"

out="$($CCH update check 2>&1)"
assert_contains "workflow: update check" "Current version" "$out"

# DOT cycle within workflow
out="$($CCH dot on 2>&1)"
assert_contains "workflow: dot on in code" "DOT experiment: ON" "$out"

out="$($CCH doctor --summary 2>&1)"
assert_contains "workflow: status shows DOT on" "DOT:         true" "$out"

out="$($CCH dot off 2>&1)"
assert_contains "workflow: dot off" "DOT experiment: OFF" "$out"

# Work item lifecycle
$CCH work create wf-test "workflow test item" &>/dev/null
out="$($CCH work transition wf-test doing 2>&1)"
assert_contains "workflow: work todo→doing" "todo → doing" "$out"

out="$($CCH work transition wf-test done 2>&1)"
assert_contains "workflow: work doing→done" "doing → done" "$out"

out="$($CCH work list done 2>&1)"
assert_contains "workflow: done item in list" "wf-test" "$out"
