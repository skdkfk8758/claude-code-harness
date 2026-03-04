#!/usr/bin/env bash
# tests/test_skill_manager.sh — skill.sh unit tests
# Covers: skill_parse_meta, skill_list_sources, skill_scan_all, skill_validate, skill_search

CCH_LIB_DIR="$ROOT_DIR/bin/lib"
export CCH_LIB_DIR

source "$CCH_LIB_DIR/skill.sh"

FIXTURES_DIR="$ROOT_DIR/tests/fixtures"

# =============================================================================
# skill_parse_meta tests (9 tests)
# =============================================================================

test_parse_meta_extracts_name() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/valid-skill/SKILL.md" name)"
  assert_equals "parse_meta name" "test-valid-skill" "$result"
}
test_parse_meta_extracts_name

test_parse_meta_extracts_description() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/valid-skill/SKILL.md" description)"
  assert_contains "parse_meta description" "Use when testing" "$result"
}
test_parse_meta_extracts_description

test_parse_meta_extracts_user_invocable() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/valid-skill/SKILL.md" user-invocable)"
  assert_equals "parse_meta user-invocable" "true" "$result"
}
test_parse_meta_extracts_user_invocable

test_parse_meta_extracts_allowed_tools() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/valid-skill/SKILL.md" allowed-tools)"
  assert_contains "parse_meta allowed-tools" "Bash" "$result"
}
test_parse_meta_extracts_allowed_tools

test_parse_meta_extracts_argument_hint() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/valid-skill/SKILL.md" argument-hint)"
  assert_contains "parse_meta argument-hint" "test-arg" "$result"
}
test_parse_meta_extracts_argument_hint

test_parse_meta_returns_empty_for_missing_field() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/valid-skill/SKILL.md" nonexistent)"
  assert_equals "parse_meta missing field" "" "$result"
}
test_parse_meta_returns_empty_for_missing_field

test_parse_meta_handles_no_frontmatter() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/defective-skill/SKILL.md" name)"
  assert_equals "parse_meta no frontmatter" "" "$result"
}
test_parse_meta_handles_no_frontmatter

test_parse_meta_handles_minimal() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/minimal-skill/SKILL.md" name)"
  assert_equals "parse_meta minimal name" "test-minimal" "$result"
}
test_parse_meta_handles_minimal

test_parse_meta_minimal_missing_optional() {
  local result
  result="$(skill_parse_meta "$FIXTURES_DIR/minimal-skill/SKILL.md" user-invocable)"
  assert_equals "parse_meta minimal no user-invocable" "" "$result"
}
test_parse_meta_minimal_missing_optional

# =============================================================================
# skill_list_sources tests (3 tests)
# =============================================================================

test_list_sources_includes_repo() {
  local result
  result="$(skill_list_sources)"
  assert_contains "list_sources includes repo" "cch-repo" "$result"
}
test_list_sources_includes_repo

test_list_sources_includes_type_field() {
  local result
  result="$(skill_list_sources)"
  assert_contains "list_sources has type field" "\"type\"" "$result"
}
test_list_sources_includes_type_field

test_list_sources_outputs_json() {
  local result
  result="$(skill_list_sources)"
  assert_contains "list_sources is JSON array" "\[" "$result"
}
test_list_sources_outputs_json

# =============================================================================
# skill_scan_all tests (5 tests)
# =============================================================================

test_scan_all_returns_json_array() {
  local result
  result="$(skill_scan_all)"
  assert_contains "scan_all is JSON" "\[" "$result"
}
test_scan_all_returns_json_array

test_scan_all_finds_repo_skills() {
  local result
  result="$(skill_scan_all)"
  assert_contains "scan_all finds cch-commit" "cch-commit" "$result"
}
test_scan_all_finds_repo_skills

test_scan_all_includes_source_field() {
  local result
  result="$(skill_scan_all)"
  assert_contains "scan_all has source field" "\"source\"" "$result"
}
test_scan_all_includes_source_field

test_scan_all_includes_name_field() {
  local result
  result="$(skill_scan_all)"
  assert_contains "scan_all has name field" "\"name\"" "$result"
}
test_scan_all_includes_name_field

test_scan_all_includes_word_count() {
  local result
  result="$(skill_scan_all)"
  assert_contains "scan_all has word_count" "\"word_count\"" "$result"
}
test_scan_all_includes_word_count

# =============================================================================
# skill_validate tests (4 tests)
# =============================================================================

test_validate_valid_skill_passes() {
  local result
  result="$(skill_validate "$FIXTURES_DIR/valid-skill/SKILL.md")"
  assert_not_contains "validate valid skill" "error" "$result"
}
test_validate_valid_skill_passes

test_validate_defective_catches_missing_frontmatter() {
  local result
  result="$(skill_validate "$FIXTURES_DIR/defective-skill/SKILL.md" 2>&1)"
  assert_contains "validate defective: SM001" "SM001" "$result"
}
test_validate_defective_catches_missing_frontmatter

test_validate_minimal_passes_required() {
  local result
  result="$(skill_validate "$FIXTURES_DIR/minimal-skill/SKILL.md")"
  assert_not_contains "validate minimal: no errors" "error" "$result"
}
test_validate_minimal_passes_required

test_validate_returns_exit_code_on_error() {
  skill_validate "$FIXTURES_DIR/defective-skill/SKILL.md" >/dev/null 2>&1
  assert_exit_code "validate defective exit code" "1" "$?"
}
test_validate_returns_exit_code_on_error

# =============================================================================
# skill_search tests (4 tests)
# =============================================================================

test_search_matches_name() {
  local result
  result="$(skill_search "commit")"
  assert_contains "search matches name" "cch-commit" "$result"
}
test_search_matches_name

test_search_matches_description() {
  local result
  result="$(skill_search "logical")"
  assert_contains "search matches description" "cch-commit" "$result"
}
test_search_matches_description

test_search_no_results() {
  local result
  result="$(skill_search "zzz-nonexistent-xyz")"
  assert_not_contains "search no results" "name" "$result"
}
test_search_no_results

test_search_case_insensitive() {
  local result
  result="$(skill_search "COMMIT")"
  assert_contains "search case insensitive" "cch-commit" "$result"
}
test_search_case_insensitive

# =============================================================================
# cmd_skill (CLI integration) tests (5 tests)
# =============================================================================

test_cch_skill_list_runs() {
  local result
  result="$(bash "$CCH_BIN" skill list 2>&1)"
  assert_contains "cch skill list runs" "\[" "$result"
}
test_cch_skill_list_runs

test_cch_skill_search_runs() {
  local result
  result="$(bash "$CCH_BIN" skill search commit 2>&1)"
  assert_contains "cch skill search runs" "cch-commit" "$result"
}
test_cch_skill_search_runs

test_cch_skill_sources_runs() {
  local result
  result="$(bash "$CCH_BIN" skill sources 2>&1)"
  assert_contains "cch skill sources runs" "cch-repo" "$result"
}
test_cch_skill_sources_runs

test_cch_skill_help_runs() {
  local result
  result="$(bash "$CCH_BIN" skill help 2>&1)"
  assert_contains "cch skill help" "list" "$result"
}
test_cch_skill_help_runs

test_cch_skill_info_runs() {
  local result
  result="$(bash "$CCH_BIN" skill info cch-commit 2>&1)"
  assert_contains "cch skill info" "cch-commit" "$result"
}
test_cch_skill_info_runs
