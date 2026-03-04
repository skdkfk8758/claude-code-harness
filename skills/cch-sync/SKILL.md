---
name: cch-sync
description: Sync cch binary and skills to plugin cache. Run after adding or modifying skills.
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Sync

소스 `bin/cch` 바이너리와 `skills/` 디렉터리를 플러그인 캐시에 동기화합니다.
다른 프로젝트(ad-simulator 등)에서도 안전하게 사용 가능합니다. 프로젝트별 소유권을 추적하여 스킬 충돌을 방지합니다.

## Steps

1. Locate the plugin cache path from `$HOME/.claude/plugins/installed_plugins.json`.
2. Try running the cached binary first. If `sync` command is not found, fall back to `$PWD/bin/cch`:

```bash
# Try cached binary first
CACHE_BIN=$(sed -n 's/.*"installPath"[[:space:]]*:[[:space:]]*"\([^"]*claude-code-harness[^"]*\)".*/\1/p' "$HOME/.claude/plugins/installed_plugins.json" | head -1)

if bash "$CACHE_BIN/bin/cch" sync 2>/dev/null; then
  echo "Sync complete via cached binary."
elif [[ -f "$PWD/bin/cch" ]]; then
  bash "$PWD/bin/cch" sync
else
  echo "ERROR: No cch binary with sync support found."
  exit 1
fi
```

3. Report the sync result (binary update + skills added/updated/removed/unchanged) to the user.
4. If changes were made, remind the user to restart Claude Code session.
