#!/usr/bin/env bash
# Layer 3: Ruflo Skills - 6개 Ruflo 스킬 SKILL.md 구조 검증

SKILLS_DIR="$ROOT_DIR/skills"

ruflo_skills=("cch-rf-swarm" "cch-rf-sparc" "cch-rf-hive" "cch-rf-memory" "cch-rf-security" "cch-rf-doctor")

for skill in "${ruflo_skills[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  assert_file_exists "ruflo skill exists: $skill" "$skill_file"

  if [[ -f "$skill_file" ]]; then
    content="$(cat "$skill_file")"

    # Check frontmatter delimiters
    assert_contains "skill $skill: has frontmatter start" "^---" "$content"

    # Check required fields
    assert_contains "skill $skill: has name field" "name:" "$content"
    assert_contains "skill $skill: has description" "description:" "$content"
    assert_contains "skill $skill: has user-invocable" "user-invocable:" "$content"
    assert_contains "skill $skill: has allowed-tools" "allowed-tools:" "$content"

    # Check Ruflo prerequisites pattern
    assert_contains "skill $skill: has prerequisites section" "Prerequisites" "$content"
    assert_contains "skill $skill: ensures ruflo source" "sources ensure ruflo" "$content"
    assert_contains "skill $skill: sets RUFLO_CLI" "RUFLO_CLI" "$content"
  fi
done

# Verify count
actual_count=$(ls -d "$SKILLS_DIR"/cch-rf-*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
assert_equals "ruflo skill count is 6" "6" "$actual_count"
