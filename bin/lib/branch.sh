#!/usr/bin/env bash
# cch branch - Branch management module
# Storage: .claude/cch/branches/<branch-slug>.yaml
# Implements G1-G5, G7, G10, G14 from BW gap analysis

BRANCH_DIR="$CCH_STATE_DIR/branches"

# --- YAML Helpers (formerly in work.sh) ---

yaml_get() {
  local file="$1" key="$2"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[[:space:]]*//"
}

yaml_set() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}:" "$file" 2>/dev/null; then
    sed -i.bak "s/^${key}:.*/${key}: ${value}/" "$file" && rm -f "${file}.bak"
  else
    echo "${key}: ${value}" >> "$file"
  fi
}

# --- Helpers ---

# Convert branch name to safe filename: / → _
branch_state_filename() {
  echo "${1//\//_}"
}

# Get configured base branch
# 3-tier fallback: .claude/cch/config/base_branch file → check if main exists → check if master exists → error
branch_base() {
  # Tier 1: config file
  local config_file="$CCH_STATE_DIR/config/base_branch"
  if [[ -f "$config_file" ]]; then
    local configured
    configured="$(cat "$config_file")"
    if [[ -n "$configured" ]]; then
      echo "$configured"
      return 0
    fi
  fi

  # Tier 2: main exists in git
  if git rev-parse --verify "main" &>/dev/null; then
    echo "main"
    return 0
  fi

  # Tier 3: master exists in git
  if git rev-parse --verify "master" &>/dev/null; then
    echo "master"
    return 0
  fi

  echo "[cch] ERROR: No base branch found (main/master). Set one in $CCH_STATE_DIR/config/base_branch" >&2
  return 1
}

# --- Commands ---

cmd_branch() {
  local action="${1:-list}"
  shift || true

  case "$action" in
    create)  branch_create "$@" ;;
    list)    branch_list "$@" ;;
    current) branch_current "$@" ;;
    cleanup) branch_cleanup "$@" ;;
    base)    branch_base ;;
    *)
      echo "[cch] Usage: cch branch [create|list|current|cleanup|base] ..."
      return 1
      ;;
  esac
}

# G3, G5, G7, G10, G14: Create a feature branch with safety checks
branch_create() {
  local type="${1:-}"
  local work_id="${2:-}"

  if [[ -z "$type" || -z "$work_id" ]]; then
    echo "[cch] Usage: cch branch create <type> <work-id> [slug]"
    return 1
  fi

  local slug="${3:-$work_id}"
  local branch_name="${type}/${slug}"

  # G7: Uncommitted changes check (no auto-stash)
  if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet HEAD 2>/dev/null; then
    echo "[cch] ERROR: Uncommitted changes detected."
    echo "[cch] Run: git stash (to save changes temporarily)"
    return 1
  fi

  # G14: Base branch fallback chain
  local base
  base="$(branch_base)"
  if ! git rev-parse --verify "$base" &>/dev/null; then
    if git rev-parse --verify "master" &>/dev/null; then
      echo "[cch] WARN: '$base' not found, using 'master'"
      base="master"
    elif git rev-parse --verify "origin/main" &>/dev/null; then
      git checkout -b main origin/main
      base="main"
    else
      echo "[cch] ERROR: No base branch found"
      return 1
    fi
  fi

  # G3: Existing branch handling (checkout instead of error)
  if git rev-parse --verify "$branch_name" &>/dev/null; then
    echo "[cch] Branch already exists: $branch_name — switching."
    git checkout "$branch_name"
    # Ensure state file exists
    _branch_ensure_state "$branch_name" "$type" "$work_id" "$slug" "$base"
    return 0
  fi
  if git ls-remote --heads origin "$branch_name" 2>/dev/null | grep -q "$branch_name"; then
    echo "[cch] Branch exists on remote: $branch_name — tracking."
    git checkout -b "$branch_name" "origin/$branch_name"
    _branch_ensure_state "$branch_name" "$type" "$work_id" "$slug" "$base"
    return 0
  fi

  # Fetch latest base
  git fetch origin "$base" 2>/dev/null || true

  # Create branch
  git checkout -b "$branch_name" "$base"

  # Write state file
  _branch_write_state "$branch_name" "$type" "$work_id" "$slug" "$base"

  echo "[cch] Branch created: $branch_name (from $base)"
}

# List active branches with work-item mapping
branch_list() {
  if [[ ! -d "$BRANCH_DIR" ]]; then
    echo "[cch] No branches tracked."
    return 0
  fi

  echo "=== Branches ==="
  local count=0
  for state_file in "$BRANCH_DIR"/*.yaml; do
    [[ ! -f "$state_file" ]] && continue

    local branch status work_id type
    branch="$(yaml_get "$state_file" "branch")"
    status="$(yaml_get "$state_file" "status")"
    work_id="$(yaml_get "$state_file" "work_id")"
    type="$(yaml_get "$state_file" "type")"

    printf "  [%-7s] %-8s %-30s %s\n" "$status" "$type" "$branch" "$work_id"
    count=$((count + 1))
  done

  if [[ $count -eq 0 ]]; then
    echo "  (none)"
  fi
}

# Show current branch info + work-item mapping
branch_current() {
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [[ -z "$current_branch" || "$current_branch" == "HEAD" ]]; then
    echo "[cch] Not on a branch (detached HEAD)."
    return 1
  fi

  echo "Branch: $current_branch"

  local sf="$BRANCH_DIR/$(branch_state_filename "$current_branch").yaml"
  if [[ -f "$sf" ]]; then
    echo "Type:     $(yaml_get "$sf" "type")"
    echo "Work-Item: $(yaml_get "$sf" "work_id")"
    echo "Bead:     $(yaml_get "$sf" "bead_id")"
    echo "Base:     $(yaml_get "$sf" "base")"
    echo "Status:   $(yaml_get "$sf" "status")"
    echo "Created:  $(yaml_get "$sf" "created_at")"
  else
    echo "(not tracked by cch)"
  fi
}

# G4: Cleanup merged branches (status: merged only, no time-based deletion)
branch_cleanup() {
  if [[ ! -d "$BRANCH_DIR" ]]; then
    echo "[cch] No branches to clean up."
    return 0
  fi

  local current
  current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  local cleaned=0

  for state_file in "$BRANCH_DIR"/*.yaml; do
    [[ ! -f "$state_file" ]] && continue
    [[ "$(yaml_get "$state_file" "status")" != "merged" ]] && continue

    local branch
    branch="$(yaml_get "$state_file" "branch")"

    # Never delete current branch
    if [[ "$branch" != "$current" ]]; then
      git branch -d "$branch" 2>/dev/null && echo "[cch] Deleted branch: $branch"
    fi

    rm -f "$state_file"
    cleaned=$((cleaned + 1))
  done

  echo "[cch] Cleaned up $cleaned merged branch(es)."
}

# --- Internal helpers ---

_branch_write_state() {
  local branch="$1" type="$2" work_id="$3" slug="$4" base="$5"
  mkdir -p "$BRANCH_DIR"

  local sf="$BRANCH_DIR/$(branch_state_filename "$branch").yaml"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Resolve bead_id from execution plan if available
  local bead_id=""
  local exec_plan="$CCH_STATE_DIR/execution-plan.json"
  if [[ -f "$exec_plan" ]]; then
    bead_id="$(sed -n 's/.*"bead_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$exec_plan" | head -1)"
  fi

  cat > "$sf" <<EOF
branch: ${branch}
type: ${type}
work_id: ${work_id}
bead_id: ${bead_id}
slug: ${slug}
base: ${base}
created_at: ${now}
status: active
EOF
}

_branch_ensure_state() {
  local branch="$1" type="$2" work_id="$3" slug="$4" base="$5"
  local sf="$BRANCH_DIR/$(branch_state_filename "$branch").yaml"
  if [[ ! -f "$sf" ]]; then
    _branch_write_state "$branch" "$type" "$work_id" "$slug" "$base"
  fi
}
