#!/usr/bin/env bash
# cch arch - Architecture level management module
# Storage: .claude/cch/state/arch_level, .claude/cch/state/tdd_enabled
# Implements adaptive architecture levels with TDD enforcement

ARCH_MANIFEST="$CCH_ROOT/manifests/architecture-levels.json"
ARCH_LEVEL_FILE="$CCH_STATE_DIR/state/arch_level"
TDD_ENABLED_FILE="$CCH_STATE_DIR/state/tdd_enabled"
TDD_METRICS_DIR="$CCH_STATE_DIR/metrics"

# --- Helpers ---

# Read a JSON field from architecture-levels.json using lightweight parsing
# Usage: arch_json_get <jq-filter>
arch_json_get() {
  local filter="$1"
  if command -v jq &>/dev/null; then
    jq -r "$filter" "$ARCH_MANIFEST" 2>/dev/null
  else
    # Fallback: python3
    python3 -c "import json,sys; d=json.load(open('$ARCH_MANIFEST')); print(eval('d' + '$filter'.replace('.','[\"').replace('[\"','[\"',1).replace(']','\"]')))" 2>/dev/null || echo ""
  fi
}

# Get current architecture level (empty if not set)
arch_current_level() {
  if [[ -f "$ARCH_LEVEL_FILE" ]]; then
    cat "$ARCH_LEVEL_FILE"
  fi
}

# Get level name from manifest
arch_level_name() {
  local level="$1"
  if command -v jq &>/dev/null; then
    jq -r ".levels.\"$level\".name // empty" "$ARCH_MANIFEST" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$ARCH_MANIFEST'))
print(d.get('levels',{}).get('$level',{}).get('name',''))
" 2>/dev/null || echo ""
  fi
}

# Get level alias from manifest
arch_level_alias() {
  local level="$1"
  if command -v jq &>/dev/null; then
    jq -r ".levels.\"$level\".alias // empty" "$ARCH_MANIFEST" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$ARCH_MANIFEST'))
print(d.get('levels',{}).get('$level',{}).get('alias',''))
" 2>/dev/null || echo ""
  fi
}

# Get required dirs for a level as newline-separated list
arch_required_dirs() {
  local level="$1"
  if command -v jq &>/dev/null; then
    jq -r ".levels.\"$level\".structure.required_dirs[]" "$ARCH_MANIFEST" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$ARCH_MANIFEST'))
for p in d.get('levels',{}).get('$level',{}).get('structure',{}).get('required_dirs',[]):
    print(p)
" 2>/dev/null
  fi
}

# Get bounded context layout dirs (Level 3 only)
arch_bc_layout() {
  local level="$1"
  if command -v jq &>/dev/null; then
    jq -r ".levels.\"$level\".structure.bounded_context_layout // [] | .[]" "$ARCH_MANIFEST" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$ARCH_MANIFEST'))
for p in d.get('levels',{}).get('$level',{}).get('structure',{}).get('bounded_context_layout',[]):
    print(p)
" 2>/dev/null
  fi
}

# Get min_test_ratio for a level
arch_min_test_ratio() {
  local level="$1"
  if command -v jq &>/dev/null; then
    jq -r ".levels.\"$level\".rules.min_test_ratio // empty" "$ARCH_MANIFEST" 2>/dev/null
  else
    python3 -c "
import json
d=json.load(open('$ARCH_MANIFEST'))
print(d.get('levels',{}).get('$level',{}).get('rules',{}).get('min_test_ratio',''))
" 2>/dev/null
  fi
}

# Ensure TDD is always enabled
arch_ensure_tdd() {
  mkdir -p "$(dirname "$TDD_ENABLED_FILE")"
  echo "true" > "$TDD_ENABLED_FILE"
}

# --- Commands ---

cmd_arch() {
  local action="${1:-level}"
  shift || true

  # Ensure manifest exists
  if [[ ! -f "$ARCH_MANIFEST" ]]; then
    echo "[cch] ERROR: Architecture manifest not found: $ARCH_MANIFEST"
    return 1
  fi

  case "$action" in
    level)    arch_level ;;
    set)      arch_set "$@" ;;
    check)    arch_check ;;
    scaffold) arch_scaffold ;;
    report)   arch_report ;;
    *)
      echo "[cch] Usage: cch arch [level|set|check|scaffold|report]"
      return 1
      ;;
  esac
}

# Show current architecture level
arch_level() {
  local level
  level="$(arch_current_level)"

  if [[ -z "$level" ]]; then
    echo "[cch] Architecture level: not set"
    echo "[cch] Run 'cch arch set <1|2|3>' or use /cch-arch-guide"
    return 0
  fi

  local name
  name="$(arch_level_name "$level")"
  echo "[cch] Architecture level: $level ($name)"
  echo "[cch] TDD: always ON"
}

# Set architecture level
arch_set() {
  local level="${1:-}"

  if [[ -z "$level" ]]; then
    echo "[cch] Usage: cch arch set <1|2|3>"
    return 1
  fi

  # Validate level
  if [[ "$level" != "1" && "$level" != "2" && "$level" != "3" ]]; then
    echo "[cch] ERROR: Invalid level '$level'. Must be 1, 2, or 3."
    return 1
  fi

  # Write state
  mkdir -p "$(dirname "$ARCH_LEVEL_FILE")"
  echo "$level" > "$ARCH_LEVEL_FILE"

  # Ensure TDD is enabled
  arch_ensure_tdd

  local name
  name="$(arch_level_name "$level")"
  echo "[cch] Architecture level set: $level ($name)"
  echo "[cch] TDD: always ON"
}

# Check directory structure against current level requirements
arch_check() {
  local level
  level="$(arch_current_level)"

  if [[ -z "$level" ]]; then
    echo "[cch] ERROR: Architecture level not set. Run 'cch arch set <1|2|3>' first."
    return 1
  fi

  local name
  name="$(arch_level_name "$level")"
  echo "=== Architecture Check: Level $level ($name) ==="

  local missing=0
  local total=0

  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    total=$((total + 1))
    if [[ -d "$dir" ]]; then
      echo "  [OK]   $dir"
    else
      echo "  [MISS] $dir"
      missing=$((missing + 1))
    fi
  done < <(arch_required_dirs "$level")

  echo ""
  if [[ $missing -eq 0 ]]; then
    echo "[cch] Structure check PASSED ($total/$total directories present)"
    return 0
  else
    echo "[cch] Structure check FAILED ($((total - missing))/$total directories present, $missing missing)"
    echo "[cch] Run 'cch arch scaffold' to create missing directories"
    return 2
  fi
}

# Create directory structure for current level
arch_scaffold() {
  local level
  level="$(arch_current_level)"

  if [[ -z "$level" ]]; then
    echo "[cch] ERROR: Architecture level not set. Run 'cch arch set <1|2|3>' first."
    return 1
  fi

  local name
  name="$(arch_level_name "$level")"
  echo "=== Scaffolding: Level $level ($name) ==="

  local created=0

  # Create required directories
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      echo "  [CREATED] $dir"
      created=$((created + 1))
    else
      echo "  [EXISTS]  $dir"
    fi
  done < <(arch_required_dirs "$level")

  # Level-specific README files (only create if file doesn't exist)
  case "$level" in
    1)
      if [[ ! -f "tests/README.md" ]]; then
        cat > "tests/README.md" <<'TEOF'
# Tests

테스트 파일 위치. 패턴: `test_<name>.{sh,js,ts,py}`
TEOF
        echo "  [CREATED] tests/README.md"
        created=$((created + 1))
      fi
      ;;
    2)
      _scaffold_readme "src/domain" "순수 비즈니스 로직 (외부 의존성 없음)" && created=$((created + 1))
      _scaffold_readme "src/application" "Use Case, 오케스트레이션" && created=$((created + 1))
      _scaffold_readme "src/infrastructure" "DB, API 클라이언트 등 어댑터" && created=$((created + 1))
      _scaffold_readme "src/interfaces" "HTTP 컨트롤러, CLI 핸들러" && created=$((created + 1))
      ;;
    3)
      _scaffold_readme "src/bounded-contexts" "각 하위 디렉토리가 Bounded Context" && created=$((created + 1))
      _scaffold_readme "src/shared-kernel" "공유 타입, 이벤트, 인터페이스" && created=$((created + 1))
      _scaffold_readme "tests/domain" "도메인 불변조건 테스트" && created=$((created + 1))
      ;;
  esac

  echo ""
  echo "[cch] Scaffold complete: $created new items created"
}

# Show architecture report with TDD metrics
arch_report() {
  local level
  level="$(arch_current_level)"

  echo "=== Architecture Report ==="

  if [[ -z "$level" ]]; then
    echo "Level:       not set"
  else
    local name ratio
    name="$(arch_level_name "$level")"
    ratio="$(arch_min_test_ratio "$level")"
    echo "Level:       $level ($name)"
    echo "Min Ratio:   $ratio"
  fi

  # TDD status
  echo "TDD:         always ON"

  # TDD metrics summary
  local metrics_file="$TDD_METRICS_DIR/tdd-enforcement.jsonl"
  if [[ -f "$metrics_file" ]]; then
    local total_checks=0 total_covered=0 total_missing=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if command -v jq &>/dev/null; then
        local c m
        c="$(echo "$line" | jq -r '.covered // 0')"
        m="$(echo "$line" | jq -r '.missing // 0')"
        total_covered=$((total_covered + c))
        total_missing=$((total_missing + m))
      fi
      total_checks=$((total_checks + 1))
    done < "$metrics_file"

    echo ""
    echo "=== TDD Metrics ==="
    echo "Checks:      $total_checks"
    echo "Covered:     $total_covered files"
    echo "Missing:     $total_missing files"
    if [[ $((total_covered + total_missing)) -gt 0 ]]; then
      if command -v bc &>/dev/null; then
        local coverage
        coverage="$(echo "scale=1; $total_covered * 100 / ($total_covered + $total_missing)" | bc)"
        echo "Coverage:    ${coverage}%"
      fi
    fi
  else
    echo ""
    echo "=== TDD Metrics ==="
    echo "(no enforcement data yet)"
  fi
}

# --- Internal helpers ---

# Create README.md in a directory if it doesn't exist
# Returns 0 if created, 1 if already existed
_scaffold_readme() {
  local dir="$1" desc="$2"
  if [[ ! -f "$dir/README.md" ]]; then
    cat > "$dir/README.md" <<EOF
# $(basename "$dir")

$desc
EOF
    echo "  [CREATED] $dir/README.md"
    return 0
  fi
  return 1
}
