#!/usr/bin/env bash
# beads.sh - Beads (bd) adapter for CCH
# Wraps bd CLI to provide cch beads subcommands
# Requires: bd CLI (https://github.com/beads-project/beads)

# --- Prerequisites ---

# Check bd CLI availability
beads_check() {
  if ! command -v bd &>/dev/null; then
    echo "[cch] ERROR: bd CLI not found. Install from https://github.com/beads-project/beads"
    return 1
  fi

  if [[ ! -d "$CCH_ROOT/.beads" ]]; then
    echo "[cch] ERROR: .beads/ not initialized. Run: bd init --prefix cch"
    return 1
  fi

  return 0
}

# --- JSON helpers ---

# Extract a string field from single-object JSON (no jq dependency)
_bd_json_field() {
  local json="$1" field="$2"
  echo "$json" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

# --- CCH FSM ↔ Beads status mapping ---
# CCH:   todo → doing → blocked → done
# Beads: open → in_progress → blocked → closed

_cch_to_beads_status() {
  case "$1" in
    todo)    echo "open" ;;
    doing)   echo "in_progress" ;;
    blocked) echo "blocked" ;;
    done)    echo "closed" ;;
    *)       echo "$1" ;;  # pass-through for native beads statuses
  esac
}

_beads_to_cch_status() {
  case "$1" in
    open)        echo "todo" ;;
    in_progress) echo "doing" ;;
    blocked)     echo "blocked" ;;
    closed)      echo "done" ;;
    *)           echo "$1" ;;
  esac
}

# --- Core adapter functions ---

beads_create() {
  beads_check || return 1

  local title="" type="task" priority="2" labels="" description=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)        type="$2"; shift 2 ;;
      --priority)    priority="$2"; shift 2 ;;
      --labels)      labels="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      -*)
        echo "[cch] ERROR: Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$title" ]]; then
          title="$1"
        else
          title="$title $1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$title" ]]; then
    echo "[cch] Usage: cch beads create <title> [--type task|bug|feature] [--priority 0-4] [--labels l1,l2] [--description text]"
    return 1
  fi

  local args=(bd create "$title" --priority "$priority" --json --silent)
  [[ -n "$labels" ]] && args+=(--labels "$labels")
  [[ -n "$description" ]] && args+=(--description "$description")

  local output
  output=$("${args[@]}" 2>&1) || {
    echo "[cch] ERROR: bd create failed: $output"
    return 1
  }

  local bead_id
  bead_id=$(_bd_json_field "$output" "id")

  if [[ -z "$bead_id" ]]; then
    echo "[cch] ERROR: Failed to parse bead ID from output"
    return 1
  fi

  echo "[cch] Bead created: $bead_id ($title)"
  echo "$bead_id"
}

beads_update() {
  beads_check || return 1

  local bead_id="${1:-}"
  shift || true

  if [[ -z "$bead_id" ]]; then
    echo "[cch] Usage: cch beads update <bead-id> [--priority N] [--labels l1,l2] [--description text]"
    return 1
  fi

  local args=(bd update "$bead_id" --json)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --priority)    args+=(--priority "$2"); shift 2 ;;
      --labels)      args+=(--add-label "$2"); shift 2 ;;
      --description) args+=(--description "$2"); shift 2 ;;
      --status)      args+=(--status "$(_cch_to_beads_status "$2")"); shift 2 ;;
      *)             args+=("$1"); shift ;;
    esac
  done

  local output
  output=$("${args[@]}" 2>&1) || {
    echo "[cch] ERROR: bd update failed: $output"
    return 1
  }

  echo "[cch] Bead updated: $bead_id"
}

beads_transition() {
  beads_check || return 1

  local bead_id="${1:-}" target="${2:-}"

  if [[ -z "$bead_id" || -z "$target" ]]; then
    echo "[cch] Usage: cch beads transition <bead-id> <todo|doing|blocked|done>"
    return 1
  fi

  # Map CCH state names to beads operations
  case "$target" in
    todo)
      # Reopen to open state
      bd reopen "$bead_id" 2>&1 || {
        echo "[cch] ERROR: Failed to reopen $bead_id"
        return 1
      }
      echo "[cch] $bead_id → todo (open)"
      ;;
    doing)
      local beads_status
      beads_status=$(_cch_to_beads_status "$target")
      bd update "$bead_id" --status "$beads_status" 2>/dev/null || {
        echo "[cch] ERROR: Failed to transition $bead_id to $target"
        return 1
      }
      echo "[cch] $bead_id → doing (in_progress)"
      ;;
    blocked)
      bd update "$bead_id" --status blocked 2>/dev/null || {
        echo "[cch] ERROR: Failed to transition $bead_id to blocked"
        return 1
      }
      echo "[cch] $bead_id → blocked"
      ;;
    done)
      bd close "$bead_id" 2>/dev/null || {
        echo "[cch] ERROR: Failed to close $bead_id"
        return 1
      }
      echo "[cch] $bead_id → done (closed)"
      ;;
    *)
      echo "[cch] ERROR: Invalid state '$target'. Valid: todo, doing, blocked, done"
      return 1
      ;;
  esac
}

beads_close() {
  beads_check || return 1

  local bead_id="${1:-}" reason=""
  shift || true

  if [[ -z "$bead_id" ]]; then
    echo "[cch] Usage: cch beads close <bead-id> [--reason text]"
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason) reason="$2"; shift 2 ;;
      *)        shift ;;
    esac
  done

  local args=(bd close "$bead_id")
  [[ -n "$reason" ]] && args+=(--reason "$reason")

  local output
  output=$("${args[@]}" 2>&1) || {
    echo "[cch] ERROR: bd close failed: $output"
    return 1
  }

  echo "[cch] Bead closed: $bead_id"
}

beads_ready() {
  beads_check || return 1

  local limit="5" label="" json_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit) limit="$2"; shift 2 ;;
      --label) label="$2"; shift 2 ;;
      --json)  json_flag="--json"; shift ;;
      *)       shift ;;
    esac
  done

  # bd list with filters: open status, sorted by priority, unblocked only
  local args=(bd list --status open --limit "$limit")
  [[ -n "$label" ]] && args+=(--label "$label")
  [[ -n "$json_flag" ]] && args+=("$json_flag")

  "${args[@]}" 2>&1
}

beads_show() {
  beads_check || return 1

  local bead_id="${1:-}" json_flag=""
  shift || true

  if [[ -z "$bead_id" ]]; then
    echo "[cch] Usage: cch beads show <bead-id> [--json]"
    return 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_flag="--json"; shift ;;
      *)      shift ;;
    esac
  done

  local args=(bd show "$bead_id")
  [[ -n "$json_flag" ]] && args+=("$json_flag")

  "${args[@]}" 2>&1
}

beads_list() {
  beads_check || return 1

  local status="" label="" limit="" json_flag="" all_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status="$2"; shift 2 ;;
      --label)  label="$2"; shift 2 ;;
      --limit)  limit="$2"; shift 2 ;;
      --json)   json_flag="--json"; shift ;;
      --all)    all_flag="--all"; shift ;;
      *)        shift ;;
    esac
  done

  local args=(bd list)
  if [[ -n "$status" ]]; then
    # Map CCH status names to beads
    local beads_status
    beads_status=$(_cch_to_beads_status "$status")
    args+=(--status "$beads_status")
  fi
  [[ -n "$label" ]] && args+=(--label "$label")
  [[ -n "$limit" ]] && args+=(--limit "$limit")
  [[ -n "$json_flag" ]] && args+=("$json_flag")
  [[ -n "$all_flag" ]] && args+=("$all_flag")

  "${args[@]}" 2>&1
}

beads_dep_add() {
  beads_check || return 1

  local bead_id="${1:-}" depends_on="${2:-}"

  if [[ -z "$bead_id" || -z "$depends_on" ]]; then
    echo "[cch] Usage: cch beads dep <bead-id> <depends-on-id>"
    echo "  Creates dependency: <bead-id> is blocked by <depends-on-id>"
    return 1
  fi

  local output
  output=$(bd dep add "$bead_id" "$depends_on" 2>&1) || {
    echo "[cch] ERROR: bd dep add failed: $output"
    return 1
  }

  echo "[cch] Dependency added: $bead_id depends on $depends_on"
}

# --- Command entry point ---

cmd_beads() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    check)      beads_check ;;
    create)     beads_create "$@" ;;
    update)     beads_update "$@" ;;
    transition|tr) beads_transition "$@" ;;
    close)      beads_close "$@" ;;
    ready)      beads_ready "$@" ;;
    show)       beads_show "$@" ;;
    list)       beads_list "$@" ;;
    dep)        beads_dep_add "$@" ;;
    help|--help|-h)
      cat <<'EOF'
[cch] Beads adapter - project-level task tracking via bd CLI

Usage: cch beads <command> [options]

Commands:
  check                          Verify bd CLI and .beads/ availability
  create <title> [opts]          Create a bead (--type, --priority, --labels, --description)
  update <id> [opts]             Update a bead (--priority, --labels, --description, --status)
  transition <id> <state>        Transition state (todo|doing|blocked|done)
  close <id> [--reason text]     Close a bead
  ready [--limit N] [--label L]  Show actionable beads (unblocked, open)
  show <id> [--json]             Show bead details
  list [--status S] [--label L]  List beads (--json, --all)
  dep <id> <depends-on-id>       Add dependency
  help                           Show this help

State mapping (CCH → Beads):
  todo → open | doing → in_progress | blocked → blocked | done → closed
EOF
      ;;
    *)
      echo "[cch] Unknown beads command: $action"
      echo "[cch] Run 'cch beads help' for usage"
      return 1
      ;;
  esac
}
