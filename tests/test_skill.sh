#!/usr/bin/env bash
# Layer 3: Skill - v2 코어 스킬 SKILL.md frontmatter 및 구조 검증

SKILLS_DIR="$ROOT_DIR/skills"

# v2 core skills
core_skills=("cch-setup" "cch-status" "cch-commit" "cch-plan" "cch-todo" "cch-verify" "cch-review" "cch-pr")

for skill in "${core_skills[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  assert_file_exists "skill exists: $skill" "$skill_file"

  if [[ -f "$skill_file" ]]; then
    content="$(cat "$skill_file")"

    # Check frontmatter delimiters
    assert_contains "skill $skill: has frontmatter start" "^---" "$content"

    # Check required fields
    assert_contains "skill $skill: has name field" "name:" "$content"
    assert_contains "skill $skill: has description" "description:" "$content"
    assert_contains "skill $skill: has user-invocable" "user-invocable:" "$content"
  fi
done

# Check Enhancement section exists in Tier-aware skills
tier_aware_skills=("cch-setup" "cch-commit" "cch-plan" "cch-todo" "cch-verify" "cch-review")

for skill in "${tier_aware_skills[@]}"; do
  skill_file="$SKILLS_DIR/$skill/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    content="$(cat "$skill_file")"
    assert_contains "skill $skill: has Enhancement section" "Enhancement" "$content"
    assert_contains "skill $skill: has Tier reference" "Tier" "$content"
  fi
done
