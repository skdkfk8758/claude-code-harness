#!/usr/bin/env bash
# test_phase5.sh - Phase 5 Supply Chain & Operations integration verification
# Task: cch-7xp (#49)

set -euo pipefail

CCH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

_check() {
  local label="$1"
  local result="$2"  # "pass" or "fail"
  local detail="${3:-}"
  if [[ "$result" == "pass" ]]; then
    echo "  [PASS] $label"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label${detail:+ — $detail}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Phase 5 Integration Verification ==="
echo ""

# 1. Release manifest schema exists
if [[ -f "$CCH_ROOT/manifests/release-manifest-schema.json" ]]; then
  _check "release-manifest-schema.json exists" "pass"
else
  _check "release-manifest-schema.json exists" "fail" "file missing"
fi

# 2. Release channels definition exists
if [[ -f "$CCH_ROOT/manifests/release-channels.json" ]]; then
  _check "release-channels.json exists" "pass"
else
  _check "release-channels.json exists" "fail" "file missing"
fi

# 3. KPI schema exists
if [[ -f "$CCH_ROOT/manifests/kpi-schema.json" ]]; then
  _check "kpi-schema.json exists" "pass"
else
  _check "kpi-schema.json exists" "fail" "file missing"
fi

# 4. KPI module exists and passes bash syntax check
if [[ -f "$CCH_ROOT/bin/lib/kpi.sh" ]]; then
  _check "bin/lib/kpi.sh exists" "pass"
  if bash -n "$CCH_ROOT/bin/lib/kpi.sh" 2>/dev/null; then
    _check "bin/lib/kpi.sh syntax valid" "pass"
  else
    _check "bin/lib/kpi.sh syntax valid" "fail" "bash -n reported errors"
  fi
else
  _check "bin/lib/kpi.sh exists" "fail" "file missing"
  _check "bin/lib/kpi.sh syntax valid" "fail" "file missing"
fi

# 5. SLO definitions exist
if [[ -f "$CCH_ROOT/manifests/slo-definitions.json" ]]; then
  _check "slo-definitions.json exists" "pass"
else
  _check "slo-definitions.json exists" "fail" "file missing"
fi

# 6. JSON syntax validation for all Phase 5 JSON files
echo ""
echo "--- JSON syntax validation ---"
json_files=(
  "$CCH_ROOT/manifests/release-manifest-schema.json"
  "$CCH_ROOT/manifests/release-channels.json"
  "$CCH_ROOT/manifests/kpi-schema.json"
  "$CCH_ROOT/manifests/slo-definitions.json"
)

for f in "${json_files[@]}"; do
  fname="$(basename "$f")"
  if [[ ! -f "$f" ]]; then
    _check "$fname JSON valid" "fail" "file missing"
    continue
  fi
  # Validate JSON using python3 (portable, no jq required)
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    _check "$fname JSON valid" "pass"
  else
    _check "$fname JSON valid" "fail" "invalid JSON"
  fi
done

# Also validate bin/cch loads kpi.sh (check source line present)
echo ""
echo "--- Integration checks ---"
if grep -q 'kpi\.sh' "$CCH_ROOT/bin/cch" 2>/dev/null; then
  _check "bin/cch loads kpi.sh" "pass"
else
  _check "bin/cch loads kpi.sh" "fail" "source line missing"
fi

if grep -q 'dot-report' "$CCH_ROOT/bin/cch" 2>/dev/null; then
  _check "bin/cch dispatches dot-report" "pass"
else
  _check "bin/cch dispatches dot-report" "fail" "dispatch missing"
fi

if grep -q '_generate_release_manifest' "$CCH_ROOT/bin/lib/sources.sh" 2>/dev/null; then
  _check "sources.sh has _generate_release_manifest" "pass"
else
  _check "sources.sh has _generate_release_manifest" "fail" "function missing"
fi

if grep -q '_generate_release_manifest' "$CCH_ROOT/bin/lib/sources.sh" 2>/dev/null && \
   grep -q 'sources_lock' "$CCH_ROOT/bin/lib/sources.sh" 2>/dev/null; then
  # Check that sources_lock calls _generate_release_manifest
  if awk '/^sources_lock\(\)/,/^\}/' "$CCH_ROOT/bin/lib/sources.sh" | grep -q '_generate_release_manifest'; then
    _check "sources_lock calls _generate_release_manifest" "pass"
  else
    _check "sources_lock calls _generate_release_manifest" "fail" "call missing in sources_lock body"
  fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "Phase 5 통합 검증 PASS"
  exit 0
else
  echo "Phase 5 통합 검증 FAIL ($FAIL checks failed)"
  exit 1
fi
