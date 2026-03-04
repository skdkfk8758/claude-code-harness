#!/usr/bin/env bash
# Layer 4: Branch Workflow - branch create/list/current/cleanup/base 검증
# Tests: G3 (existing branch), G4 (cleanup), G7 (uncommitted changes),
#        G14 (base fallback), state filename, plan-bridge integration

CCH="bash $ROOT_DIR/bin/cch"

# --- Setup: initialize git repo in temp dir for safe branch operations ---
ORIG_DIR="$(pwd)"
BRANCH_TEST_DIR="$(mktemp -d)"
cd "$BRANCH_TEST_DIR" || exit 1
git init -b main . >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "initial" >/dev/null 2>&1

# Point CCH_STATE_DIR to our test state
export CCH_STATE_DIR="$BRANCH_TEST_DIR/.claude/cch"
mkdir -p "$CCH_STATE_DIR"

# --- Test: branch base (default) ---
out="$($CCH branch base 2>&1)"
assert_equals "branch: base default is main" "main" "$out"

# --- Test: branch base (configured) ---
mkdir -p "$CCH_STATE_DIR/config"
echo "develop" > "$CCH_STATE_DIR/config/base_branch"
out="$($CCH branch base 2>&1)"
assert_equals "branch: base reads config" "develop" "$out"
echo "main" > "$CCH_STATE_DIR/config/base_branch"

# --- Test: branch create ---
out="$($CCH branch create feat br-test 2>&1)"
assert_contains "branch: create succeeds" "Branch created: feat/br-test" "$out"

# Verify state file exists
assert_file_exists "branch: state file created" "$CCH_STATE_DIR/branches/feat_br-test.yaml"

# Verify state file content
sf_branch="$(grep '^branch:' "$CCH_STATE_DIR/branches/feat_br-test.yaml" | head -1 | sed 's/^branch:[[:space:]]*//')"
sf_type="$(grep '^type:' "$CCH_STATE_DIR/branches/feat_br-test.yaml" | head -1 | sed 's/^type:[[:space:]]*//')"
sf_work="$(grep '^work_id:' "$CCH_STATE_DIR/branches/feat_br-test.yaml" | head -1 | sed 's/^work_id:[[:space:]]*//')"
sf_status="$(grep '^status:' "$CCH_STATE_DIR/branches/feat_br-test.yaml" | head -1 | sed 's/^status:[[:space:]]*//')"
assert_equals "branch: state has correct branch name" "feat/br-test" "$sf_branch"
assert_equals "branch: state has correct type" "feat" "$sf_type"
assert_equals "branch: state has correct work_id" "br-test" "$sf_work"
assert_equals "branch: state has correct status" "active" "$sf_status"

# --- Test: branch list ---
out="$($CCH branch list 2>&1)"
assert_contains "branch: list shows branch" "feat/br-test" "$out"
assert_contains "branch: list shows work_id" "br-test" "$out"

# --- Test: branch current ---
out="$($CCH branch current 2>&1)"
assert_contains "branch: current shows branch" "feat/br-test" "$out"
assert_contains "branch: current shows type" "feat" "$out"

# --- Test: G3 - existing branch checkout ---
git checkout main >/dev/null 2>&1
git branch feat/br-g3 >/dev/null 2>&1
out="$($CCH branch create feat br-g3 2>&1)"
assert_contains "branch: G3 existing branch switches" "already exists" "$out"
current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
assert_equals "branch: G3 checkout works" "feat/br-g3" "$current"

# --- Test: branch create with custom slug ---
git checkout main >/dev/null 2>&1
out="$($CCH branch create fix br-slug my-fix 2>&1)"
assert_contains "branch: create with custom slug" "Branch created: fix/my-fix" "$out"
current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
assert_equals "branch: custom slug checkout correct" "fix/my-fix" "$current"

# --- Test: G7 - uncommitted changes error ---
git checkout main >/dev/null 2>&1
echo "dirty" > "$BRANCH_TEST_DIR/dirty-file.txt"
git add dirty-file.txt >/dev/null 2>&1

out="$($CCH branch create feat br-dirty 2>&1)" && rc=0 || rc=$?
assert_contains "branch: G7 uncommitted error" "Uncommitted changes" "$out"
assert_exit_code "branch: G7 returns error code" 1 "$rc"

# Cleanup staged file
git reset HEAD dirty-file.txt >/dev/null 2>&1
rm -f "$BRANCH_TEST_DIR/dirty-file.txt"

# --- Test: G14 - base fallback chain ---
echo "nonexistent" > "$CCH_STATE_DIR/config/base_branch"

out="$($CCH branch create feat br-fallback 2>&1)" && rc=0 || rc=$?
# 'nonexistent' not found → tries 'master' (no) → tries 'origin/main' (no) → error
assert_contains "branch: G14 fallback error" "No base branch found" "$out"
assert_exit_code "branch: G14 returns error" 1 "$rc"

# Now test fallback to master: create a master branch in the test repo
git checkout main >/dev/null 2>&1
git branch master >/dev/null 2>&1
out="$($CCH branch create feat br-fallback 2>&1)"
assert_contains "branch: G14 fallback to master" "not found, using" "$out"
# Cleanup: delete master and fallback branch
git checkout main >/dev/null 2>&1
git branch -D master >/dev/null 2>&1
git branch -D feat/br-fallback >/dev/null 2>&1

# Reset config
echo "main" > "$CCH_STATE_DIR/config/base_branch"

# --- Test: branch cleanup (G4) ---
# Ensure we're on main and state file exists for br-test
git checkout main >/dev/null 2>&1
sf="$CCH_STATE_DIR/branches/feat_br-test.yaml"
if [[ -f "$sf" ]]; then
  sed -i.bak 's/^status:.*/status: merged/' "$sf" && rm -f "${sf}.bak"
fi

out="$($CCH branch cleanup 2>&1)"
assert_contains "branch: cleanup merged (G4)" "Cleaned up" "$out"
assert_contains "branch: cleanup reports count" "1 merged" "$out"

# Verify state file was removed after cleanup
if [[ ! -f "$sf" ]]; then
  TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1)); printf "  ${GREEN}PASS${NC} branch: cleanup removes state file\n"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} branch: cleanup removes state file\n"
fi

# --- Test: cleanup skips active branches ---
sf2="$CCH_STATE_DIR/branches/feat_br-g3.yaml"
out="$($CCH branch cleanup 2>&1)"
assert_contains "branch: cleanup skips active" "Cleaned up 0" "$out"

# --- Test: branch current on non-tracked branch ---
git checkout main >/dev/null 2>&1
out="$($CCH branch current 2>&1)"
assert_contains "branch: current non-tracked" "not tracked by cch" "$out"

# --- Test: branch list when empty ---
# Remove all state files
rm -rf "$CCH_STATE_DIR/branches"
out="$($CCH branch list 2>&1)"
assert_contains "branch: list empty" "No branches tracked" "$out"

# --- Test: branch state filename slash conversion ---
out="$(source "$ROOT_DIR/bin/lib/branch.sh" 2>/dev/null; branch_state_filename "feat/my-branch")"
assert_equals "branch: state filename / to _" "feat_my-branch" "$out"

out="$(source "$ROOT_DIR/bin/lib/branch.sh" 2>/dev/null; branch_state_filename "fix/deep/path")"
assert_equals "branch: state filename multi-slash" "fix_deep_path" "$out"

# --- Test: branch usage on invalid action ---
out="$($CCH branch invalid-action 2>&1)" && rc=0 || rc=$?
assert_contains "branch: invalid action shows usage" "Usage" "$out"
assert_exit_code "branch: invalid action returns error" 1 "$rc"

# --- Test: branch create without args ---
out="$($CCH branch create 2>&1)" && rc=0 || rc=$?
assert_contains "branch: create no args shows usage" "Usage" "$out"
assert_exit_code "branch: create no args returns error" 1 "$rc"

# --- Test: plan-bridge branch integration ---
# Verify plan-bridge.mjs has branch-related functions
if grep -q "branch" "$ROOT_DIR/scripts/plan-bridge.mjs" 2>/dev/null; then
  TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1)); printf "  ${GREEN}PASS${NC} plan-bridge: contains branch integration\n"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} plan-bridge: contains branch integration\n"
fi

# --- Test: cch-pr skill has branch workflow ---
if grep -q "branch" "$ROOT_DIR/skills/cch-pr/SKILL.md" 2>/dev/null; then
  TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1)); printf "  ${GREEN}PASS${NC} cch-pr: skill has branch workflow\n"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} cch-pr: skill has branch workflow\n"
fi

# --- Test: cch-commit skill has branch trailer ---
if grep -q "Branch" "$ROOT_DIR/skills/cch-commit/SKILL.md" 2>/dev/null; then
  TOTAL=$((TOTAL + 1)); PASS=$((PASS + 1)); printf "  ${GREEN}PASS${NC} cch-commit: skill has branch trailer\n"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1)); printf "  ${RED}FAIL${NC} cch-commit: skill has branch trailer\n"
fi

# --- Cleanup ---
cd "$ORIG_DIR" || true
rm -rf "$BRANCH_TEST_DIR"
