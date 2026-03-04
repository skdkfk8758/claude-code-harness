#!/usr/bin/env bash
# Layer 4: Vendor Integration - E2E 통합 검증
# sources.json, capabilities.json, health-rules.json, profiles 일관성 확인

# --- sources.json 검증 ---
SOURCES_FILE="$ROOT_DIR/manifests/sources.json"
assert_file_exists "sources.json exists" "$SOURCES_FILE"

if [[ -f "$SOURCES_FILE" ]]; then
  sources_content="$(cat "$SOURCES_FILE")"

  # GPTaku post_install
  assert_contains "gptaku has post_install" "post_install" "$sources_content"
  assert_contains "gptaku post_install inits submodules" "git submodule update --init --recursive" "$sources_content"

  # All 5 vendors present
  for vendor in omc superpowers gptaku_plugins ruflo excalidraw; do
    assert_contains "source defined: $vendor" "\"$vendor\"" "$sources_content"
  done
fi

# --- capabilities.json 검증 ---
CAPS_FILE="$ROOT_DIR/manifests/capabilities.json"
assert_file_exists "capabilities.json exists" "$CAPS_FILE"

if [[ -f "$CAPS_FILE" ]]; then
  caps_content="$(cat "$CAPS_FILE")"

  # Skills arrays present for gptaku and ruflo
  assert_contains "gptaku_plugins has skills array" "cch-gp-team" "$caps_content"
  assert_contains "ruflo has skills array" "cch-rf-swarm" "$caps_content"
fi

# --- health-rules.json 검증 ---
RULES_FILE="$ROOT_DIR/manifests/health-rules.json"
assert_file_exists "health-rules.json exists" "$RULES_FILE"

if [[ -f "$RULES_FILE" ]]; then
  rules_content="$(cat "$RULES_FILE")"

  # R006 and R007 exist
  assert_contains "health rule R006 exists" "R006" "$rules_content"
  assert_contains "health rule R007 exists" "R007" "$rules_content"
  assert_contains "R006 covers code mode" "gptaku_skills_unavailable" "$rules_content"
  assert_contains "R007 covers SPARC" "sparc_unavailable" "$rules_content"
fi

# --- profiles 검증 ---
for profile in tool swarm plan code; do
  profile_file="$ROOT_DIR/profiles/$profile.json"
  assert_file_exists "profile exists: $profile" "$profile_file"

  if [[ -f "$profile_file" ]]; then
    profile_content="$(cat "$profile_file")"
    assert_contains "profile $profile: has capabilities" "capabilities" "$profile_content"
  fi
done

# --- profiles secondary capabilities ---
tool_content="$(cat "$ROOT_DIR/profiles/tool.json")"
assert_contains "tool profile: secondary includes omc" "omc" "$tool_content"

swarm_content="$(cat "$ROOT_DIR/profiles/swarm.json")"
assert_contains "swarm profile: secondary includes omc" "omc" "$swarm_content"

plan_content="$(cat "$ROOT_DIR/profiles/plan.json")"
assert_contains "plan profile: secondary includes gptaku" "gptaku_plugins" "$plan_content"

code_content="$(cat "$ROOT_DIR/profiles/code.json")"
assert_contains "code profile: secondary includes gptaku" "gptaku_plugins" "$code_content"
assert_contains "code profile: secondary includes ruflo" "ruflo" "$code_content"

# --- sources.sh 확장 함수 검증 ---
SOURCES_LIB="$ROOT_DIR/bin/lib/sources.sh"
assert_file_exists "sources.sh exists" "$SOURCES_LIB"

if [[ -f "$SOURCES_LIB" ]]; then
  lib_content="$(cat "$SOURCES_LIB")"
  assert_contains "sources_ensure function exists" "sources_ensure()" "$lib_content"
  assert_contains "sources_init_submodule function exists" "sources_init_submodule()" "$lib_content"
  assert_contains "sources_ensure_ruflo function exists" "sources_ensure_ruflo()" "$lib_content"
  assert_contains "cmd_sources has ensure action" "ensure)" "$lib_content"
  assert_contains "cmd_sources has init-submodule action" "init-submodule)" "$lib_content"
fi

# --- bin/cch sync_skills in setup 검증 ---
CCH_BIN="$ROOT_DIR/bin/cch"
assert_file_exists "bin/cch exists" "$CCH_BIN"

if [[ -f "$CCH_BIN" ]]; then
  cch_content="$(cat "$CCH_BIN")"
  assert_contains "cmd_setup calls sync_skills" "sync_skills" "$cch_content"
fi

# --- Full pipeline skill exists ---
assert_file_exists "full pipeline skill exists" "$ROOT_DIR/skills/cch-full-pipeline/SKILL.md"
if [[ -f "$ROOT_DIR/skills/cch-full-pipeline/SKILL.md" ]]; then
  pipeline_content="$(cat "$ROOT_DIR/skills/cch-full-pipeline/SKILL.md")"
  assert_contains "full pipeline: ensures gptaku" "sources ensure gptaku_plugins" "$pipeline_content"
  assert_contains "full pipeline: ensures ruflo" "sources ensure ruflo" "$pipeline_content"
fi

# --- Total skill count ---
total_new=$(ls -d "$ROOT_DIR"/skills/cch-gp-*/SKILL.md "$ROOT_DIR"/skills/cch-rf-*/SKILL.md "$ROOT_DIR"/skills/cch-full-pipeline/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
assert_equals "total new vendor skills is 16" "16" "$total_new"

# --- Phase VS: 서브모듈 경로 일관성 (하이픈 사용, 언더스코어 금지) ---
hyphen_skills=("cch-gp-prd" "cch-gp-research" "cch-gp-docs" "cch-gp-skill-builder" "cch-gp-mentor" "cch-gp-git-learn")
hyphen_paths=("show-me-the-prd" "deep-research" "docs-guide" "skillers-suda" "vibe-sunsang" "git-teacher")

for i in "${!hyphen_skills[@]}"; do
  skill="${hyphen_skills[$i]}"
  expected_path="${hyphen_paths[$i]}"
  skill_file="$ROOT_DIR/skills/$skill/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    skill_content="$(cat "$skill_file")"
    assert_contains "submodule path uses hyphens: $skill" "$expected_path" "$skill_content"
  fi
done

# --- Phase VS: profiles secondary 필드 존재 검증 ---
for profile in tool swarm plan code; do
  profile_file="$ROOT_DIR/profiles/$profile.json"
  if [[ -f "$profile_file" ]]; then
    p_content="$(cat "$profile_file")"
    assert_contains "profile $profile: has secondary field" "secondary" "$p_content"
  fi
done

# --- Phase VS: cch doctor Deep Diagnostics 출력 검증 ---
CCH_BIN="$ROOT_DIR/bin/cch"
if [[ -f "$CCH_BIN" ]]; then
  cch_content="$(cat "$CCH_BIN")"
  assert_contains "cch doctor: has deep diagnostics output" "Deep Diagnostics" "$cch_content"
fi

# --- Phase VS: 신규 스킬 존재 검증 ---
assert_file_exists "excalidraw skill exists" "$ROOT_DIR/skills/cch-excalidraw/SKILL.md"
assert_file_exists "gp-playground skill exists" "$ROOT_DIR/skills/cch-gp-playground/SKILL.md"

# --- Phase VS: sources.sh lock/unlock 함수 검증 ---
SOURCES_LIB="$ROOT_DIR/bin/lib/sources.sh"
if [[ -f "$SOURCES_LIB" ]]; then
  lib_content="$(cat "$SOURCES_LIB")"
  assert_contains "sources_lock function exists" "sources_lock()" "$lib_content"
  assert_contains "sources_unlock function exists" "sources_unlock()" "$lib_content"
  assert_contains "sources_check_lock function exists" "sources_check_lock()" "$lib_content"
fi

# --- Phase VS: sources.sh integrity 함수 검증 ---
if [[ -f "$SOURCES_LIB" ]]; then
  lib_content="$(cat "$SOURCES_LIB")"
  assert_contains "sources_record_checksums function exists" "sources_record_checksums()" "$lib_content"
  assert_contains "sources_verify_integrity function exists" "sources_verify_integrity()" "$lib_content"
fi

# --- Phase VS: health-rules.json R008 (excalidraw) 검증 ---
RULES_FILE="$ROOT_DIR/manifests/health-rules.json"
if [[ -f "$RULES_FILE" ]]; then
  rules_content="$(cat "$RULES_FILE")"
  assert_contains "health rule R008 exists" "R008" "$rules_content"
  assert_contains "R008 covers excalidraw" "excalidraw" "$rules_content"

  # R008 source must exactly match a key in sources.json
  SOURCES_FILE="$ROOT_DIR/manifests/sources.json"
  if [[ -f "$SOURCES_FILE" ]]; then
    r008_source="$(python3 -c "import json,sys; rules=json.load(open('$RULES_FILE')); print([r['source'] for r in rules['rules'] if r['id']=='R008'][0])")"
    sources_keys="$(python3 -c "import json; d=json.load(open('$SOURCES_FILE')); print(' '.join(d.get('sources',d).keys()))")"
    match_found=0
    for key in $sources_keys; do
      if [[ "$key" == "$r008_source" ]]; then match_found=1; break; fi
    done
    assert_eq "R008 source '$r008_source' exists in sources.json" "1" "$match_found"
  fi
fi
