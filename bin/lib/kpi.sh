#!/usr/bin/env bash
# kpi.sh - KPI metrics collection and display
# Normalized per manifests/kpi-schema.json

cmd_kpi_dashboard() {
  local action="${1:-show}"
  case "$action" in
    show)
      _kpi_collect
      _kpi_display
      ;;
    --json)
      _kpi_collect
      _kpi_display_json
      ;;
    *)
      echo "[cch] Usage: cch kpi dashboard [show [--json]]"
      ;;
  esac
}

_kpi_collect() {
  # sources_available / sources_total
  KPI_SOURCES_TOTAL=0
  KPI_SOURCES_AVAILABLE=0
  local names
  names="$(sources_list 2>/dev/null)" || names=""
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    KPI_SOURCES_TOTAL=$((KPI_SOURCES_TOTAL + 1))
    sources_is_installed "$src" 2>/dev/null && KPI_SOURCES_AVAILABLE=$((KPI_SOURCES_AVAILABLE + 1))
  done <<< "$names"

  # health_score = available/total * 100
  KPI_HEALTH_SCORE=0
  [[ "$KPI_SOURCES_TOTAL" -gt 0 ]] && \
    KPI_HEALTH_SCORE=$(( KPI_SOURCES_AVAILABLE * 100 / KPI_SOURCES_TOTAL ))

  # lock_drift_count
  KPI_LOCK_DRIFT=0
  sources_check_lock 2>/dev/null || KPI_LOCK_DRIFT=1
}

_kpi_display() {
  echo "=== CCH KPI Dashboard ==="
  echo "Sources: ${KPI_SOURCES_AVAILABLE}/${KPI_SOURCES_TOTAL} available"
  echo "Health Score: ${KPI_HEALTH_SCORE}%"
  echo "Lock Drift: ${KPI_LOCK_DRIFT}"
}

_kpi_display_json() {
  printf '{"sources_available":%d,"sources_total":%d,"health_score":%d,"lock_drift_count":%d}\n' \
    "$KPI_SOURCES_AVAILABLE" "$KPI_SOURCES_TOTAL" "$KPI_HEALTH_SCORE" "$KPI_LOCK_DRIFT"
}

# DOT gate auto-determination report (Task 5: cch-4o7)
cmd_dot_report() {
  echo "=== DOT Gate Report ==="
  local dot_enabled=false
  local mode_file="$CCH_STATE_DIR/mode"
  local current_mode="code"
  [[ -f "$mode_file" ]] && current_mode="$(cat "$mode_file")"

  # Check DOT eligibility from profile
  local profile="$CCH_ROOT/profiles/${current_mode}.json"
  if [[ -f "$profile" ]]; then
    local eligible
    eligible=$(grep -o '"eligible"[[:space:]]*:[[:space:]]*[a-z]*' "$profile" | head -1 | grep -o 'true\|false')
    [[ "$eligible" == "true" ]] && dot_enabled=true
  fi

  echo "Mode: $current_mode"
  echo "DOT Eligible: $dot_enabled"
  echo "DOT Source: $(sources_is_installed dot 2>/dev/null && echo 'installed' || echo 'not installed')"

  if [[ "$dot_enabled" == "true" ]] && sources_is_installed dot 2>/dev/null; then
    echo "Gate: PASS (DOT available and eligible)"
  elif [[ "$dot_enabled" == "true" ]]; then
    echo "Gate: WARN (DOT eligible but source not installed)"
  else
    echo "Gate: N/A (DOT not eligible in $current_mode mode)"
  fi
}
