#!/usr/bin/env bash
# bin/lib/skill.sh — Skill metadata parsing and management utilities

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

# List all configured skill source paths as JSON.
# Each entry: {"id":"<source-id>","path":"<path>","type":"<type>"}
skill_list_sources() {
  local repo_skills="$CCH_ROOT/skills"
  local cch_cache=""
  local custom_dir="$HOME/.claude/commands"

  # Find CCH cache
  local cache_base="$HOME/.claude/plugins/cache/claude-code-harness-marketplace"
  if [[ -d "$cache_base" ]]; then
    local latest
    latest="$(find "$cache_base" -maxdepth 2 -name "skills" -type d 2>/dev/null | head -1)"
    [[ -n "$latest" ]] && cch_cache="$latest"
  fi

  local first=true
  _emit_source() {
    local id="$1" path="$2" type="$3"
    $first || printf ','
    first=false
    printf '{"id":"%s","path":"%s","type":"%s"}' "$id" "$path" "$type"
  }

  printf '['
  [[ -d "$repo_skills" ]] && _emit_source "cch-repo" "$repo_skills" "development"
  [[ -n "$cch_cache" ]] && _emit_source "cch-cache" "$cch_cache" "deployed"
  [[ -d "$custom_dir" ]] && _emit_source "custom" "$custom_dir" "user-defined"
  printf ']'
  echo
}

# Scan all skill sources and return metadata as JSON array.
# Each entry includes: name, source, path, user_invocable, description, word_count, has_enhancement
skill_scan_all() {
  local first=true

  _scan_source() {
    local source_id="$1" source_dir="$2" pattern="$3"

    while IFS= read -r skill_file; do
      [[ -f "$skill_file" ]] || continue

      local name desc user_inv word_count
      name="$(skill_parse_meta "$skill_file" name)"
      [[ -z "$name" ]] && continue

      desc="$(skill_parse_meta "$skill_file" description)"
      user_inv="$(skill_parse_meta "$skill_file" user-invocable)"
      word_count="$(wc -w < "$skill_file" | tr -d ' ')"

      $first || printf ','
      first=false

      # Escape double quotes in description
      local safe_desc
      safe_desc="$(printf '%s' "$desc" | sed 's/"/\\"/g' | head -c 200)"

      printf '\n{"name":"%s","source":"%s","path":"%s","user_invocable":%s,"description":"%s","word_count":%s}' \
        "$name" \
        "$source_id" \
        "$skill_file" \
        "${user_inv:-false}" \
        "$safe_desc" \
        "${word_count:-0}"
    done < <(find "$source_dir" -name "$pattern" -type f 2>/dev/null | sort)
  }

  printf '['

  local repo_skills="$CCH_ROOT/skills"
  [[ -d "$repo_skills" ]] && _scan_source "cch-repo" "$repo_skills" "SKILL.md"

  # CCH cache
  local cache_base="$HOME/.claude/plugins/cache/claude-code-harness-marketplace"
  if [[ -d "$cache_base" ]]; then
    local cache_skills
    cache_skills="$(find "$cache_base" -maxdepth 2 -name "skills" -type d 2>/dev/null | head -1)"
    [[ -n "$cache_skills" ]] && _scan_source "cch-cache" "$cache_skills" "SKILL.md"
  fi

  # Custom commands
  local custom_dir="$HOME/.claude/commands"
  [[ -d "$custom_dir" ]] && _scan_source "custom" "$custom_dir" "*.md"

  printf ']'
  echo
}

# Validate a SKILL.md file against basic rules.
# Outputs lines like: "SM001 error: Missing frontmatter"
# Returns 0 if no errors, 1 if errors found.
skill_validate() {
  local file="$1"
  local has_error=false

  [[ -f "$file" ]] || { echo "SM001 error: File not found: $file"; return 1; }

  local first_line
  first_line="$(head -1 "$file")"

  # SM001: Check frontmatter exists
  if [[ "$first_line" != "---" ]]; then
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
    if [[ -n "$name" ]] && ! printf '%s' "$name" | grep -qE '^[a-zA-Z0-9-]+$'; then
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

# Search skills by keyword (matches name or description, case-insensitive).
# Returns JSON array of matching skills.
skill_search() {
  local query="$1"
  [[ -z "$query" ]] && { echo "[]"; return 0; }

  local query_lower
  query_lower="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"

  local all_skills
  all_skills="$(skill_scan_all)"

  local first=true
  printf '['
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Strip trailing comma from line
    line="${line%,}"
    local name desc name_lower desc_lower
    name="$(printf '%s' "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')"
    desc="$(printf '%s' "$line" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p')"
    name_lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    desc_lower="$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]')"

    if [[ "$name_lower" == *"$query_lower"* ]] || [[ "$desc_lower" == *"$query_lower"* ]]; then
      $first || printf ','
      first=false
      printf '\n%s' "$line"
    fi
  done < <(printf '%s\n' "$all_skills" | grep '"name"')

  printf ']'
  echo
}

# Show detailed info for a single skill by name.
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

# Command router for `cch skill` subcommand.
cmd_skill() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    list)     skill_scan_all ;;
    info)     skill_info "$@" ;;
    search)   skill_search "$@" ;;
    sources)  skill_list_sources ;;
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
