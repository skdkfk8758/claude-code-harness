#!/usr/bin/env bash
# build-release.sh - Build a submodule-free release bundle
# Usage: ./scripts/build-release.sh [output_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(bash "$ROOT_DIR/bin/cch" version | awk '{print $2}')"
OUTPUT_DIR="${1:-$ROOT_DIR/dist}"
BUNDLE_NAME="claude-code-harness-${VERSION}"
BUNDLE_DIR="$OUTPUT_DIR/$BUNDLE_NAME"

echo "[build] Building release bundle v${VERSION}..."
echo "[build] Output: $BUNDLE_DIR"

# Clean previous build
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Copy plugin structure (no submodules, no dev files)
INCLUDE_DIRS=(".claude-plugin" "skills" "hooks" "bin" "profiles" "manifests" "overlays" "dot" "scripts")

for dir in "${INCLUDE_DIRS[@]}"; do
  if [[ -d "$ROOT_DIR/$dir" ]]; then
    cp -R "$ROOT_DIR/$dir" "$BUNDLE_DIR/$dir"
  fi
done

# Copy root config files
for file in .gitignore; do
  if [[ -f "$ROOT_DIR/$file" ]]; then
    cp "$ROOT_DIR/$file" "$BUNDLE_DIR/$file"
  fi
done

# Remove .gitkeep files from bundle
find "$BUNDLE_DIR" -name ".gitkeep" -delete 2>/dev/null || true

# Ensure bin/cch is executable
chmod +x "$BUNDLE_DIR/bin/cch"

# Verify required files exist in bundle
REQUIRED_FILES=("bin/cch" "bin/lib/sources.sh" "manifests/capabilities.json" "manifests/sources.json" "scripts/mode-detector.sh" "scripts/plan-bridge.mjs" "scripts/todo-sync-check.sh")
missing=0
for req in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$BUNDLE_DIR/$req" ]]; then
    echo "[build] ERROR: Required file missing from bundle: $req"
    missing=$((missing + 1))
  fi
done
if [[ $missing -gt 0 ]]; then
  echo "[build] ABORT: $missing required file(s) missing. Ensure all files are git-tracked."
  exit 1
fi

# Generate lock file with checksums
echo "[build] Generating checksums..."
LOCK_FILE="$BUNDLE_DIR/manifests/release.lock"
{
  echo "# Release lock - claude-code-harness v${VERSION}"
  echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
  find "$BUNDLE_DIR" -type f -not -name "release.lock" | sort | while read -r f; do
    local_path="${f#$BUNDLE_DIR/}"
    checksum="$(shasum -a 256 "$f" | awk '{print $1}')"
    echo "$checksum  $local_path"
  done
} > "$LOCK_FILE"

# Summary
FILE_COUNT="$(find "$BUNDLE_DIR" -type f | wc -l | tr -d ' ')"
echo "[build] Bundle complete: $BUNDLE_DIR"
echo "[build] Files: $FILE_COUNT"
echo "[build] Version: $VERSION"
echo "[build] No submodule dependencies."
