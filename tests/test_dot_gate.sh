#!/usr/bin/env bash
# Layer 6: DOT Gate - code 모드 KPI 측정 및 킬스위치 판정

CCH="bash $ROOT_DIR/bin/cch"
$CCH setup --no-fetch &>/dev/null
$CCH mode code &>/dev/null

# KPI recording
out="$($CCH kpi record token_usage 1500 2>&1)"
assert_contains "dot_gate: token_usage recorded" "KPI recorded" "$out"

out="$($CCH kpi record mode_switch_latency 200 2>&1)"
assert_contains "dot_gate: latency recorded" "KPI recorded" "$out"

out="$($CCH kpi record prompt_conflict test_conflict 2>&1)"
assert_contains "dot_gate: conflict recorded" "KPI recorded" "$out"

# KPI show with data
out="$($CCH kpi show 2>&1)"
assert_contains "dot_gate: dashboard shows token" "Token Usage" "$out"
assert_contains "dot_gate: dashboard shows latency" "Mode Switch Latency" "$out"
assert_contains "dot_gate: dashboard shows conflicts" "Prompt Conflicts" "$out"
assert_contains "dot_gate: dashboard shows regressions" "Quality Regressions" "$out"
assert_contains "dot_gate: token samples counted" "Samples: 1" "$out"

# JSONL format verification
assert_file_exists "dot_gate: JSONL file exists" "$CCH_STATE_DIR/metrics/dot-poc.jsonl"
line="$(head -1 "$CCH_STATE_DIR/metrics/dot-poc.jsonl")"
assert_contains "dot_gate: JSONL has ts" '"ts"' "$line"
assert_contains "dot_gate: JSONL has metric" '"metric"' "$line"
assert_contains "dot_gate: JSONL has value" '"value"' "$line"
assert_contains "dot_gate: JSONL has mode" '"mode"' "$line"

# Kill switch: 2+ quality regressions
$CCH kpi record quality_regression "regression_1" &>/dev/null
out="$($CCH kpi record quality_regression regression_2 2>&1)"
assert_contains "dot_gate: kill switch triggered at 2" "KILL SWITCH" "$out"

# KPI show: no-data stability (after reset)
$CCH kpi reset &>/dev/null
out="$($CCH kpi show 2>&1)"
ec=$?
assert_equals "dot_gate: kpi show exits 0 after reset" "0" "$ec"
assert_contains "dot_gate: reset shows no data" "No data" "$out"

# DOT compile: combo/combos path handling
$CCH dot on &>/dev/null 2>&1
compiled="$(cat "$CCH_STATE_DIR/dot_compiled" 2>/dev/null)"
assert_contains "dot_gate: dot_compiled state set" "$compiled" "true cache false"
$CCH dot off &>/dev/null 2>&1

# Execution log: start/end pair recorded
out="$($CCH log tail _global 2 2>&1)"
assert_contains "dot_gate: log has start event" "start" "$out"
assert_contains "dot_gate: log has end event" "end" "$out"
