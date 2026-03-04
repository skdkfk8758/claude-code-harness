#!/usr/bin/env bash
# tdd-enforcer.sh - PostToolUse hook for TDD enforcement
# Detects git commit in Bash tool usage and checks for corresponding test files
# Principle: warn, not block — raise awareness without breaking flow

set -euo pipefail

# Read hook input from stdin
input="$(cat)"

# Extract tool name and command from JSON input
tool_name="$(echo "$input" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"

# Only process Bash tool calls
if [[ "$tool_name" != "Bash" ]]; then
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
fi

# Check if the command contains git commit
tool_input="$(echo "$input" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"

if ! echo "$tool_input" | grep -q "git commit"; then
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
fi

# --- Git commit detected: check for test coverage ---

# Get list of committed files (from last commit)
committed_files="$(git diff --name-only HEAD~1..HEAD 2>/dev/null)" || {
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
}

# Non-source file patterns to exclude
skip_patterns='\.md$|\.json$|\.yaml$|\.yml$|\.toml$|\.env|\.lock$|\.txt$|\.csv$|\.svg$|\.png$|\.jpg$|\.gif$|LICENSE|CHANGELOG|README|Makefile|Dockerfile|\.dockerignore|\.gitignore|\.editorconfig'
# Also exclude files already in test directories
test_dir_patterns='^tests/|^test/|^__tests__/|\.test\.|\.spec\.|^spec/'

missing_tests=()
checked=0
covered=0

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Skip non-source files
  if echo "$file" | grep -qE "$skip_patterns"; then
    continue
  fi

  # Skip files already in test directories
  if echo "$file" | grep -qE "$test_dir_patterns"; then
    continue
  fi

  checked=$((checked + 1))

  # Extract base name without extension
  local_basename="$(basename "$file")"
  name_no_ext="${local_basename%.*}"

  # Check for corresponding test file patterns
  found_test=false
  for pattern in "test_${name_no_ext}" "${name_no_ext}.test" "${name_no_ext}.spec" "${name_no_ext}_test"; do
    if git ls-files | grep -q "$pattern"; then
      found_test=true
      break
    fi
  done

  if [[ "$found_test" == "true" ]]; then
    covered=$((covered + 1))
  else
    missing_tests+=("$file")
  fi
done <<< "$committed_files"

# Record metrics
metrics_dir=".claude/cch/metrics"
mkdir -p "$metrics_dir"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "{\"ts\":\"$now\",\"checked\":$checked,\"covered\":$covered,\"missing\":${#missing_tests[@]},\"files\":[$(printf '"%s",' "${missing_tests[@]}" | sed 's/,$//')]}" >> "$metrics_dir/tdd-enforcement.jsonl"

# If there are missing tests, add warning context (do NOT block)
if [[ ${#missing_tests[@]} -gt 0 ]]; then
  missing_list=""
  for f in "${missing_tests[@]}"; do
    missing_list="${missing_list}\n  - ${f}"
  done

  cat <<EOJSON
{"continue":true,"additionalContext":"[TDD Enforcer] ⚠️ ${#missing_tests[@]}개 소스 파일에 대응 테스트가 없습니다:${missing_list}\n\n테스트 파일 패턴: test_<name>.*, <name>.test.*, <name>.spec.*\nTDD 정책: 테스트 작성을 권장합니다 (차단하지 않음)."}
EOJSON
else
  if [[ $checked -gt 0 ]]; then
    echo "{\"continue\":true,\"additionalContext\":\"[TDD Enforcer] ✅ 커밋된 ${checked}개 소스 파일 모두 테스트가 존재합니다.\"}"
  else
    echo '{"continue":true,"suppressOutput":true}'
  fi
fi
