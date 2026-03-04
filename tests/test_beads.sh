#!/usr/bin/env bash
# Layer: Beads adapter - create → transition → close roundtrip
# Tests: beads_check, create, show, list, transition, close, ready, dep

CCH="bash $ROOT_DIR/bin/cch"

# --- Setup: use temp dir with bd init ---
ORIG_DIR="$(pwd)"
BEADS_TEST_DIR="$(mktemp -d)"
cd "$BEADS_TEST_DIR" || exit 1
git init -b main . >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "initial" >/dev/null 2>&1

# Initialize beads in test dir
bd init --prefix cch >/dev/null 2>&1

# Point CCH_ROOT to test dir (beads_check looks for $CCH_ROOT/.beads)
export CCH_ROOT="$BEADS_TEST_DIR"
export CCH_STATE_DIR="$BEADS_TEST_DIR/.claude/cch"
export CCH_LIB_DIR="$ORIG_DIR/bin/lib"
mkdir -p "$CCH_STATE_DIR"

# Source beads.sh directly for unit-style testing
source "$CCH_LIB_DIR/beads.sh"

# --- Test: beads_check ---
out="$(beads_check 2>&1)"
ec=$?
assert_exit_code "beads: check passes with .beads/ present" "0" "$ec"

# --- Test: beads_create ---
out="$(beads_create "Test item alpha" --priority 1 --labels "phase:1,test" 2>&1)"
ec=$?
assert_exit_code "beads: create succeeds" "0" "$ec"
assert_contains "beads: create shows bead ID" "cch-" "$out"
assert_contains "beads: create shows title" "Test item alpha" "$out"

# Extract bead ID from output (last line)
BEAD_A="$(echo "$out" | grep -o 'cch-[a-z0-9]*' | head -1)"

# --- Test: beads_show ---
out="$(beads_show "$BEAD_A" 2>&1)"
ec=$?
assert_exit_code "beads: show succeeds" "0" "$ec"
assert_contains "beads: show displays title" "Test item alpha" "$out"

# --- Test: beads_show --json ---
out="$(beads_show "$BEAD_A" --json 2>&1)"
assert_contains "beads: show --json has id" "$BEAD_A" "$out"

# --- Test: beads_list ---
out="$(beads_list 2>&1)"
ec=$?
assert_exit_code "beads: list succeeds" "0" "$ec"
assert_contains "beads: list shows bead" "$BEAD_A" "$out"

# --- Test: beads_list --json ---
out="$(beads_list --json 2>&1)"
assert_contains "beads: list --json has id" "$BEAD_A" "$out"

# --- Test: beads_transition todo→doing ---
out="$(beads_transition "$BEAD_A" doing 2>&1)"
ec=$?
assert_exit_code "beads: transition to doing succeeds" "0" "$ec"
assert_contains "beads: transition output" "doing" "$out"

# Verify status changed
out="$(bd show "$BEAD_A" --json 2>&1)"
assert_contains "beads: status is in_progress after transition" "in_progress" "$out"

# --- Test: beads_transition doing→blocked ---
out="$(beads_transition "$BEAD_A" blocked 2>&1)"
ec=$?
assert_exit_code "beads: transition to blocked succeeds" "0" "$ec"

out="$(bd show "$BEAD_A" --json 2>&1)"
assert_contains "beads: status is blocked" "blocked" "$out"

# --- Test: beads_transition blocked→doing ---
out="$(beads_transition "$BEAD_A" doing 2>&1)"
ec=$?
assert_exit_code "beads: transition back to doing succeeds" "0" "$ec"

# --- Test: beads_transition doing→done (close) ---
out="$(beads_transition "$BEAD_A" done 2>&1)"
ec=$?
assert_exit_code "beads: transition to done succeeds" "0" "$ec"

out="$(bd show "$BEAD_A" --json 2>&1)"
assert_contains "beads: status is closed after done" "closed" "$out"

# --- Test: beads_close with reason ---
# Create a new bead to test close
out="$(beads_create "Item to close" 2>&1)"
BEAD_B="$(echo "$out" | grep -o 'cch-[a-z0-9]*' | head -1)"

out="$(beads_close "$BEAD_B" --reason "completed task" 2>&1)"
ec=$?
assert_exit_code "beads: close with reason succeeds" "0" "$ec"
assert_contains "beads: close output" "closed" "$out"

# --- Test: beads_ready ---
# Create open items for ready test
out="$(beads_create "Ready item 1" --priority 1 2>&1)"
BEAD_C="$(echo "$out" | grep -o 'cch-[a-z0-9]*' | head -1)"
out="$(beads_create "Ready item 2" --priority 2 2>&1)"
BEAD_D="$(echo "$out" | grep -o 'cch-[a-z0-9]*' | head -1)"

out="$(beads_ready --limit 5 2>&1)"
ec=$?
assert_exit_code "beads: ready succeeds" "0" "$ec"
assert_contains "beads: ready shows open item" "$BEAD_C" "$out"

# --- Test: beads_dep_add ---
out="$(beads_dep_add "$BEAD_D" "$BEAD_C" 2>&1)"
ec=$?
assert_exit_code "beads: dep add succeeds" "0" "$ec"
assert_contains "beads: dep output" "depends on" "$out"

# --- Test: beads_create missing title ---
out="$(beads_create 2>&1)" && ec=0 || ec=$?
assert_exit_code "beads: create without title fails" "1" "$ec"
assert_contains "beads: create error shows usage" "Usage" "$out"

# --- Test: invalid transition state ---
out="$(beads_transition "$BEAD_C" invalid 2>&1)" && ec=0 || ec=$?
assert_exit_code "beads: invalid state fails" "1" "$ec"
assert_contains "beads: invalid state error" "Invalid state" "$out"

# --- Test: beads_list --status filter ---
out="$(beads_list --status done --all 2>&1)"
assert_contains "beads: list --status done shows closed" "$BEAD_A" "$out"

# --- Cleanup ---
cd "$ORIG_DIR" || true
rm -rf "$BEADS_TEST_DIR"
