# Skill Manager Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a hybrid skill management tool (CLI utility + entry-point skill + analysis agent) that provides unified inventory, quality linting, lifecycle management, and dependency analysis across all 4 skill sources.

**Architecture:** Single entry-point skill (`cch-skill-manager`) routes subcommands. Light operations (list, info, search) run `bin/lib/skill.sh` bash functions directly. Heavy analysis (lint, create, edit, deps) dispatches the `skill-analyzer` agent. `bin/cch skill` CLI subcommand exposes bash utilities for non-Claude use.

**Tech Stack:** Bash (bin/lib/skill.sh, tests), Markdown (SKILL.md, agent definition), harness.sh test framework

**Design doc:** `docs/plans/2026-03-04-skill-manager-design.md`

---

## Task 1: Test Fixtures

Create valid and defective skill fixtures for testing.

**Files:**
- Create: `tests/fixtures/valid-skill/SKILL.md`
- Create: `tests/fixtures/defective-skill/SKILL.md`
- Create: `tests/fixtures/minimal-skill/SKILL.md`

**Step 1: Create fixture directory**

```bash
mkdir -p tests/fixtures/valid-skill tests/fixtures/defective-skill tests/fixtures/minimal-skill
```

**Step 2: Create valid skill fixture**

Create `tests/fixtures/valid-skill/SKILL.md`:
```markdown
---
name: test-valid-skill
description: Use when testing skill manager validation. Validates correct frontmatter parsing.
user-invocable: true
allowed-tools: Bash, Read
argument-hint: "<test-arg>"
---

# Test Valid Skill

## Overview

A fixture skill for testing the skill manager.

## When to Use

Use this for automated tests only.

## Enhancement (Tier 1+)

> superpowers plugin enhancement.

- **Tier 1+**: Example enhancement
```

**Step 3: Create defective skill fixture**

Create `tests/fixtures/defective-skill/SKILL.md`:
```markdown
This file has no frontmatter at all.
Just plain text content without YAML.
name: not-in-frontmatter
```

**Step 4: Create minimal skill fixture**

Create `tests/fixtures/minimal-skill/SKILL.md`:
```markdown
---
name: test-minimal
description: Minimal skill with only required fields.
---

# Minimal Skill

Content without optional fields.
```

**Step 5: Commit**

```bash
git add tests/fixtures/
git commit -m "test: add skill manager test fixtures (valid, defective, minimal)"
```

---

## Task 2: `skill_parse_meta()` — Frontmatter Parser

Core function that extracts YAML frontmatter from a SKILL.md file.

**Files:**
- Create: `bin/lib/skill.sh`
- Create: `tests/test_skill_manager.sh`

**Step 1: Write the failing tests**

Create `tests/test_skill_manager.sh`:
```bash
#!/usr/bin/env bash
# tests/test_skill_manager.sh — skill.sh unit tests

source "$CCH_LIB_DIR/skill.sh"

FIXTURES_DIR="$ROOT_DIR/tests/fixtures"

# --- skill_parse_meta tests ---

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
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — `skill_parse_meta: command not found`

**Step 3: Write minimal implementation**

Create `bin/lib/skill.sh`:
```bash
#!/usr/bin/env bash
# bin/lib/skill.sh — Skill metadata parsing utilities

# Extract a single frontmatter field from a SKILL.md file.
# Usage: skill_parse_meta <file_path> <field_name>
# Returns the field value (empty string if not found).
skill_parse_meta() {
  local file="$1" field="$2"
  [[ -f "$file" ]] || return 0

  local in_frontmatter=false
  local line
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if $in_frontmatter; then
        break
      else
        in_frontmatter=true
        continue
      fi
    fi
    if $in_frontmatter; then
      # Match "field: value" or "field: \"value\""
      if [[ "$line" =~ ^${field}:[[:space:]]*(.*) ]]; then
        local value="${BASH_REMATCH[1]}"
        # Strip surrounding quotes
        value="${value#\"}"
        value="${value%\"}"
        # Strip surrounding single quotes
        value="${value#\'}"
        value="${value%\'}"
        echo "$value"
        return 0
      fi
    fi
  done < "$file"
}
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 9 tests PASS

**Step 5: Commit**

```bash
git add bin/lib/skill.sh tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add skill_parse_meta with frontmatter parsing"
```

---

## Task 3: `skill_list_sources()` — Source Registry

Returns all configured skill source paths.

**Files:**
- Modify: `bin/lib/skill.sh`
- Modify: `tests/test_skill_manager.sh`

**Step 1: Write the failing tests**

Append to `tests/test_skill_manager.sh`:
```bash
# --- skill_list_sources tests ---

test_list_sources_includes_repo() {
  local result
  result="$(skill_list_sources)"
  assert_contains "list_sources includes repo" "cch-repo" "$result"
}
test_list_sources_includes_repo

test_list_sources_includes_custom() {
  local result
  result="$(skill_list_sources)"
  assert_contains "list_sources includes custom" "custom" "$result"
}
test_list_sources_includes_custom

test_list_sources_outputs_json() {
  local result
  result="$(skill_list_sources)"
  assert_contains "list_sources is JSON array" "[" "$result"
}
test_list_sources_outputs_json
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — `skill_list_sources: command not found`

**Step 3: Write minimal implementation**

Append to `bin/lib/skill.sh`:
```bash
# List all configured skill source paths as JSON.
# Each entry: {"id":"<source-id>","path":"<path>","type":"<type>"}
skill_list_sources() {
  local sources=()
  local repo_skills="$CCH_ROOT/skills"
  local cch_cache=""
  local sp_cache=""
  local custom_dir="$HOME/.claude/commands"

  # Find CCH cache
  local cache_base="$HOME/.claude/plugins/cache/claude-code-harness-marketplace"
  if [[ -d "$cache_base" ]]; then
    local latest
    latest="$(find "$cache_base" -maxdepth 2 -name "skills" -type d 2>/dev/null | head -1)"
    [[ -n "$latest" ]] && cch_cache="$latest"
  fi

  # Find Superpowers cache
  local sp_base="$HOME/.claude/plugins/cache/superpowers-marketplace"
  if [[ -d "$sp_base" ]]; then
    local latest
    latest="$(find "$sp_base" -maxdepth 3 -name "skills" -type d 2>/dev/null | head -1)"
    [[ -n "$latest" ]] && sp_cache="$latest"
  fi

  echo "["

  local first=true
  _emit_source() {
    local id="$1" path="$2" type="$3"
    $first || echo ","
    first=false
    printf '  {"id":"%s","path":"%s","type":"%s"}' "$id" "$path" "$type"
  }

  [[ -d "$repo_skills" ]] && _emit_source "cch-repo" "$repo_skills" "development"
  [[ -n "$cch_cache" ]] && _emit_source "cch-cache" "$cch_cache" "deployed"
  [[ -n "$sp_cache" ]] && _emit_source "superpowers" "$sp_cache" "external"
  [[ -d "$custom_dir" ]] && _emit_source "custom" "$custom_dir" "user-defined"

  echo ""
  echo "]"
}
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 12 tests PASS

**Step 5: Commit**

```bash
git add bin/lib/skill.sh tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add skill_list_sources for source registry"
```

---

## Task 4: `skill_scan_all()` — Unified Inventory

Scans all sources and returns metadata for every skill found.

**Files:**
- Modify: `bin/lib/skill.sh`
- Modify: `tests/test_skill_manager.sh`

**Step 1: Write the failing tests**

Append to `tests/test_skill_manager.sh`:
```bash
# --- skill_scan_all tests ---

test_scan_all_returns_json_array() {
  local result
  result="$(skill_scan_all)"
  assert_contains "scan_all is JSON" "[" "$result"
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
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — `skill_scan_all: command not found`

**Step 3: Write minimal implementation**

Append to `bin/lib/skill.sh`:
```bash
# Scan all skill sources and return metadata as JSON array.
# Each entry includes: name, source, path, user_invocable, description, word_count, has_enhancement
skill_scan_all() {
  local first=true
  echo "["

  _scan_source() {
    local source_id="$1" source_dir="$2" pattern="$3"

    while IFS= read -r skill_file; do
      [[ -f "$skill_file" ]] || continue

      local name desc user_inv allowed_tools arg_hint word_count has_enh
      name="$(skill_parse_meta "$skill_file" name)"
      [[ -z "$name" ]] && continue

      desc="$(skill_parse_meta "$skill_file" description)"
      user_inv="$(skill_parse_meta "$skill_file" user-invocable)"
      allowed_tools="$(skill_parse_meta "$skill_file" allowed-tools)"
      arg_hint="$(skill_parse_meta "$skill_file" argument-hint)"
      word_count="$(wc -w < "$skill_file" | tr -d ' ')"
      has_enh="false"
      grep -q "Enhancement" "$skill_file" 2>/dev/null && has_enh="true"

      $first || echo ","
      first=false

      printf '  {"name":"%s","source":"%s","path":"%s","user_invocable":%s,"description":"%s","word_count":%s,"has_enhancement":%s}' \
        "$name" \
        "$source_id" \
        "$skill_file" \
        "${user_inv:-false}" \
        "$(echo "$desc" | sed 's/"/\\"/g' | head -c 200)" \
        "${word_count:-0}" \
        "$has_enh"
    done < <(find "$source_dir" -name "$pattern" -type f 2>/dev/null | sort)
  }

  local repo_skills="$CCH_ROOT/skills"
  [[ -d "$repo_skills" ]] && _scan_source "cch-repo" "$repo_skills" "SKILL.md"

  # CCH cache
  local cache_base="$HOME/.claude/plugins/cache/claude-code-harness-marketplace"
  if [[ -d "$cache_base" ]]; then
    local cache_skills
    cache_skills="$(find "$cache_base" -maxdepth 2 -name "skills" -type d 2>/dev/null | head -1)"
    [[ -n "$cache_skills" ]] && _scan_source "cch-cache" "$cache_skills" "SKILL.md"
  fi

  # Superpowers cache
  local sp_base="$HOME/.claude/plugins/cache/superpowers-marketplace"
  if [[ -d "$sp_base" ]]; then
    local sp_skills
    sp_skills="$(find "$sp_base" -maxdepth 3 -name "skills" -type d 2>/dev/null | head -1)"
    [[ -n "$sp_skills" ]] && _scan_source "superpowers" "$sp_skills" "SKILL.md"
  fi

  # Custom commands
  local custom_dir="$HOME/.claude/commands"
  [[ -d "$custom_dir" ]] && _scan_source "custom" "$custom_dir" "*.md"

  echo ""
  echo "]"
}
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 17 tests PASS

**Step 5: Commit**

```bash
git add bin/lib/skill.sh tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add skill_scan_all for unified inventory"
```

---

## Task 5: `skill_validate()` — Basic Format Validation

Validates a single SKILL.md against basic rules (SM001-SM003, SM010).

**Files:**
- Modify: `bin/lib/skill.sh`
- Modify: `tests/test_skill_manager.sh`

**Step 1: Write the failing tests**

Append to `tests/test_skill_manager.sh`:
```bash
# --- skill_validate tests ---

test_validate_valid_skill_passes() {
  local result
  result="$(skill_validate "$FIXTURES_DIR/valid-skill/SKILL.md")"
  assert_not_contains "validate valid skill" "error" "$result"
}
test_validate_valid_skill_passes

test_validate_defective_catches_missing_frontmatter() {
  local result
  result="$(skill_validate "$FIXTURES_DIR/defective-skill/SKILL.md")"
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
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — `skill_validate: command not found`

**Step 3: Write minimal implementation**

Append to `bin/lib/skill.sh`:
```bash
# Validate a SKILL.md file against basic rules.
# Outputs lines like: "SM001 error: Missing frontmatter"
# Returns 0 if no errors, 1 if errors found.
skill_validate() {
  local file="$1"
  local has_error=false

  [[ -f "$file" ]] || { echo "SM001 error: File not found: $file"; return 1; }

  local content
  content="$(cat "$file")"

  # SM001: Check frontmatter exists
  if ! echo "$content" | head -1 | grep -q "^---"; then
    echo "SM001 error: Missing frontmatter or YAML parse failure"
    has_error=true
  else
    local name desc
    name="$(skill_parse_meta "$file" name)"
    desc="$(skill_parse_meta "$file" description)"

    # SM002: name field
    if [[ -z "$name" ]]; then
      echo "SM002 error: Missing name field"
      has_error=true
    fi

    # SM010: invalid characters in name
    if [[ -n "$name" ]] && ! echo "$name" | grep -qE '^[a-zA-Z0-9-]+$'; then
      echo "SM010 error: Invalid characters in name (only letters, numbers, hyphens allowed)"
      has_error=true
    fi

    # SM003: description field
    if [[ -z "$desc" ]]; then
      echo "SM003 error: Missing description field"
      has_error=true
    fi
  fi

  $has_error && return 1
  return 0
}
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 21 tests PASS

**Step 5: Commit**

```bash
git add bin/lib/skill.sh tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add skill_validate with SM001-SM003, SM010 rules"
```

---

## Task 6: `skill_search()` — Keyword Search

Search skills by name or description keyword.

**Files:**
- Modify: `bin/lib/skill.sh`
- Modify: `tests/test_skill_manager.sh`

**Step 1: Write the failing tests**

Append to `tests/test_skill_manager.sh`:
```bash
# --- skill_search tests ---

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
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — `skill_search: command not found`

**Step 3: Write minimal implementation**

Append to `bin/lib/skill.sh`:
```bash
# Search skills by keyword (matches name or description, case-insensitive).
# Returns JSON array of matching skills.
skill_search() {
  local query="$1"
  [[ -z "$query" ]] && { echo "[]"; return 0; }

  local query_lower
  query_lower="$(echo "$query" | tr '[:upper:]' '[:lower:]')"

  local all_skills
  all_skills="$(skill_scan_all)"

  echo "["
  local first=true
  while IFS= read -r line; do
    local name_lower desc_lower
    local name desc
    name="$(echo "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')"
    desc="$(echo "$line" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p')"
    name_lower="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    desc_lower="$(echo "$desc" | tr '[:upper:]' '[:lower:]')"

    if [[ "$name_lower" == *"$query_lower"* ]] || [[ "$desc_lower" == *"$query_lower"* ]]; then
      $first || echo ","
      first=false
      echo "  $line"
    fi
  done < <(echo "$all_skills" | grep '"name"')

  echo ""
  echo "]"
}
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 25 tests PASS

**Step 5: Commit**

```bash
git add bin/lib/skill.sh tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add skill_search with case-insensitive matching"
```

---

## Task 7: `cmd_skill()` — CLI Subcommand Router

Add `skill` subcommand to `bin/cch`.

**Files:**
- Modify: `bin/cch` (add `cmd_skill` dispatch + source skill.sh)
- Modify: `tests/test_skill_manager.sh`

**Step 1: Write the failing tests**

Append to `tests/test_skill_manager.sh`:
```bash
# --- cmd_skill (CLI integration) tests ---

test_cch_skill_list_runs() {
  local result
  result="$(bash "$CCH_BIN" skill list 2>&1)"
  assert_contains "cch skill list runs" "[" "$result"
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
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — unknown command `skill`

**Step 3: Modify `bin/cch`**

3a. Add `skill.sh` source line alongside other lib sources (near lines 14-20):
```bash
[[ -f "$CCH_LIB_DIR/skill.sh" ]] && source "$CCH_LIB_DIR/skill.sh"
```

3b. Add `skill_info()` function to `bin/lib/skill.sh`:
```bash
# Show detailed info for a single skill by name.
# Searches all sources, returns first match.
skill_info() {
  local target="$1"
  [[ -z "$target" ]] && { echo "[cch] ERROR: skill name required"; return 1; }

  local all_skills
  all_skills="$(skill_scan_all)"
  local match
  match="$(echo "$all_skills" | grep "\"name\":\"${target}\"")"

  if [[ -z "$match" ]]; then
    echo "[cch] Skill '$target' not found."
    echo "[cch] Did you mean one of:"
    skill_search "$target" | grep '"name"' | sed 's/.*"name":"\([^"]*\)".*/  - \1/' | head -5
    return 1
  fi

  echo "$match"
}
```

3c. Add `cmd_skill()` router to `bin/lib/skill.sh`:
```bash
# Command router for `cch skill` subcommand.
cmd_skill() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    list)    skill_scan_all ;;
    info)    skill_info "$@" ;;
    search)  skill_search "$@" ;;
    sources) skill_list_sources ;;
    validate) skill_validate "$@" ;;
    help|--help|-h)
      echo "Usage: cch skill <action> [args]"
      echo ""
      echo "Actions:"
      echo "  list              List all skills across all sources"
      echo "  info <name>       Show detailed info for a skill"
      echo "  search <query>    Search skills by keyword"
      echo "  sources           List configured skill sources"
      echo "  validate <file>   Validate a SKILL.md file"
      echo "  help              Show this help"
      ;;
    *)
      echo "[cch] Unknown skill action: $action"
      echo "[cch] Run 'cch skill help' for usage."
      return 1
      ;;
  esac
}
```

3d. Add `skill)` case to the main dispatch in `bin/cch` (in the case statement near line 430):
```bash
    skill)           cmd_skill "$@" || _cch_exit_code=$? ;;
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 30 tests PASS

**Step 5: Commit**

```bash
git add bin/cch bin/lib/skill.sh tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add cch skill CLI subcommand with list/info/search/sources"
```

---

## Task 8: Skill Entry Point — `cch-skill-manager/SKILL.md`

The user-invocable skill that routes subcommands.

**Files:**
- Create: `skills/cch-skill-manager/SKILL.md`

**Step 1: Write SKILL.md validation test**

Append to `tests/test_skill_manager.sh`:
```bash
# --- SKILL.md metadata tests ---

test_skill_manager_has_frontmatter() {
  local file="$ROOT_DIR/skills/cch-skill-manager/SKILL.md"
  local content
  content="$(cat "$file")"
  assert_contains "skill-manager: has frontmatter" "^---" "$content"
  assert_contains "skill-manager: has name" "name:" "$content"
  assert_contains "skill-manager: has description" "description:" "$content"
  assert_contains "skill-manager: has user-invocable" "user-invocable:" "$content"
  assert_contains "skill-manager: has argument-hint" "argument-hint:" "$content"
}
test_skill_manager_has_frontmatter

test_skill_manager_has_enhancement() {
  local file="$ROOT_DIR/skills/cch-skill-manager/SKILL.md"
  local content
  content="$(cat "$file")"
  assert_contains "skill-manager: has Enhancement" "Enhancement" "$content"
  assert_contains "skill-manager: has Tier" "Tier" "$content"
}
test_skill_manager_has_enhancement
```

**Step 2: Run tests to verify they fail**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: FAIL — file not found

**Step 3: Create the skill**

Create `skills/cch-skill-manager/SKILL.md`:
```markdown
---
name: cch-skill-manager
description: Manage, analyze, and create skills across all plugin sources. Use for skill inventory, linting, creation, and dependency analysis.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Agent, Write, Edit, AskUserQuestion
argument-hint: "list | info <name> | lint [name] | create <name> | edit <name> | deps [name] | search <query>"
---

# CCH Skill Manager

스킬 인벤토리, 품질 분석, 생성/수정, 의존성 분석을 위한 통합 관리 도구.

## Step 1 — 인자 파싱

인자에서 서브커맨드와 대상을 추출합니다.

```
ARGUMENTS 문자열에서:
- 첫 단어 → subcommand (list, info, lint, create, edit, deps, search)
- 나머지 → target (스킬 이름 또는 검색 쿼리)

인자가 없으면 → list 실행
```

## Step 2 — Light Operations (직접 처리)

`list`, `info`, `search`, `sources` 서브커맨드는 CLI를 직접 호출합니다.

### list — 전체 스킬 인벤토리

```bash
bash bin/cch skill list
```

결과를 읽기 좋은 테이블로 포맷합니다:

| Name | Source | Invocable | Words | Enhancement |
|------|--------|-----------|-------|-------------|

### info — 단일 스킬 상세

```bash
bash bin/cch skill info <name>
```

### search — 키워드 검색

```bash
bash bin/cch skill search "<query>"
```

### sources — 소스 목록

```bash
bash bin/cch skill sources
```

## Step 3 — Heavy Operations (에이전트 디스패치)

`lint`, `create`, `edit`, `deps` 서브커맨드는 `skill-analyzer` 에이전트를 디스패치합니다.

### lint — 품질 분석

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-analyzer`

프롬프트에 포함할 내용:
1. 분석 대상 (특정 스킬 이름 또는 "전체")
2. lint 규칙 테이블 (SM001-SM012)
3. 기본 검증은 `bash bin/cch skill validate <file>` 활용
4. 결과를 심각도별로 그룹화하여 보고

### create — 새 스킬 생성

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-creator`

프롬프트에 포함할 내용:
1. 생성할 스킬 이름
2. writing-skills TDD 워크플로우 참조
3. SKILL.md 템플릿 (frontmatter + body 구조)
4. 기존 패턴 참조 (cch-commit, cch-plan 등)

### edit — 기존 스킬 수정

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-editor`

프롬프트에 포함할 내용:
1. 수정할 스킬 이름
2. 현재 스킬 내용 (`bash bin/cch skill info <name>`로 경로 파악)
3. 수정 가이드라인

### deps — 의존성/충돌 분석

Agent 도구로 호출:
- subagent_type: `general-purpose`
- name: `skill-dep-analyzer`

프롬프트에 포함할 내용:
1. 분석 대상 (특정 스킬 또는 전체)
2. 크로스 레퍼런스 패턴: `superpowers:name`, `cch-name`, `Skill("name")`, `bin/cch <cmd>`
3. 중복 감지 기준 (description 유사도)
4. 결과: 의존성 목록 + 충돌 경고

## Step 4 — 결과 출력

서브커맨드 결과를 사용자에게 포맷하여 출력합니다.
에이전트 결과는 요약하여 전달합니다.

## Enhancement (Tier 1+)

> superpowers 플러그인이 설치되어 있으면 다음 강화 기능을 활용합니다.

- **Tier 1+**: `create` 시 `superpowers:writing-skills` TDD 워크플로우 자동 적용
- **Tier 1+**: `lint` 시 `superpowers:verification-before-completion` 체크리스트 기반 검증
- **Tier 2+**: `deps` 시 Serena MCP 도구로 심볼릭 크로스 레퍼런스 분석
```

**Step 4: Run tests to verify they pass**

Run: `bash tests/harness.sh tests/test_skill_manager.sh`
Expected: All 32 tests PASS

**Step 5: Commit**

```bash
git add skills/cch-skill-manager/ tests/test_skill_manager.sh
git commit -m "feat(skill-manager): add cch-skill-manager entry-point skill"
```

---

## Task 9: Analysis Agent — `skill-analyzer.md`

The dedicated agent for heavy analysis operations.

**Files:**
- Create: `.claude/agents/skill-analyzer.md`

**Step 1: Create the agent definition**

Create `.claude/agents/skill-analyzer.md`:
```markdown
# Skill Analyzer Agent

You are a specialized skill analysis agent for the Claude Code Harness (CCH) ecosystem. You analyze, validate, and provide guidance for SKILL.md files across multiple plugin sources.

## Your Capabilities

You have access to: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion

## Skill Sources

- **CCH repo**: `./skills/cch-*/SKILL.md`
- **CCH cache**: `~/.claude/plugins/cache/claude-code-harness-marketplace/.../skills/`
- **Superpowers**: `~/.claude/plugins/cache/superpowers-marketplace/.../skills/`
- **Custom**: `~/.claude/commands/*.md`

## SKILL.md Format Reference

Valid frontmatter:
```yaml
---
name: skill-name-with-hyphens
description: Use when [specific triggers/symptoms/contexts]
user-invocable: true
allowed-tools: Tool1, Tool2
argument-hint: "usage pattern"
---
```

## Lint Rules

When performing lint analysis, check these rules:

| Rule | Severity | Check |
|------|----------|-------|
| SM001 | error | Frontmatter exists (starts with `---`) |
| SM002 | error | `name` field present |
| SM003 | error | `description` field present |
| SM004 | warn | Description starts with "Use when" (CSO optimization) |
| SM005 | warn | Description under 500 characters |
| SM006 | info | Body under 500 words (token efficiency) |
| SM007 | warn | If `user-invocable: true`, `allowed-tools` should be present |
| SM008 | info | Has `## Enhancement` section (tier utilization) |
| SM009 | warn | Description not >80% similar to another skill |
| SM010 | error | Name contains only letters, numbers, hyphens |
| SM011 | info | Has `## When to Use` section |
| SM012 | warn | If skill expects arguments, has `argument-hint` |

For basic validation, use: `bash bin/cch skill validate <file>`

## Dependency Analysis Patterns

When analyzing dependencies, search for these cross-reference patterns:
- `superpowers:skill-name` — Superpowers skill reference
- `cch-skill-name` in text — CCH skill reference
- `Skill("skill-name")` or `Skill(skill-name)` — Skill tool invocation
- `bin/cch <command>` — CLI dependency
- `Enhancement (Tier N+)` — Tier dependency

## Operating Modes

You will receive a prompt specifying one of these modes:

### lint mode
1. Run `bash bin/cch skill validate <file>` for basic checks
2. Read the SKILL.md content
3. Apply SM004-SM012 rules manually
4. Group findings by severity (error → warn → info)
5. Provide specific improvement suggestions for each finding

### create mode
1. Ask for the skill's purpose via AskUserQuestion
2. Generate SKILL.md following the template above
3. Ensure all required fields are present
4. Include Enhancement section
5. Write the file and validate it

### edit mode
1. Read the current SKILL.md
2. Identify issues via lint rules
3. Suggest improvements
4. Apply changes with user confirmation

### deps mode
1. Scan all skills for cross-references
2. Build a reference map: `{skill → [references_to_other_skills]}`
3. Identify duplicates (similar descriptions)
4. Report circular dependencies if any
5. Format as dependency graph
```

**Step 2: Verify the agent file exists and is well-formed**

Run: `ls -la .claude/agents/skill-analyzer.md`
Expected: file exists

**Step 3: Commit**

```bash
git add .claude/agents/skill-analyzer.md
git commit -m "feat(skill-manager): add skill-analyzer agent definition"
```

---

## Task 10: Add `cch-skill-manager` to Core Skills List in Tests

Update `test_skill.sh` to include the new skill in validation.

**Files:**
- Modify: `tests/test_skill.sh`

**Step 1: Read current test_skill.sh to find core_skills array**

Read `tests/test_skill.sh` and locate the `core_skills` array.

**Step 2: Add cch-skill-manager to the core_skills array**

Add `"cch-skill-manager"` to the `core_skills` array (line 7).

Before:
```bash
core_skills=("cch-setup" "cch-status" "cch-commit" "cch-plan" "cch-todo" "cch-verify" "cch-review" "cch-pr")
```

After:
```bash
core_skills=("cch-setup" "cch-status" "cch-commit" "cch-plan" "cch-todo" "cch-verify" "cch-review" "cch-pr" "cch-skill-manager")
```

**Step 3: Add cch-skill-manager to tier_aware_skills array**

Add `"cch-skill-manager"` to the `tier_aware_skills` array.

**Step 4: Run the full test suite to verify nothing breaks**

Run: `bash tests/harness.sh`
Expected: All existing tests PASS + new tests PASS

**Step 5: Commit**

```bash
git add tests/test_skill.sh
git commit -m "test: add cch-skill-manager to core skills validation"
```

---

## Task 11: Integration Test & Final Verification

End-to-end verification of the complete system.

**Files:**
- Modify: `tests/test_skill_manager.sh` (add integration tests)

**Step 1: Add integration tests**

Append to `tests/test_skill_manager.sh`:
```bash
# --- Integration tests ---

test_cch_skill_list_finds_skill_manager() {
  local result
  result="$(bash "$CCH_BIN" skill list 2>&1)"
  assert_contains "skill list finds skill-manager" "cch-skill-manager" "$result"
}
test_cch_skill_list_finds_skill_manager

test_cch_skill_info_skill_manager() {
  local result
  result="$(bash "$CCH_BIN" skill info cch-skill-manager 2>&1)"
  assert_contains "skill info skill-manager" "cch-skill-manager" "$result"
}
test_cch_skill_info_skill_manager

test_cch_skill_validate_valid() {
  local result
  result="$(bash "$CCH_BIN" skill validate "$ROOT_DIR/tests/fixtures/valid-skill/SKILL.md" 2>&1)"
  assert_not_contains "validate valid fixture" "error" "$result"
}
test_cch_skill_validate_valid

test_cch_skill_validate_defective() {
  bash "$CCH_BIN" skill validate "$ROOT_DIR/tests/fixtures/defective-skill/SKILL.md" >/dev/null 2>&1
  assert_exit_code "validate defective via CLI" "1" "$?"
}
test_cch_skill_validate_defective
```

**Step 2: Run the full test suite**

Run: `bash tests/harness.sh`
Expected: ALL tests PASS across all test files

**Step 3: Commit**

```bash
git add tests/test_skill_manager.sh
git commit -m "test: add skill-manager integration tests"
```

---

## Summary

| Task | Component | Tests | Files |
|------|-----------|-------|-------|
| 1 | Test fixtures | — | 3 new fixture files |
| 2 | `skill_parse_meta()` | 9 | `bin/lib/skill.sh`, `tests/test_skill_manager.sh` |
| 3 | `skill_list_sources()` | 3 | modify skill.sh, test file |
| 4 | `skill_scan_all()` | 5 | modify skill.sh, test file |
| 5 | `skill_validate()` | 4 | modify skill.sh, test file |
| 6 | `skill_search()` | 4 | modify skill.sh, test file |
| 7 | `cmd_skill()` + `bin/cch` | 5 | modify bin/cch, skill.sh, test file |
| 8 | `cch-skill-manager/SKILL.md` | 2 | new skill |
| 9 | `skill-analyzer.md` agent | — | new agent |
| 10 | Core skills list update | — | modify test_skill.sh |
| 11 | Integration tests | 4 | modify test file |

**Total: 36 tests, 11 commits**
