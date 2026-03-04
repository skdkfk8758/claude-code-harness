#!/usr/bin/env bash
# Source Type System - install_type 필드 및 동작 검증

SOURCES_FILE="$ROOT_DIR/manifests/sources.json"
SOURCES_LIB="$ROOT_DIR/bin/lib/sources.sh"
_ST_TMP=""

# --- 1. install_type 필드 존재: All 5 sources have install_type ---
if [[ -f "$SOURCES_FILE" ]]; then
  sources_content="$(cat "$SOURCES_FILE")"

  for vendor in omc superpowers gptaku_plugins ruflo excalidraw; do
    # Extract the block for this vendor and check install_type is present
    vendor_block="$(sed -n "/\"$vendor\"/,/\}/p" "$SOURCES_FILE")"
    assert_contains "install_type field exists: $vendor" "install_type" "$vendor_block"
  done
fi

# --- 2. plugin 유형: omc and superpowers have marketplace and plugin_id ---
if [[ -f "$SOURCES_FILE" ]]; then
  for vendor in omc superpowers; do
    vendor_block="$(sed -n "/\"$vendor\"/,/\}/p" "$SOURCES_FILE")"
    assert_contains "$vendor has marketplace field" "marketplace" "$vendor_block"
    assert_contains "$vendor has plugin_id field" "plugin_id" "$vendor_block"
    assert_contains "$vendor install_type is plugin" '"install_type": "plugin"' "$vendor_block"
  done
fi

# --- 3. npm 유형: ruflo has install_type npm and post_install ---
if [[ -f "$SOURCES_FILE" ]]; then
  ruflo_block="$(sed -n "/\"ruflo\"/,/\}/p" "$SOURCES_FILE")"
  assert_contains "ruflo install_type is npm" '"install_type": "npm"' "$ruflo_block"
  assert_contains "ruflo has post_install field" "post_install" "$ruflo_block"
fi

# --- 4. git 유형: gptaku_plugins has install_type git ---
if [[ -f "$SOURCES_FILE" ]]; then
  gptaku_block="$(sed -n "/\"gptaku_plugins\"/,/\}/p" "$SOURCES_FILE")"
  assert_contains "gptaku_plugins install_type is git" '"install_type": "git"' "$gptaku_block"
fi

# --- 5. sources_install plugin 스킵: outputs [PLUGIN] guidance, no git clone ---
if [[ -f "$SOURCES_LIB" ]]; then
  # Source the library with a mock CCH_ROOT pointing to actual project root
  (
    CCH_ROOT="$ROOT_DIR"
    export CCH_ROOT
    source "$SOURCES_LIB"
    out="$(sources_install omc 2>&1)"
    echo "$out"
  ) > /tmp/_cch_plugin_test.out 2>&1 || true
  plugin_out="$(cat /tmp/_cch_plugin_test.out)"
  assert_contains "sources_install plugin: prints [PLUGIN] tag" "[PLUGIN]" "$plugin_out"
  assert_contains "sources_install plugin: shows install command" "claude plugin install" "$plugin_out"
  assert_not_contains "sources_install plugin: does not attempt git clone" "git clone" "$plugin_out"
  rm -f /tmp/_cch_plugin_test.out
fi

# --- 6. sources_install local 스킵: outputs [LOCAL] skip message ---
if [[ -f "$SOURCES_LIB" ]]; then
  # Create a minimal temporary sources.json with a local-type source
  tmp_dir="$(mktemp -d)"
  tmp_manifest="$tmp_dir/manifests/sources.json"
  mkdir -p "$tmp_dir/manifests"
  cat > "$tmp_manifest" <<'MANIFEST'
{
  "sources": {
    "mylocal": {
      "repo": "",
      "target": ".claude/cch/sources/mylocal",
      "scope": "project",
      "branch": "main",
      "description": "Local built-in source",
      "install_type": "local"
    }
  }
}
MANIFEST

  (
    CCH_ROOT="$tmp_dir"
    export CCH_ROOT
    source "$SOURCES_LIB"
    out="$(sources_install mylocal 2>&1)"
    echo "$out"
  ) > /tmp/_cch_local_test.out 2>&1 || true
  local_out="$(cat /tmp/_cch_local_test.out)"
  assert_contains "sources_install local: prints [LOCAL] tag" "[LOCAL]" "$local_out"
  assert_contains "sources_install local: says no installation needed" "No installation needed" "$local_out"
  rm -f /tmp/_cch_local_test.out
  rm -rf "$tmp_dir"
fi

# --- 7. install_type 기본값: missing install_type defaults to git behavior ---
# Verify the default fallback is implemented in source code (static check)
if [[ -f "$SOURCES_LIB" ]]; then
  lib_content="$(cat "$SOURCES_LIB")"
  # The implementation uses ${install_type:-git} to default missing field to git
  assert_contains "sources_install: defaults missing install_type to git" 'install_type:-git' "$lib_content"
  # The git/npm branch (non-plugin, non-local) uses repo + git clone
  assert_contains "sources_install: git branch uses git clone" "git clone" "$lib_content"
  # Neither plugin nor local branch is entered when install_type is git/empty
  # Verified by: plugin branch only entered when == "plugin", local only when == "local"
  assert_contains "sources_install: plugin branch is conditional" '"plugin"' "$lib_content"
  assert_contains "sources_install: local branch is conditional" '"local"' "$lib_content"
fi

# --- 8. sources.sh 소스 타입 분기 코드 존재 검증 ---
if [[ -f "$SOURCES_LIB" ]]; then
  lib_content="$(cat "$SOURCES_LIB")"
  assert_contains "sources.sh: handles plugin install_type" '"plugin"' "$lib_content"
  assert_contains "sources.sh: handles local install_type" '"local"' "$lib_content"
  assert_contains "sources.sh: handles npm install_type" '"npm"' "$lib_content"
  assert_contains "sources.sh: defaults install_type to git" 'install_type:-git' "$lib_content"
  assert_contains "sources.sh: get_source_field reads install_type" 'install_type' "$lib_content"
fi

# --- 9. superpowers plugin_id 검증 ---
if [[ -f "$SOURCES_FILE" ]]; then
  superpowers_block="$(sed -n "/\"superpowers\"/,/\}/p" "$SOURCES_FILE")"
  assert_contains "superpowers plugin_id set" "superpowers@superpowers-marketplace" "$superpowers_block"
  assert_contains "superpowers marketplace set" "superpowers-marketplace" "$superpowers_block"
fi

# --- 10. omc plugin_id 검증 ---
if [[ -f "$SOURCES_FILE" ]]; then
  omc_block="$(sed -n "/\"omc\"/,/\}/p" "$SOURCES_FILE")"
  assert_contains "omc plugin_id set" "oh-my-claudecode@omc" "$omc_block"
  assert_contains "omc marketplace set" '"marketplace"' "$omc_block"
fi
