#!/usr/bin/env bash
# Layer 3: Skill - 개별 스킬 SKILL.md frontmatter 필수 필드 검증

SKILLS_DIR="$ROOT_DIR/skills"

required_skills=("cch-setup" "cch-mode" "cch-status" "cch-update" "cch-dot" "omc-setup")

for skill in "${required_skills[@]}"; do
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

    # Check bin/cch mapping
    assert_contains "skill $skill: maps to bin/cch" "bin/cch" "$content"
  fi
done
