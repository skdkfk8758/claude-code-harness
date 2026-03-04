#!/usr/bin/env bash
# Phase 5: 코어 스킬 및 Tier 시스템 통합 검증

CCH="bash $ROOT_DIR/bin/cch"

# Setup
$CCH setup &>/dev/null

# --- capabilities.json schema ---
cap_file="$ROOT_DIR/manifests/capabilities.json"
assert_file_exists "capabilities.json exists" "$cap_file"

if [[ -f "$cap_file" ]]; then
  content="$(cat "$cap_file")"
  assert_contains "capabilities: has schema_version 2" '"schema_version": 2' "$content"
  assert_contains "capabilities: has sources" '"sources"' "$content"
  assert_contains "capabilities: has error_codes" '"error_codes"' "$content"
fi

# --- check-env.mjs ---
env_script="$ROOT_DIR/scripts/check-env.mjs"
assert_file_exists "check-env.mjs exists" "$env_script"

if command -v node &>/dev/null && [[ -f "$env_script" ]]; then
  out="$(node "$env_script" --cli 2>&1)" || true
  assert_contains "check-env: shows tier" "Tier" "$out"
fi

# --- core.mjs ---
core_script="$ROOT_DIR/scripts/lib/core.mjs"
assert_file_exists "core.mjs exists" "$core_script"

if command -v node &>/dev/null && [[ -f "$core_script" ]]; then
  out="$(node "$core_script" tier 2>&1)" || true
  # Should output a number (0, 1, or 2)
  if [[ "$out" =~ ^[0-2]$ ]]; then
    assert_equals "core.mjs tier: returns valid tier" "pass" "pass"
  else
    assert_equals "core.mjs tier: returns valid tier" "pass" "fail: got '$out'"
  fi

  out="$(node "$core_script" status-json 2>&1)" || true
  assert_contains "core.mjs status-json: has version" '"version"' "$out"
  assert_contains "core.mjs status-json: has tier" '"tier"' "$out"
fi

# --- Tier detection in cch ---
out="$($CCH setup 2>&1)"
assert_contains "setup: tier detected" "Tier detected" "$out"

# --- Cleanup function ---
out="$(grep -c '_cleanup_stale_files' "$ROOT_DIR/bin/cch" 2>/dev/null)" || true
if [[ "$out" -ge 2 ]]; then
  assert_equals "bin/cch: has cleanup function" "pass" "pass"
else
  assert_equals "bin/cch: has cleanup function" "pass" "fail: only $out references"
fi

# --- v2 skill count ---
skill_count="$(find "$ROOT_DIR/skills" -name 'SKILL.md' -type f | wc -l | tr -d ' ')"
if [[ "$skill_count" -ge 8 ]]; then
  assert_equals "at least 8 core skills" "pass" "pass"
else
  assert_equals "at least 8 core skills" "pass" "fail: only $skill_count skills"
fi
