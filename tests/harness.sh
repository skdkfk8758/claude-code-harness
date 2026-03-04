#!/usr/bin/env bash
# CCH Test Harness - Minimal test framework
# Usage: source tests/harness.sh

set -uo pipefail

# Test counters
_PASS=0
_FAIL=0
_TOTAL=0

# Colors
_GREEN="\033[32m"
_RED="\033[31m"
_DIM="\033[2m"
_RESET="\033[0m"

# --- Setup ---
# Resolve ROOT_DIR: BASH_SOURCE works when executed under bash;
# fallback to $0 for direct execution or zsh source
_HARNESS_SRC="${BASH_SOURCE[0]:-$0}"
ROOT_DIR="$(cd "$(dirname "$_HARNESS_SRC")/.." && pwd)"
export ROOT_DIR

# Core CCH paths — exported so test files can reference them directly
CCH_ROOT="$ROOT_DIR"
export CCH_ROOT

CCH_BIN="$ROOT_DIR/bin/cch"
export CCH_BIN

# Create isolated test state dir
TEST_STATE_DIR="$(mktemp -d)"
export TEST_STATE_DIR
export CCH_STATE_DIR="$TEST_STATE_DIR"

# --- Assertions ---
# All assertion functions and test utilities are exported so they are available
# in sub-shells and test files that source this harness.

assert_contains() {
  local label="$1" expected="$2" actual="$3"
  _TOTAL=$((_TOTAL + 1))
  if echo "$actual" | grep -q "$expected"; then
    _PASS=$((_PASS + 1))
    printf "  ${_GREEN}PASS${_RESET} %s\n" "$label"
  else
    _FAIL=$((_FAIL + 1))
    printf "  ${_RED}FAIL${_RESET} %s\n" "$label"
    printf "       ${_DIM}expected to contain: %s${_RESET}\n" "$expected"
    printf "       ${_DIM}actual: %.200s${_RESET}\n" "$actual"
  fi
}

assert_not_contains() {
  local label="$1" unexpected="$2" actual="$3"
  _TOTAL=$((_TOTAL + 1))
  if ! echo "$actual" | grep -q "$unexpected"; then
    _PASS=$((_PASS + 1))
    printf "  ${_GREEN}PASS${_RESET} %s\n" "$label"
  else
    _FAIL=$((_FAIL + 1))
    printf "  ${_RED}FAIL${_RESET} %s\n" "$label"
    printf "       ${_DIM}should NOT contain: %s${_RESET}\n" "$unexpected"
  fi
}

assert_equals() {
  local label="$1" expected="$2" actual="$3"
  _TOTAL=$((_TOTAL + 1))
  if [[ "$actual" == "$expected" ]]; then
    _PASS=$((_PASS + 1))
    printf "  ${_GREEN}PASS${_RESET} %s\n" "$label"
  else
    _FAIL=$((_FAIL + 1))
    printf "  ${_RED}FAIL${_RESET} %s\n" "$label"
    printf "       ${_DIM}expected: %s${_RESET}\n" "$expected"
    printf "       ${_DIM}actual:   %s${_RESET}\n" "$actual"
  fi
}

assert_file_exists() {
  local label="$1" filepath="$2"
  _TOTAL=$((_TOTAL + 1))
  if [[ -f "$filepath" ]]; then
    _PASS=$((_PASS + 1))
    printf "  ${_GREEN}PASS${_RESET} %s\n" "$label"
  else
    _FAIL=$((_FAIL + 1))
    printf "  ${_RED}FAIL${_RESET} %s\n" "$label"
    printf "       ${_DIM}file not found: %s${_RESET}\n" "$filepath"
  fi
}

assert_exit_code() {
  local label="$1" expected="$2" actual="$3"
  _TOTAL=$((_TOTAL + 1))
  if [[ "$actual" -eq "$expected" ]]; then
    _PASS=$((_PASS + 1))
    printf "  ${_GREEN}PASS${_RESET} %s\n" "$label"
  else
    _FAIL=$((_FAIL + 1))
    printf "  ${_RED}FAIL${_RESET} %s\n" "$label"
    printf "       ${_DIM}expected exit code: %s, got: %s${_RESET}\n" "$expected" "$actual"
  fi
}

# Export assertion functions so sub-shells (e.g. sourced test files run via
# bash -c or process substitution) can use them without re-sourcing the harness.
export -f assert_contains
export -f assert_not_contains
export -f assert_equals
export -f assert_file_exists
export -f assert_exit_code

# --- Runner ---

run_test_file() {
  local test_file="$1"
  local test_name
  test_name="$(basename "$test_file" .sh)"
  echo ""
  printf "=== %s ===\n" "$test_name"
  source "$test_file"
}
export -f run_test_file

test_summary() {
  echo ""
  echo "================================"
  printf "Results: ${_GREEN}%d passed${_RESET}, ${_RED}%d failed${_RESET}, %d total\n" "$_PASS" "$_FAIL" "$_TOTAL"
  echo "================================"

  # Cleanup
  rm -rf "$TEST_STATE_DIR" 2>/dev/null

  if [[ "$_FAIL" -gt 0 ]]; then
    return 1
  fi
  return 0
}

# --- Main: run when executed directly ---
# Usage: bash tests/harness.sh [test_file...]
#   No args  → run all test_*.sh files
#   With args → run specified test files only
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"

  if [[ $# -gt 0 ]]; then
    # Run specified tests
    for tf in "$@"; do
      run_test_file "$tf"
    done
  else
    # Run all test files in order
    for tf in "$TEST_DIR"/test_*.sh; do
      [[ -f "$tf" ]] && run_test_file "$tf"
    done
  fi

  test_summary
  _rc=$?
  exit $_rc
fi
