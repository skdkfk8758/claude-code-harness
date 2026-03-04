#!/usr/bin/env bash
# test_arch_tdd.sh - Architecture level + TDD enforcement tests

CCH="bash $ROOT_DIR/bin/cch"

echo "--- arch: level (not set) ---"
out=$($CCH arch level 2>&1)
assert_contains "arch level not set" "not set" "$out"

echo "--- arch: set valid levels ---"
for lvl in 1 2 3; do
  ec=0
  out=$($CCH arch set "$lvl" 2>&1) || ec=$?
  assert_exit_code "arch set $lvl exit code" "0" "$ec"
  assert_contains "arch set $lvl confirmation" "level set: $lvl" "$out"
done

echo "--- arch: set invalid level ---"
ec=0
out=$($CCH arch set 0 2>&1) || ec=$?
assert_exit_code "arch set 0 rejected" "1" "$ec"
assert_contains "arch set 0 error msg" "Invalid level" "$out"

ec=0
out=$($CCH arch set 4 2>&1) || ec=$?
assert_exit_code "arch set 4 rejected" "1" "$ec"

ec=0
out=$($CCH arch set abc 2>&1) || ec=$?
assert_exit_code "arch set abc rejected" "1" "$ec"

echo "--- arch: level (after set) ---"
$CCH arch set 2 >/dev/null 2>&1
out=$($CCH arch level 2>&1)
assert_contains "arch level shows 2" "2" "$out"
assert_contains "arch level shows name" "Clean Architecture" "$out"
assert_contains "arch level shows TDD" "TDD" "$out"

echo "--- arch: check (dirs missing) ---"
$CCH arch set 2 >/dev/null 2>&1
ec=0
out=$($CCH arch check 2>&1) || ec=$?
assert_exit_code "arch check fails when dirs missing" "2" "$ec"
assert_contains "arch check shows MISS" "MISS" "$out"

echo "--- arch: check (not set) ---"
rm -f "$ROOT_DIR/.claude/cch/state/arch_level"
ec=0
out=$($CCH arch check 2>&1) || ec=$?
assert_exit_code "arch check fails when not set" "1" "$ec"
assert_contains "arch check not set error" "not set" "$out"

echo "--- arch: scaffold level 1 ---"
$CCH arch set 1 >/dev/null 2>&1
ec=0
out=$($CCH arch scaffold 2>&1) || ec=$?
assert_exit_code "arch scaffold L1 exit code" "0" "$ec"
assert_contains "scaffold creates tests dir" "tests" "$out"

# Verify tests dir exists
TOTAL=$((TOTAL + 1))
if [[ -d "$ROOT_DIR/tests" ]]; then
  PASS=$((PASS + 1))
  printf "  ${GREEN}PASS${NC} scaffold L1: tests/ exists\n"
else
  FAIL=$((FAIL + 1))
  printf "  ${RED}FAIL${NC} scaffold L1: tests/ should exist\n"
fi

echo "--- arch: scaffold level 2 ---"
$CCH arch set 2 >/dev/null 2>&1
ec=0
out=$($CCH arch scaffold 2>&1) || ec=$?
assert_exit_code "arch scaffold L2 exit code" "0" "$ec"
assert_contains "scaffold L2 creates src/domain" "src/domain" "$out"

# Verify structure
for d in src/domain src/application src/infrastructure src/interfaces; do
  TOTAL=$((TOTAL + 1))
  if [[ -d "$ROOT_DIR/$d" ]]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} scaffold L2: $d exists\n"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} scaffold L2: $d should exist\n"
  fi
done

echo "--- arch: scaffold idempotency ---"
ec=0
out2=$($CCH arch scaffold 2>&1) || ec=$?
assert_exit_code "scaffold idempotent exit code" "0" "$ec"
assert_contains "scaffold idempotent shows EXISTS" "EXISTS" "$out2"
assert_not_contains "scaffold idempotent no CREATED dirs" "CREATED] src/" "$out2"

echo "--- arch: scaffold level 3 ---"
$CCH arch set 3 >/dev/null 2>&1
ec=0
out=$($CCH arch scaffold 2>&1) || ec=$?
assert_exit_code "arch scaffold L3 exit code" "0" "$ec"
assert_contains "scaffold L3 creates bounded-contexts" "bounded-contexts" "$out"
assert_contains "scaffold L3 creates shared-kernel" "shared-kernel" "$out"

echo "--- arch: check (after scaffold L3) ---"
ec=0
out=$($CCH arch check 2>&1) || ec=$?
assert_exit_code "arch check passes after scaffold" "0" "$ec"
assert_contains "arch check PASSED" "PASSED" "$out"

echo "--- arch: report ---"
ec=0
out=$($CCH arch report 2>&1) || ec=$?
assert_exit_code "arch report exit code" "0" "$ec"
assert_contains "report shows level" "Level:" "$out"
assert_contains "report shows TDD" "TDD" "$out"
assert_contains "report shows metrics header" "TDD Metrics" "$out"

echo "--- arch: TDD state file ---"
TOTAL=$((TOTAL + 1))
if [[ -f "$ROOT_DIR/.claude/cch/state/tdd_enabled" ]]; then
  tdd_val=$(cat "$ROOT_DIR/.claude/cch/state/tdd_enabled")
  if [[ "$tdd_val" == "true" ]]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} tdd_enabled state is true\n"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} tdd_enabled should be 'true', got '$tdd_val'\n"
  fi
else
  FAIL=$((FAIL + 1))
  printf "  ${RED}FAIL${NC} tdd_enabled state file should exist\n"
fi

echo "--- arch: status integration ---"
out=$($CCH status 2>&1)
assert_contains "status shows Arch Level" "Arch Level:" "$out"
assert_contains "status shows TDD always ON" "TDD:" "$out"

echo "--- arch: manifest validation ---"
TOTAL=$((TOTAL + 1))
if [[ -f "$ROOT_DIR/manifests/architecture-levels.json" ]]; then
  if command -v jq &>/dev/null; then
    if jq empty "$ROOT_DIR/manifests/architecture-levels.json" 2>/dev/null; then
      PASS=$((PASS + 1))
      printf "  ${GREEN}PASS${NC} manifest is valid JSON\n"
    else
      FAIL=$((FAIL + 1))
      printf "  ${RED}FAIL${NC} manifest is invalid JSON\n"
    fi
  else
    if python3 -c "import json; json.load(open('$ROOT_DIR/manifests/architecture-levels.json'))" 2>/dev/null; then
      PASS=$((PASS + 1))
      printf "  ${GREEN}PASS${NC} manifest is valid JSON\n"
    else
      FAIL=$((FAIL + 1))
      printf "  ${RED}FAIL${NC} manifest is invalid JSON\n"
    fi
  fi
else
  FAIL=$((FAIL + 1))
  printf "  ${RED}FAIL${NC} manifest file not found\n"
fi

# Cleanup scaffold artifacts
rm -rf "$ROOT_DIR/src/domain" "$ROOT_DIR/src/application" "$ROOT_DIR/src/infrastructure" "$ROOT_DIR/src/interfaces"
rm -rf "$ROOT_DIR/src/bounded-contexts" "$ROOT_DIR/src/shared-kernel"
rm -rf "$ROOT_DIR/tests/domain"
