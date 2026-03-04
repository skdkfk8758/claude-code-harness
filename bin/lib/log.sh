#!/usr/bin/env bash
# cch log - Execution log recorder
# Storage: .claude/cch/runs/<date>/<work-id>.jsonl

RUNS_DIR="$CCH_STATE_DIR/runs"

# Internal: get log dir for today, ensure it exists
_log_dir() {
  local date_dir
  date_dir="$(date -u +%Y-%m-%d)"
  local log_dir="$RUNS_DIR/$date_dir"
  mkdir -p "$log_dir"
  echo "$log_dir"
}

# Write a JSONL log entry for the current command execution (backward compat)
log_record() {
  local work_id="${1:-_global}" cmd="$2" result="${3:-ok}" detail="${4:-}"
  local log_dir
  log_dir="$(_log_dir)"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local mode
  mode="$(cat "$CCH_STATE_DIR/mode" 2>/dev/null || echo "")"

  echo "{\"ts\":\"$ts\",\"work_id\":\"$work_id\",\"cmd\":\"$cmd\",\"result\":\"$result\",\"mode\":\"$mode\",\"detail\":\"$detail\"}" \
    >> "$log_dir/$work_id.jsonl"
}

# Record start of an execution. Sets CCH_RUN_START_* variables.
# Usage: log_start <work_id> <cmd>
log_start() {
  local work_id="${1:-_global}" cmd="${2:-}"
  local log_dir
  log_dir="$(_log_dir)"

  local start_ts
  start_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local start_epoch
  start_epoch="$(date +%s)"
  local mode
  mode="$(cat "$CCH_STATE_DIR/mode" 2>/dev/null || echo "")"

  # Export for log_end to pick up
  export CCH_RUN_WORK_ID="$work_id"
  export CCH_RUN_CMD="$cmd"
  export CCH_RUN_START_TS="$start_ts"
  export CCH_RUN_START_EPOCH="$start_epoch"
  export CCH_RUN_MODE="$mode"
  export CCH_RUN_LOG_DIR="$log_dir"

  echo "{\"event\":\"start\",\"ts\":\"$start_ts\",\"work_id\":\"$work_id\",\"cmd\":\"$cmd\",\"mode\":\"$mode\"}" \
    >> "$log_dir/$work_id.jsonl"
}

# Record end of an execution. Calculates duration from log_start.
# Usage: log_end <result> [error_class] [error_message]
log_end() {
  local result="${1:-ok}" error_class="${2:-}" error_message="${3:-}"

  # Use values from log_start
  local work_id="${CCH_RUN_WORK_ID:-_global}"
  local cmd="${CCH_RUN_CMD:-}"
  local start_ts="${CCH_RUN_START_TS:-}"
  local start_epoch="${CCH_RUN_START_EPOCH:-}"
  local mode="${CCH_RUN_MODE:-}"
  local log_dir="${CCH_RUN_LOG_DIR:-}"

  # Fallback if log_start wasn't called
  if [[ -z "$log_dir" ]]; then
    log_dir="$(_log_dir)"
  fi

  local end_ts
  end_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local duration_ms=0
  if [[ -n "$start_epoch" ]]; then
    local end_epoch
    end_epoch="$(date +%s)"
    duration_ms=$(( (end_epoch - start_epoch) * 1000 ))
  fi

  # Build JSON entry
  local entry="{\"event\":\"end\",\"ts\":\"$end_ts\",\"work_id\":\"$work_id\",\"cmd\":\"$cmd\",\"result\":\"$result\",\"mode\":\"$mode\""
  entry+=",\"start\":\"$start_ts\",\"end\":\"$end_ts\",\"duration_ms\":$duration_ms"
  if [[ -n "$error_class" ]]; then
    entry+=",\"error_class\":\"$error_class\""
  fi
  if [[ -n "$error_message" ]]; then
    # Escape double quotes in error message
    local safe_msg="${error_message//\"/\\\"}"
    entry+=",\"error_message\":\"$safe_msg\""
  fi

  # Append health + reason_codes (shared with cch status)
  local _health _health_reason
  _health="$(cat "$CCH_STATE_DIR/health" 2>/dev/null || echo "")"
  _health_reason="$(cat "$CCH_STATE_DIR/health_reason" 2>/dev/null || echo "")"
  if [[ -n "$_health" ]]; then
    entry+=",\"health\":\"$_health\""
  fi
  if [[ -n "$_health_reason" ]]; then
    entry+=",\"reason_codes\":\"$_health_reason\""
  fi
  entry+="}"

  echo "$entry" >> "$log_dir/$work_id.jsonl"

  # Clean up env
  unset CCH_RUN_WORK_ID CCH_RUN_CMD CCH_RUN_START_TS CCH_RUN_START_EPOCH CCH_RUN_MODE CCH_RUN_LOG_DIR
}

cmd_log() {
  local action="${1:-show}"
  shift || true

  case "$action" in
    show)  log_show "$@" ;;
    tail)  log_tail "$@" ;;
    *)
      echo "[cch] Usage: cch log [show|tail] [work-id]"
      return 1
      ;;
  esac
}

log_show() {
  local work_id="${1:-}"

  if [[ ! -d "$RUNS_DIR" ]]; then
    echo "[cch] No execution logs."
    return 0
  fi

  echo "=== Execution Logs ==="

  if [[ -n "$work_id" ]]; then
    # Show logs for specific work-id across all dates
    find "$RUNS_DIR" -name "${work_id}.jsonl" -type f | sort | while read -r f; do
      local date_part
      date_part="$(basename "$(dirname "$f")")"
      echo "--- $date_part ---"
      cat "$f"
    done
  else
    # Show all recent logs (today)
    local today
    today="$(date -u +%Y-%m-%d)"
    local today_dir="$RUNS_DIR/$today"
    if [[ -d "$today_dir" ]]; then
      echo "--- $today ---"
      for f in "$today_dir"/*.jsonl; do
        [[ ! -f "$f" ]] && continue
        local wid
        wid="$(basename "$f" .jsonl)"
        echo "  [$wid]"
        cat "$f" | while read -r line; do
          echo "    $line"
        done
      done
    else
      echo "  No logs for today."
    fi
  fi
}

log_tail() {
  local work_id="${1:-_global}" n="${2:-10}"

  if [[ ! -d "$RUNS_DIR" ]]; then
    echo "[cch] No execution logs."
    return 0
  fi

  # Find the most recent log file for this work-id
  local latest
  latest="$(find "$RUNS_DIR" -name "${work_id}.jsonl" -type f | sort | tail -1)"

  if [[ -z "$latest" ]]; then
    echo "[cch] No logs found for: $work_id"
    return 0
  fi

  echo "=== Last $n entries: $work_id ==="
  tail -"$n" "$latest"
}
