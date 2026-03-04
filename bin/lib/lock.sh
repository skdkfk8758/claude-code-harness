#!/usr/bin/env bash
# lock.sh - Concurrency control via lock files

CCH_LOCK_DIR="${CCH_STATE_DIR:-.claude/cch}/locks"

# Acquire a lock (non-blocking, returns 1 if already locked)
lock_acquire() {
  local name="$1" timeout="${2:-0}"
  local lockfile="$CCH_LOCK_DIR/${name}.lock"
  mkdir -p "$CCH_LOCK_DIR"

  # Check if lock exists and is stale (> 10 minutes)
  if [[ -f "$lockfile" ]]; then
    local lock_age=$(( $(date +%s) - $(stat -f %m "$lockfile" 2>/dev/null || echo 0) ))
    if [[ $lock_age -gt 600 ]]; then
      echo "[cch] Removing stale lock: $name (age: ${lock_age}s)"
      rm -f "$lockfile"
    else
      echo "[cch] Lock held: $name (age: ${lock_age}s)"
      return 1
    fi
  fi

  # Create lock with PID
  echo "$$" > "$lockfile"
  return 0
}

# Release a lock
lock_release() {
  local name="$1"
  local lockfile="$CCH_LOCK_DIR/${name}.lock"
  rm -f "$lockfile"
}

# Check if locked
lock_check() {
  local name="$1"
  local lockfile="$CCH_LOCK_DIR/${name}.lock"
  [[ -f "$lockfile" ]]
}

# Run a command with a lock
lock_run() {
  local name="$1"; shift
  if ! lock_acquire "$name"; then
    echo "[cch] ERROR: Cannot acquire lock: $name"
    return 1
  fi
  local rc=0
  "$@" || rc=$?
  lock_release "$name"
  return $rc
}
