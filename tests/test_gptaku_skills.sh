#!/usr/bin/env bash
# Layer 3: GPTaku Skills - 8개 GPTaku 스킬 SKILL.md 구조 검증

SKILLS_DIR="$ROOT_DIR/skills"

gptaku_skills=("cch-gp-team" "cch-gp-pumasi" "cch-gp-skill-builder" "cch-gp-prd" "cch-gp-research" "cch-gp-docs" "cch-gp-mentor" "cch-gp-git-learn")

for skill in "${gptaku_skills[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  assert_file_exists "gptaku skill exists: $skill" "$skill_file"

  if [[ -f "$skill_file" ]]; then
    content="$(cat "$skill_file")"

    # Check frontmatter delimiters
    assert_contains "skill $skill: has frontmatter start" "^---" "$content"

    # Check required fields
    assert_contains "skill $skill: has name field" "name:" "$content"
    assert_contains "skill $skill: has description" "description:" "$content"
    assert_contains "skill $skill: has user-invocable" "user-invocable:" "$content"
    assert_contains "skill $skill: has allowed-tools" "allowed-tools:" "$content"

    # Check GPTaku prerequisites pattern
    assert_contains "skill $skill: has prerequisites section" "Prerequisites" "$content"
    assert_contains "skill $skill: ensures gptaku source" "sources ensure gptaku_plugins" "$content"
    assert_contains "skill $skill: inits submodule" "sources init-submodule gptaku_plugins" "$content"
  fi
done

# Verify count
actual_count=$(ls -d "$SKILLS_DIR"/cch-gp-*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
assert_equals "gptaku skill count is 9" "9" "$actual_count"

# --- Phase VS: 서브모듈 경로 하이픈 일관성 검증 ---
# Parallel arrays (bash 3 compatible, no associative arrays)
path_skills=("cch-gp-prd" "cch-gp-research" "cch-gp-docs" "cch-gp-skill-builder" "cch-gp-mentor" "cch-gp-git-learn")
path_expected=("show-me-the-prd" "deep-research" "docs-guide" "skillers-suda" "vibe-sunsang" "git-teacher")

for i in "${!path_skills[@]}"; do
  skill="${path_skills[$i]}"
  expected_path="${path_expected[$i]}"
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    content="$(cat "$skill_file")"
    assert_contains "skill $skill: submodule path uses hyphens ($expected_path)" "$expected_path" "$content"
    # Verify underscore variant is NOT used
    underscore_path="${expected_path//-/_}"
    assert_not_contains "skill $skill: submodule path does not use underscores" "plugins/$underscore_path" "$content"
  fi
done

# --- Phase VS: cch-gp-playground 스킬 검증 ---
playground_file="$SKILLS_DIR/cch-gp-playground/SKILL.md"
assert_file_exists "playground skill exists" "$playground_file"

if [[ -f "$playground_file" ]]; then
  playground_content="$(cat "$playground_file")"
  assert_contains "playground: has name field" "name:" "$playground_content"
  assert_contains "playground: has description" "description:" "$playground_content"
  assert_contains "playground: has user-invocable" "user-invocable:" "$playground_content"
  assert_contains "playground: has allowed-tools" "allowed-tools:" "$playground_content"
  assert_contains "playground: ensures gptaku source" "sources ensure gptaku_plugins" "$playground_content"
  assert_contains "playground: inits submodule" "sources init-submodule gptaku_plugins" "$playground_content"
  assert_contains "playground: submodule path uses hyphens" "test-playground" "$playground_content"
fi
