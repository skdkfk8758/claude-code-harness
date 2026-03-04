#!/usr/bin/env bash
# Layer 2: Agent - mode별 capability 선택/응답 포맷 검증

CCH="bash $ROOT_DIR/bin/cch"
$CCH setup &>/dev/null

# Plan mode: ruflo + superpowers
$CCH mode plan &>/dev/null
out="$($CCH doctor --summary 2>&1)"
assert_contains "plan: profile loaded" "profiles/plan.json" "$out"

# Code mode: omc + superpowers
$CCH mode code &>/dev/null
out="$($CCH doctor --summary 2>&1)"
assert_contains "code: profile loaded" "profiles/code.json" "$out"
assert_contains "code: shows omc source" "omc" "$out"

# Tool mode: gptaku_plugins
$CCH mode tool &>/dev/null
out="$($CCH doctor --summary 2>&1)"
assert_contains "tool: profile loaded" "profiles/tool.json" "$out"
assert_contains "tool: shows gptaku_plugins" "gptaku_plugins" "$out"

# Swarm mode: ruflo
$CCH mode swarm &>/dev/null
out="$($CCH doctor --summary 2>&1)"
assert_contains "swarm: profile loaded" "profiles/swarm.json" "$out"
assert_contains "swarm: shows ruflo" "ruflo" "$out"

# Resolve output format
$CCH mode code &>/dev/null
$CCH resolve code &>/dev/null
assert_file_exists "resolve: state.json created" "$ROOT_DIR/.resolved/state.json"

resolved="$(cat "$ROOT_DIR/.resolved/state.json")"
assert_contains "resolve: has mode field" '"mode"' "$resolved"
assert_contains "resolve: has health field" '"health"' "$resolved"
assert_contains "resolve: has available field" '"available"' "$resolved"
assert_contains "resolve: has degraded field" '"degraded"' "$resolved"
