#!/usr/bin/env bash
# sources.sh - External source auto-install/update module
# Reads manifests/sources.json and manages git clone/pull

# Parse sources.json and return source names
sources_list() {
  local registry="$CCH_ROOT/manifests/sources.json"
  if [[ ! -f "$registry" ]]; then
    echo ""
    return
  fi
  grep '"[a-z_]*"[[:space:]]*:' "$registry" \
    | grep -v '"sources"\|"repo"\|"target"\|"scope"\|"branch"\|"description"' \
    | sed 's/.*"\([a-z_]*\)".*/\1/'
}

# Get a field value from sources.json for a given source
sources_get() {
  local source="$1" field="$2"
  local registry="$CCH_ROOT/manifests/sources.json"
  [[ ! -f "$registry" ]] && return

  # Extract the block for the source, then get the field
  sed -n "/\"$source\"/,/\}/p" "$registry" \
    | sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -1
}

# Resolve the actual target path for a source
sources_resolve_path() {
  local source="$1"
  local target scope
  target="$(sources_get "$source" "target")"
  scope="$(sources_get "$source" "scope")"

  if [[ -z "$target" ]]; then
    return 1
  fi

  case "$scope" in
    project)
      # Project-level: absolute path from working directory
      echo "$(pwd)/$target"
      ;;
    plugin|*)
      # Plugin-level: relative to CCH_ROOT
      echo "$CCH_ROOT/$target"
      ;;
  esac
}

# Check if a source is installed
sources_is_installed() {
  local source="$1"
  local path
  path="$(sources_resolve_path "$source")" || return 1
  [[ -d "$path" ]]
}

# Helper: get a field for a source_id from sources.json (no jq required)
# Usage: _get_source_field <source_id> <field>
_get_source_field() {
  sources_get "$1" "$2"
}

# Get a nested health_check field (method or target) from sources.json
# Usage: _get_health_check_field <source_id> <subfield>
_get_health_check_field() {
  local source="$1" subfield="$2"
  local registry="$CCH_ROOT/manifests/sources.json"
  [[ ! -f "$registry" ]] && return

  # Extract the block for the source, then find health_check object, then the subfield
  sed -n "/\"$source\"/,/^    \}/p" "$registry" \
    | sed -n "/\"health_check\"/,/\}/p" \
    | sed -n "s/.*\"$subfield\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -1
}

# Check availability of a source using its health_check definition.
# Returns: 0=available, 1=unavailable, 2=degraded
sources_check_availability() {
  local source="$1"
  local health_method health_target
  health_method="$(_get_health_check_field "$source" "method")"
  health_target="$(_get_health_check_field "$source" "target")"

  if [[ -z "$health_method" ]]; then
    # No health_check defined — fall back to dir existence
    local path
    path="$(sources_resolve_path "$source")" || return 1
    [[ -d "$path" ]] && return 0 || return 1
  fi

  case "$health_method" in
    plugin_installed)
      # Check Claude Code plugin cache directory for plugin_id marker
      local plugin_cache="${HOME}/.claude/plugins"
      if [[ -n "$health_target" ]] && [[ -d "$plugin_cache" ]]; then
        # Plugin cache dirs are named after the plugin_id (with @ replaced by -)
        local cache_name
        cache_name="$(echo "$health_target" | tr '@' '-')"
        if [[ -d "$plugin_cache/$cache_name" ]] || [[ -d "$plugin_cache/$health_target" ]]; then
          return 0
        fi
      fi
      return 1
      ;;
    dir_exists)
      local check_path
      if [[ "$health_target" = /* ]]; then
        check_path="$health_target"
      else
        check_path="$(pwd)/$health_target"
      fi
      [[ -d "$check_path" ]] && return 0 || return 1
      ;;
    node_modules)
      local nm_path
      if [[ "$health_target" = /* ]]; then
        nm_path="$health_target"
      else
        nm_path="$(pwd)/$health_target"
      fi
      if [[ ! -d "$nm_path" ]]; then
        return 1
      fi
      # Degraded if node_modules exists but is essentially empty (no package dirs)
      local pkg_count
      pkg_count="$(ls -1 "$nm_path" 2>/dev/null | grep -v '^\.' | wc -l | tr -d ' ')"
      if [[ "$pkg_count" -eq 0 ]]; then
        return 2
      fi
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Type-specific install helpers ---

# Install a plugin-type source (Claude Code marketplace plugin)
_install_plugin() {
  local source="$1"
  local plugin_id marketplace
  plugin_id="$(_get_source_field "$source" "plugin_id")"
  marketplace="$(_get_source_field "$source" "marketplace")"
  echo "[PLUGIN] $source is a Claude Code plugin."
  echo "Install via: claude plugin install ${plugin_id:-$source}"
  if [[ -n "$marketplace" ]]; then
    echo "Add marketplace first: Settings > extraKnownMarketplaces > add \"$marketplace\""
  fi
  return 0
}

# Clone a git-type source and run post_install
_install_git() {
  local source="$1" repo="$2" branch="$3" path="$4"
  echo "[cch] Installing $source from $repo ..."
  mkdir -p "$(dirname "$path")"

  local clone_output
  if clone_output="$(git clone --depth 1 --branch "$branch" "$repo" "$path" 2>&1)"; then
    echo "[cch] Installed: $source -> $path"
    local post_install
    post_install="$(sources_get "$source" "post_install")"
    if [[ -n "$post_install" ]]; then
      echo "[cch] Running post-install for $source ..."
      if (cd "$path" && eval "$post_install" 2>&1); then
        echo "[cch] Post-install complete: $source"
      else
        echo "[cch] WARN: Post-install failed for $source (source still installed)"
        echo "[cch]   command: $post_install"
        echo "[cch]   retry: cd $path && $post_install"
      fi
    fi
    return 0
  else
    local exit_code=$?
    echo "[cch] ERROR: Failed to install $source (exit=$exit_code)"
    echo "[cch]   repo: $repo"
    echo "[cch]   target: $path"
    if echo "$clone_output" | grep -qi "not found\|404"; then
      echo "[cch]   cause: Repository not found"
    elif echo "$clone_output" | grep -qi "auth\|permission\|403"; then
      echo "[cch]   cause: Authentication required"
    elif echo "$clone_output" | grep -qi "timeout\|resolve"; then
      echo "[cch]   cause: Network error"
    else
      echo "[cch]   output: $(echo "$clone_output" | tail -2)"
    fi
    echo "[cch]   retry: cch sources install $source"
    return 1
  fi
}

# Clone an npm-type source, run npm install, and verify node_modules
_install_npm() {
  local source="$1" repo="$2" branch="$3" path="$4"
  _install_git "$source" "$repo" "$branch" "$path" || return 1
  # Verify node_modules after post_install
  if [[ ! -d "$path/node_modules" ]]; then
    local post_install
    post_install="$(sources_get "$source" "post_install")"
    echo "[cch] WARN: node_modules not found after post-install for $source"
    echo "[cch]   retry: cd $path && ${post_install:-npm install}"
  fi
  return 0
}

# Install a single source, dispatching to type-specific helpers
sources_install() {
  local source="$1"
  local install_type repo branch path
  install_type="$(_get_source_field "$source" "install_type")"
  install_type="${install_type:-git}"  # default to git if not present

  # --- local: built-in, no installation needed ---
  if [[ "$install_type" == "local" ]]; then
    echo "[LOCAL] $source is built-in. No installation needed."
    return 0
  fi

  # --- plugin: Claude Code plugin, no git clone ---
  if [[ "$install_type" == "plugin" ]]; then
    _install_plugin "$source"
    return $?
  fi

  # --- git / npm: require repo + path ---
  repo="$(sources_get "$source" "repo")"
  branch="$(sources_get "$source" "branch")"
  path="$(sources_resolve_path "$source")" || return 1

  if [[ -z "$repo" ]]; then
    echo "[cch] WARN: No repo URL for source: $source"
    return 1
  fi

  branch="${branch:-main}"

  if [[ -d "$path" ]]; then
    echo "[cch] Source already installed: $source ($path)"
    return 0
  fi

  if [[ "$install_type" == "npm" ]]; then
    _install_npm "$source" "$repo" "$branch" "$path"
  else
    _install_git "$source" "$repo" "$branch" "$path"
  fi
  return $?
}

# Update a single source (git pull)
sources_update() {
  local source="$1"
  local branch path
  branch="$(sources_get "$source" "branch")"
  path="$(sources_resolve_path "$source")" || return 1

  branch="${branch:-main}"

  if [[ ! -d "$path/.git" ]]; then
    echo "[cch] SKIP: $source is not a git repo ($path)"
    return 1
  fi

  echo "[cch] Updating $source ..."
  (cd "$path" && git pull origin "$branch" --ff-only 2>&1) || {
    echo "[cch] WARN: Failed to update $source (non-ff merge or network error)"
    return 1
  }
  echo "[cch] Updated: $source"
}

# Install all missing sources
sources_install_all() {
  local registry="$CCH_ROOT/manifests/sources.json"
  if [[ ! -f "$registry" ]]; then
    echo "[cch] No sources registry found (manifests/sources.json)"
    return 0
  fi

  local names installed=0 failed=0 skipped=0
  local failed_names=()
  names="$(sources_list)"

  if [[ -z "$names" ]]; then
    echo "[cch] No external sources defined"
    return 0
  fi

  echo "[cch] === Auto-installing external sources ==="
  echo ""

  while IFS= read -r source; do
    [[ -z "$source" ]] && continue
    local desc
    desc="$(sources_get "$source" "description")"

    if sources_is_installed "$source"; then
      echo "  [OK]   $source - already installed"
      skipped=$((skipped + 1))
    else
      echo "  [GET]  $source - $desc"
      if sources_install "$source"; then
        installed=$((installed + 1))
      else
        failed=$((failed + 1))
        failed_names+=("$source")
      fi
    fi
  done <<< "$names"

  echo ""
  echo "[cch] Sources: $installed installed, $skipped already present, $failed failed"

  if [[ ${#failed_names[@]} -gt 0 ]]; then
    echo ""
    echo "[cch] Failed sources - manual install commands:"
    for src in "${failed_names[@]}"; do
      echo "  cch sources install $src"
    done
  fi
  return 0
}

# Update all installed sources
sources_update_all() {
  local names
  names="$(sources_list)"

  if [[ -z "$names" ]]; then
    echo "[cch] No external sources defined"
    return 0
  fi

  echo "[cch] === Updating external sources ==="
  echo ""

  while IFS= read -r source; do
    [[ -z "$source" ]] && continue
    if sources_is_installed "$source"; then
      sources_update "$source"
    else
      echo "  [MISS] $source - not installed (run setup to install)"
    fi
  done <<< "$names"
}

# Ensure a source is installed (install if missing)
sources_ensure() {
  local source="$1"
  if sources_is_installed "$source"; then
    return 0
  fi
  echo "[cch] Source '$source' not installed, installing..."
  sources_install "$source"
}

# Initialize a submodule within a source (lazy init fallback)
sources_init_submodule() {
  local source="$1" submodule_path="$2"
  local src_path
  src_path="$(sources_resolve_path "$source")" || {
    echo "[cch] ERROR: Cannot resolve path for source: $source"
    return 1
  }

  local full_path="$src_path/$submodule_path"

  # Check if submodule directory exists and is non-empty
  if [[ -d "$full_path" ]] && [[ -n "$(ls -A "$full_path" 2>/dev/null)" ]]; then
    return 0
  fi

  echo "[cch] Initializing submodule: $source/$submodule_path ..."
  if (cd "$src_path" && git submodule update --init "$submodule_path" 2>&1); then
    echo "[cch] Submodule ready: $submodule_path"
    return 0
  else
    echo "[cch] ERROR: Failed to init submodule: $submodule_path"
    echo "[cch]   retry: cd $src_path && git submodule update --init $submodule_path"
    return 1
  fi
}

# Ensure Ruflo is ready (source installed + basic validation)
sources_ensure_ruflo() {
  sources_ensure ruflo || return 1

  local ruflo_path
  ruflo_path="$(sources_resolve_path ruflo)"
  local cli="$ruflo_path/bin/cli.js"

  if [[ ! -f "$cli" ]]; then
    echo "[cch] WARN: Ruflo CLI not found at $cli"
    echo "[cch]   The source may be incomplete. Try: cch sources update ruflo"
    return 1
  fi

  # Check node_modules (required)
  if [[ ! -d "$ruflo_path/node_modules" ]]; then
    echo "[cch] ERROR: ruflo node_modules not installed. Run: cch sources install ruflo"
    return 1
  fi

  return 0
}

# Lock all installed sources to manifests/release.lock
sources_lock() {
  local registry="$CCH_ROOT/manifests/sources.json"
  local lock_file="$CCH_ROOT/manifests/release.lock"
  local names
  names="$(sources_list)"

  if [[ -z "$names" ]]; then
    echo "[cch] No external sources defined"
    return 0
  fi

  local locked_at
  locked_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Build JSON lock file
  local sources_json=""
  local count=0

  while IFS= read -r source; do
    [[ -z "$source" ]] && continue
    local path branch commit
    path="$(sources_resolve_path "$source")" || continue

    if [[ ! -d "$path/.git" ]]; then
      continue
    fi

    commit="$(cd "$path" && git rev-parse HEAD 2>/dev/null)" || continue
    branch="$(sources_get "$source" "branch")"
    branch="${branch:-main}"
    local entry_ts
    entry_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    if [[ -n "$sources_json" ]]; then
      sources_json="${sources_json},"
    fi
    sources_json="${sources_json}
    \"$source\": {
      \"commit_sha\": \"$commit\",
      \"branch\": \"$branch\",
      \"locked_at\": \"$entry_ts\"
    }"
    count=$((count + 1))
  done <<< "$names"

  printf '{\n  "locked_at": "%s",\n  "sources": {%s\n  }\n}\n' \
    "$locked_at" "$sources_json" > "$lock_file"

  echo "[cch] Locked $count sources to manifests/release.lock"
  _generate_release_manifest
}

# Generate a signed release manifest after locking
# Writes to manifests/release-manifest.json
_generate_release_manifest() {
  local lock_file="$CCH_ROOT/manifests/release.lock"
  local integrity_file="$CCH_ROOT/.claude/cch/integrity.json"
  local manifest_file="$CCH_ROOT/manifests/release-manifest.json"

  local version git_sha build_date sources_lock_sha integrity_sha sig

  version="${CCH_VERSION:-0.0.0}"
  build_date="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  git_sha="$(git -C "$CCH_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")"

  if [[ -f "$lock_file" ]]; then
    sources_lock_sha="$(shasum -a 256 "$lock_file" 2>/dev/null | awk '{print $1}')"
  else
    sources_lock_sha="none"
  fi

  if [[ -f "$integrity_file" ]]; then
    integrity_sha="$(shasum -a 256 "$integrity_file" 2>/dev/null | awk '{print $1}')"
  else
    integrity_sha="none"
  fi

  # Signature: SHA256 of concatenated key fields
  sig="$(printf '%s%s%s%s' "$version" "$git_sha" "$sources_lock_sha" "$integrity_sha" \
    | shasum -a 256 | awk '{print $1}')"

  cat > "$manifest_file" <<EOF
{
  "version": "$version",
  "build_date": "$build_date",
  "git_sha": "$git_sha",
  "sources_lock": "$sources_lock_sha",
  "integrity_hash": "$integrity_sha",
  "test_results": { "total": 0, "passed": 0, "failed": 0 },
  "signature": {
    "method": "sha256",
    "value": "$sig"
  }
}
EOF

  echo "[cch] Release manifest written to manifests/release-manifest.json"
}

# Remove the release lock file
sources_unlock() {
  local lock_file="$CCH_ROOT/manifests/release.lock"
  if [[ -f "$lock_file" ]]; then
    rm "$lock_file"
    echo "[cch] Release lock removed"
  else
    echo "[cch] No lock file found (manifests/release.lock)"
  fi
}

# Check installed sources against the release lock
sources_check_lock() {
  local lock_file="$CCH_ROOT/manifests/release.lock"

  if [[ ! -f "$lock_file" ]]; then
    return 0
  fi

  local mismatch=0

  # Parse each locked source entry from the lock file
  # Extract source names from lock file (lines with a key followed by a colon inside sources block)
  local in_sources=0
  local current_source=""
  local locked_sha=""

  while IFS= read -r line; do
    if echo "$line" | grep -q '"sources"'; then
      in_sources=1
      continue
    fi

    if [[ "$in_sources" -eq 0 ]]; then
      continue
    fi

    # Detect source name key (indented with 4 spaces, not a known field)
    if echo "$line" | grep -qE '^    "[a-z_]+"[[:space:]]*:'; then
      current_source="$(echo "$line" | sed 's/.*"\([a-z_]*\)".*/\1/')"
      locked_sha=""
      continue
    fi

    # Capture commit_sha for current source
    if [[ -n "$current_source" ]] && echo "$line" | grep -q '"commit_sha"'; then
      locked_sha="$(echo "$line" | sed 's/.*"commit_sha"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"

      # Now check the actual commit
      local path actual_sha
      path="$(sources_resolve_path "$current_source" 2>/dev/null)" || continue

      if [[ ! -d "$path/.git" ]]; then
        echo "[cch] WARN: $current_source - not a git repo, skipping lock check"
        continue
      fi

      actual_sha="$(cd "$path" && git rev-parse HEAD 2>/dev/null)" || continue

      if [[ "$actual_sha" != "$locked_sha" ]]; then
        echo "[cch] WARN: $current_source - commit mismatch"
        echo "       expected: $locked_sha"
        echo "       actual:   $actual_sha"
        mismatch=$((mismatch + 1))
      fi
    fi
  done < "$lock_file"

  if [[ "$mismatch" -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Record SHA256 checksums of all SKILL.md files under installed sources
sources_record_checksums() {
  local integrity_file="$CCH_ROOT/.claude/cch/integrity.json"
  local names
  names="$(sources_list)"

  if [[ -z "$names" ]]; then
    echo "[cch] No external sources defined"
    return 0
  fi

  mkdir -p "$(dirname "$integrity_file")"

  local checksums_json=""
  local recorded_at
  recorded_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  while IFS= read -r source; do
    [[ -z "$source" ]] && continue
    local path
    path="$(sources_resolve_path "$source")" || continue
    [[ ! -d "$path" ]] && continue

    # Find all SKILL.md files under this source path
    while IFS= read -r skill_file; do
      [[ -z "$skill_file" ]] && continue
      local hash rel_path
      hash="$(shasum -a 256 "$skill_file" 2>/dev/null | awk '{print $1}')"
      [[ -z "$hash" ]] && continue
      # Make path relative to CCH_ROOT
      rel_path="${skill_file#$CCH_ROOT/}"
      if [[ -n "$checksums_json" ]]; then
        checksums_json="${checksums_json},"
      fi
      checksums_json="${checksums_json}
    \"$rel_path\": \"$hash\""
    done < <(find "$path" -name "SKILL.md" -type f 2>/dev/null)
  done <<< "$names"

  printf '{\n  "recorded_at": "%s",\n  "checksums": {%s\n  }\n}\n' \
    "$recorded_at" "$checksums_json" > "$integrity_file"

  echo "[cch] Integrity checksums recorded to .claude/cch/integrity.json"
}

# Verify SKILL.md files against recorded checksums
sources_verify_integrity() {
  local integrity_file="$CCH_ROOT/.claude/cch/integrity.json"

  if [[ ! -f "$integrity_file" ]]; then
    echo "No integrity record found. Run: cch sources integrity record"
    return 0
  fi

  local failures=0
  local in_checksums=0

  while IFS= read -r line; do
    if echo "$line" | grep -q '"checksums"'; then
      in_checksums=1
      continue
    fi

    [[ "$in_checksums" -eq 0 ]] && continue

    # Match lines like:  "some/path/SKILL.md": "sha256hash"
    if echo "$line" | grep -qE '"[^"]+SKILL\.md"[[:space:]]*:[[:space:]]*"[0-9a-f]+"'; then
      local rel_path expected_hash actual_hash full_path
      rel_path="$(echo "$line" | sed 's/.*"\([^"]*\)"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
      expected_hash="$(echo "$line" | sed 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"\([0-9a-f]*\)".*/\1/')"
      full_path="$CCH_ROOT/$rel_path"

      if [[ ! -f "$full_path" ]]; then
        echo "[INTEGRITY_FAIL] $rel_path (file missing)"
        failures=$((failures + 1))
        continue
      fi

      actual_hash="$(shasum -a 256 "$full_path" 2>/dev/null | awk '{print $1}')"

      if [[ "$actual_hash" != "$expected_hash" ]]; then
        echo "[INTEGRITY_FAIL] $rel_path (expected: $expected_hash, actual: $actual_hash)"
        failures=$((failures + 1))
      fi
    fi
  done < "$integrity_file"

  if [[ "$failures" -eq 0 ]]; then
    echo "[cch] Integrity check passed (all checksums match)"
  else
    echo "[cch] Integrity check failed: $failures file(s) modified"
  fi

  return "$failures"
}

# CLI handler for 'cch sources' subcommand
cmd_sources() {
  local action="${1:-status}"

  case "$action" in
    ensure)
      local target="${2:-}"
      if [[ -z "$target" ]]; then
        echo "[cch] Usage: cch sources ensure <source-name>"
        return 1
      fi
      sources_ensure "$target"
      ;;
    init-submodule)
      local source="${2:-}" subpath="${3:-}"
      if [[ -z "$source" || -z "$subpath" ]]; then
        echo "[cch] Usage: cch sources init-submodule <source> <submodule-path>"
        return 1
      fi
      sources_init_submodule "$source" "$subpath"
      ;;
    status)
      local names
      names="$(sources_list)"
      echo "=== External Sources ==="
      if [[ -z "$names" ]]; then
        echo "  No sources defined"
        return 0
      fi
      while IFS= read -r source; do
        [[ -z "$source" ]] && continue
        local path desc repo avail_label
        path="$(sources_resolve_path "$source")"
        desc="$(sources_get "$source" "description")"
        repo="$(sources_get "$source" "repo")"
        if [[ -d "$path" ]]; then
          sources_check_availability "$source"
          local avail_rc=$?
          case "$avail_rc" in
            0) avail_label="available" ;;
            2) avail_label="degraded" ;;
            *) avail_label="unavailable" ;;
          esac
          echo "  [OK]   $source ($desc) [$avail_label]"
          echo "         $path"
        else
          echo "  [MISS] $source ($desc)"
          echo "         repo: $repo"
        fi
      done <<< "$names"
      ;;
    install)
      local target="${2:-all}"
      if [[ "$target" == "all" ]]; then
        sources_install_all
      else
        sources_install "$target"
      fi
      ;;
    update)
      local target="${2:-all}"
      if [[ "$target" == "all" ]]; then
        sources_update_all
      else
        sources_update "$target"
      fi
      ;;
    lock)
      sources_lock
      ;;
    unlock)
      sources_unlock
      ;;
    check)
      sources_check_lock
      ;;
    integrity)
      local subcmd="${2:-}"
      case "$subcmd" in
        record)
          sources_record_checksums
          ;;
        verify)
          sources_verify_integrity
          ;;
        *)
          echo "[cch] Usage: cch sources integrity [record|verify]"
          return 1
          ;;
      esac
      ;;
    diagnose)
      local use_json=0
      [[ "${2:-}" == "--json" ]] && use_json=1
      local names
      names="$(sources_list)"
      if [[ -z "$names" ]]; then
        echo "[cch] No external sources defined"
        return 0
      fi

      if [[ "$use_json" -eq 1 ]]; then
        local json_entries=""
        while IFS= read -r source; do
          [[ -z "$source" ]] && continue
          local path desc install_status avail_label version integrity_status fix_hint
          path="$(sources_resolve_path "$source")"
          desc="$(sources_get "$source" "description")"

          # 1. Installation status
          if [[ -d "$path" ]]; then
            install_status="installed"
          else
            install_status="missing"
          fi

          # 2. Availability
          sources_check_availability "$source"
          local avail_rc=$?
          case "$avail_rc" in
            0) avail_label="available" ;;
            2) avail_label="degraded" ;;
            *) avail_label="unavailable" ;;
          esac

          # 3. Version (git commit SHA)
          if [[ -d "$path/.git" ]]; then
            version="$(cd "$path" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
          else
            version="n/a"
          fi

          # 4. Integrity
          local integrity_file="$CCH_ROOT/.claude/cch/integrity.json"
          if [[ -f "$integrity_file" ]] && grep -q "\"$source" "$integrity_file" 2>/dev/null; then
            integrity_status="recorded"
          else
            integrity_status="unrecorded"
          fi

          # 5. Fix hint
          if [[ "$install_status" == "missing" ]]; then
            fix_hint="cch sources install $source"
          elif [[ "$avail_label" == "unavailable" ]] || [[ "$avail_label" == "degraded" ]]; then
            local post_install
            post_install="$(sources_get "$source" "post_install")"
            if [[ -n "$post_install" ]]; then
              fix_hint="cd $path && $post_install"
            else
              fix_hint="cch sources update $source"
            fi
          else
            fix_hint=""
          fi

          [[ -n "$json_entries" ]] && json_entries="${json_entries},"
          json_entries="${json_entries}
    \"$source\": {
      \"description\": \"$desc\",
      \"install_status\": \"$install_status\",
      \"availability\": \"$avail_label\",
      \"version\": \"$version\",
      \"integrity\": \"$integrity_status\",
      \"fix\": \"$fix_hint\"
    }"
        done <<< "$names"
        printf '{\n  "sources": {%s\n  }\n}\n' "$json_entries"
      else
        echo "=== Source Diagnostics ==="
        echo ""
        while IFS= read -r source; do
          [[ -z "$source" ]] && continue
          local path desc install_status avail_label version integrity_status fix_hint
          path="$(sources_resolve_path "$source")"
          desc="$(sources_get "$source" "description")"

          # 1. Installation status
          if [[ -d "$path" ]]; then
            install_status="installed"
          else
            install_status="missing"
          fi

          # 2. Availability
          sources_check_availability "$source"
          local avail_rc=$?
          case "$avail_rc" in
            0) avail_label="available" ;;
            2) avail_label="degraded" ;;
            *) avail_label="unavailable" ;;
          esac

          # 3. Version (git commit SHA)
          if [[ -d "$path/.git" ]]; then
            version="$(cd "$path" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
          else
            version="n/a"
          fi

          # 4. Integrity
          local integrity_file="$CCH_ROOT/.claude/cch/integrity.json"
          if [[ -f "$integrity_file" ]] && grep -q "\"$source" "$integrity_file" 2>/dev/null; then
            integrity_status="recorded"
          else
            integrity_status="unrecorded"
          fi

          echo "  $source"
          echo "    description : $desc"
          echo "    installed   : $install_status"
          echo "    availability: $avail_label"
          echo "    version     : $version"
          echo "    integrity   : $integrity_status"

          # 5. Fix hint
          if [[ "$install_status" == "missing" ]]; then
            echo "    fix         : cch sources install $source"
          elif [[ "$avail_label" == "unavailable" ]] || [[ "$avail_label" == "degraded" ]]; then
            local post_install
            post_install="$(sources_get "$source" "post_install")"
            if [[ -n "$post_install" ]]; then
              echo "    fix         : cd $path && $post_install"
            else
              echo "    fix         : cch sources update $source"
            fi
          fi
          echo ""
        done <<< "$names"
      fi
      ;;
    *)
      echo "[cch] Usage: cch sources [status|install [name|all]|update [name|all]|ensure <name>|init-submodule <source> <path>|lock|unlock|check|integrity [record|verify]|diagnose [--json]]"
      ;;
  esac
}
