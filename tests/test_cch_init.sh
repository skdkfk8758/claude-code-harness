#!/usr/bin/env bash
# cch-init system integration tests
# Tests skill file existence, frontmatter validity, orchestrator structure,
# mode branching, and sub-skill content contracts.

SKILLS_DIR="$ROOT_DIR/skills"

# ── 1. Skill file existence ───────────────────────────────────────────────────

echo ""
echo "--- 1. Skill file existence ---"

for skill in cch-init cch-init-scan cch-init-docs cch-init-scaffold; do
  assert_file_exists "skill exists: $skill" "$SKILLS_DIR/$skill/SKILL.md"
done

# ── 2. Frontmatter validity ───────────────────────────────────────────────────

echo ""
echo "--- 2. Frontmatter validity ---"

# Helper: read content only when file exists (avoids cat errors)
_read_skill() {
  local path="$SKILLS_DIR/$1/SKILL.md"
  [[ -f "$path" ]] && cat "$path" || echo ""
}

# cch-init: user-invocable true, name, description, allowed-tools, argument-hint
INIT_CONTENT="$(_read_skill cch-init)"
assert_contains "cch-init: has frontmatter" "^---" "$INIT_CONTENT"
assert_contains "cch-init: has name"          "name:"           "$INIT_CONTENT"
assert_contains "cch-init: has description"   "description:"    "$INIT_CONTENT"
assert_contains "cch-init: user-invocable true" "user-invocable: true" "$INIT_CONTENT"
assert_contains "cch-init: has allowed-tools" "allowed-tools:"  "$INIT_CONTENT"
assert_contains "cch-init: has argument-hint" "argument-hint:"  "$INIT_CONTENT"

# cch-init-scan: user-invocable false, allowed-tools includes Glob/Grep/Bash/Read
SCAN_CONTENT="$(_read_skill cch-init-scan)"
assert_contains "cch-init-scan: has frontmatter"       "^---"                  "$SCAN_CONTENT"
assert_contains "cch-init-scan: user-invocable false"  "user-invocable: false" "$SCAN_CONTENT"
assert_contains "cch-init-scan: allowed-tools has Glob" "Glob"                 "$SCAN_CONTENT"
assert_contains "cch-init-scan: allowed-tools has Grep" "Grep"                 "$SCAN_CONTENT"
assert_contains "cch-init-scan: allowed-tools has Bash" "Bash"                 "$SCAN_CONTENT"
assert_contains "cch-init-scan: allowed-tools has Read" "Read"                 "$SCAN_CONTENT"

# cch-init-docs: user-invocable false, allowed-tools includes Agent/Write
DOCS_CONTENT="$(_read_skill cch-init-docs)"
assert_contains "cch-init-docs: has frontmatter"       "^---"                  "$DOCS_CONTENT"
assert_contains "cch-init-docs: user-invocable false"  "user-invocable: false" "$DOCS_CONTENT"
assert_contains "cch-init-docs: allowed-tools has Agent" "Agent"               "$DOCS_CONTENT"
assert_contains "cch-init-docs: allowed-tools has Write" "Write"               "$DOCS_CONTENT"

# cch-init-scaffold: user-invocable false, allowed-tools includes Write/Bash
SCAFFOLD_CONTENT="$(_read_skill cch-init-scaffold)"
assert_contains "cch-init-scaffold: has frontmatter"       "^---"                  "$SCAFFOLD_CONTENT"
assert_contains "cch-init-scaffold: user-invocable false"  "user-invocable: false" "$SCAFFOLD_CONTENT"
assert_contains "cch-init-scaffold: allowed-tools has Write" "Write"               "$SCAFFOLD_CONTENT"
assert_contains "cch-init-scaffold: allowed-tools has Bash"  "Bash"                "$SCAFFOLD_CONTENT"

# ── 3. Orchestrator structure — cch-init references all 3 sub-skills ─────────

echo ""
echo "--- 3. Orchestrator sub-skill references ---"

assert_contains "cch-init: references cch-init-scan"     "cch-init-scan"     "$INIT_CONTENT"
assert_contains "cch-init: references cch-init-docs"     "cch-init-docs"     "$INIT_CONTENT"
assert_contains "cch-init: references cch-init-scaffold" "cch-init-scaffold" "$INIT_CONTENT"

# ── 4. Mode branching — onboard and migrate strings present ──────────────────

echo ""
echo "--- 4. Mode branching ---"

assert_contains "cch-init: contains onboard mode" "onboard" "$INIT_CONTENT"
assert_contains "cch-init: contains migrate mode" "migrate" "$INIT_CONTENT"

# ── 5. Scan output schema — scan-result.json path referenced ─────────────────

echo ""
echo "--- 5. Scan output schema ---"

assert_contains "cch-init-scan: references scan-result.json" "scan-result.json" "$SCAN_CONTENT"

# ── 6. Docs generation targets — 4 documents referenced ─────────────────────

echo ""
echo "--- 6. Docs generation targets ---"

assert_contains "cch-init-docs: references Architecture" "Architecture" "$DOCS_CONTENT"
assert_contains "cch-init-docs: references PRD"          "PRD"          "$DOCS_CONTENT"
assert_contains "cch-init-docs: references Roadmap"      "Roadmap"      "$DOCS_CONTENT"
assert_contains "cch-init-docs: references TODO"         "TODO"         "$DOCS_CONTENT"

# ── 7. Scaffold targets — manifests/ and profiles/ referenced ────────────────

echo ""
echo "--- 7. Scaffold structure targets ---"

assert_contains "cch-init-scaffold: references manifests/" "manifests/" "$SCAFFOLD_CONTENT"
assert_contains "cch-init-scaffold: references profiles/"  "profiles/"  "$SCAFFOLD_CONTENT"
