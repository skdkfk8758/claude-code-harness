#!/usr/bin/env bash
# test.sh - CCH test runner
# Usage: ./scripts/test.sh [layer]
# Layers: contract, agent, skill, workflow, resilience, all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"

PASS=0
FAIL=0
TOTAL=0

# Colors (if terminal supports)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$label"
    printf "       expected: %s\n" "$expected"
    printf "       actual:   %s\n" "$actual"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$label"
    printf "       expected to contain: %s\n" "$needle"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$label"
    printf "       expected NOT to contain: %s\n" "$needle"
  fi
}

assert_exit_code() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$label"
    printf "       expected exit: %s, got: %s\n" "$expected" "$actual"
  fi
}

assert_file_exists() {
  local label="$1" file="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -f "$file" ]]; then
    PASS=$((PASS + 1))
    printf "  ${GREEN}PASS${NC} %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ${RED}FAIL${NC} %s\n" "$label"
    printf "       file not found: %s\n" "$file"
  fi
}

# Compatibility alias for harness.sh tests that use assert_equals
assert_equals() { assert_eq "$@"; }

# Export for test files
export -f assert_eq assert_equals assert_contains assert_not_contains assert_exit_code assert_file_exists
export PASS FAIL TOTAL RED GREEN YELLOW NC
export ROOT_DIR

# Clean state before each test layer
clean_state() {
  rm -rf "$ROOT_DIR/.claude/cch" "$ROOT_DIR/.resolved"
}

# --- Run ---

run_layer() {
  local layer="$1"
  local test_file="$TESTS_DIR/test_${layer}.sh"

  if [[ ! -f "$test_file" ]]; then
    printf "${YELLOW}SKIP${NC} Layer: %s (file not found)\n" "$layer"
    return
  fi

  printf "\n=== Layer: %s ===\n" "$layer"
  clean_state
  source "$test_file"
  # Safety: restore cwd in case test file changed directory
  cd "$ROOT_DIR"
}

# --- Node.js unit tests ---

run_node_tests() {
  printf "\n=== Layer: node_unit ===\n"
  local node_pass=0 node_fail=0
  for test_file in "$TESTS_DIR"/unit/*.test.mjs; do
    [[ -f "$test_file" ]] || continue
    local test_name
    test_name="$(basename "$test_file")"
    if node --test "$test_file" > /dev/null 2>&1; then
      printf "  ${GREEN}PASS${NC} %s\n" "$test_name"
      node_pass=$((node_pass + 1))
    else
      printf "  ${RED}FAIL${NC} %s\n" "$test_name"
      node --test "$test_file" 2>&1 | tail -5
      node_fail=$((node_fail + 1))
    fi
  done
  PASS=$((PASS + node_pass))
  FAIL=$((FAIL + node_fail))
  TOTAL=$((TOTAL + node_pass + node_fail))
}

# --- Main ---

layer="${1:-all}"

if [[ "$layer" == "all" ]]; then
  for l in contract agent skill workflow resilience branch source_types vendor_integration cch_init arch_tdd beads; do
    run_layer "$l"
  done
  run_node_tests
elif [[ "$layer" == "node_unit" ]]; then
  run_node_tests
else
  run_layer "$layer"
fi

# Summary
echo ""
echo "==============================="
printf "Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
