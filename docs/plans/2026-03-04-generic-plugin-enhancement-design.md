# Generic Plugin Enhancement System — Design

**Date:** 2026-03-04
**Status:** Approved
**Approach:** B (Auto-Register Capabilities)

---

## 1. 개요 및 목표

### 문제

CCH의 Tier/Enhancement 시스템이 `superpowers-marketplace`에 하드코딩되어 있어,
다른 플러그인(예: gptaku/kkirikkiri)이 설치돼도 Tier 0으로 인식됨.

하드코딩 포인트 3곳:
- `bin/cch` `_calculate_tier()` — `superpowers-marketplace` 디렉터리만 체크
- `scripts/lib/core.mjs` `calculateTier()` — 동일
- `scripts/check-env.mjs` `checkEnv()` — `capabilities.json` 등록 sources만 매칭

### 목표

1. **Generic Tier 계산**: 어떤 플러그인이든 설치되면 Tier 1로 인식
2. **Auto-Register Capabilities**: 감지된 플러그인을 capabilities에 동적 등록
3. **Status 노출**: `cch-status`에서 모든 설치된 플러그인과 스킬 표시
4. **하위 호환**: 기존 Enhancement 섹션의 `superpowers:*` 참조는 그대로 유지

### 비변경 범위

- Enhancement 섹션 리팩터링 안 함
- SKILL.md 파싱 안 함
- 플러그인 간 자동 대체(auto-substitute) 안 함

---

## 2. 아키텍처 / 변경 구조

### 변경 대상 파일 (4개)

| 파일 | 작업 | 설명 |
|------|------|------|
| `scripts/lib/core.mjs` | Modify | `calculateTier()` generic화 |
| `bin/cch` | Modify | `_calculate_tier()` generic화 |
| `scripts/check-env.mjs` | Modify | `checkEnv()` auto-register 로직 |
| `tests/test_contract.sh` | Modify | Tier 테스트 케이스 추가 |

### 데이터 흐름 (Before → After)

**Before:**
```
SessionStart → check-env.mjs → detectPlugins() → [결과 무시]
                             → calculateTier() → superpowers-marketplace 하드체크
                             → capabilities.json → 수동 등록 2개만 매칭
```

**After:**
```
SessionStart → check-env.mjs → detectPlugins() → [모든 플러그인 리스트]
                             → calculateTier() → plugins.length > 0 ? Tier1 : Tier0
                             → capabilities.json (정적) + detected plugins (동적) merge
                             → 통합 capabilities 맵 출력
```

### Tier 계산 규칙 변경

| 조건 | Before | After |
|------|--------|-------|
| 플러그인 없음 | Tier 0 | Tier 0 |
| superpowers만 설치 | Tier 1 | Tier 1 |
| gptaku만 설치 | **Tier 0** (버그) | **Tier 1** |
| superpowers + MCP | Tier 2 | Tier 2 |
| gptaku + MCP | **Tier 0** (버그) | **Tier 2** |
| 아무 플러그인 + MCP | Tier 0~1 | **Tier 2** |

---

## 3. 핵심 컴포넌트 변경 상세

### 3-1. `scripts/lib/core.mjs` — `calculateTier()`

```javascript
// After: generic plugin detection
export function calculateTier() {
  let tier = 0;
  const cacheDir = join(process.env.HOME || "", ".claude/plugins/cache");
  if (existsSync(cacheDir)) {
    try {
      const marketplaces = readdirSync(cacheDir);
      const hasPlugins = marketplaces.some(mp => {
        const mpDir = join(cacheDir, mp);
        try {
          return readdirSync(mpDir).length > 0;
        } catch { return false; }
      });
      if (hasPlugins) tier = 1;
    } catch { }
  }
  // MCP check (동일 로직)
  if (tier >= 1) {
    const mcpConfig = join(process.env.HOME || "", ".claude/mcp.json");
    try {
      const config = JSON.parse(readFileSync(mcpConfig, "utf8"));
      if (Object.keys(config.mcpServers || {}).length > 0) { tier = 2; }
    } catch { }
  }
  return tier;
}
```

### 3-2. `bin/cch` — `_calculate_tier()`

```bash
# After: generic plugin detection
_calculate_tier() {
  local tier=0
  local cache_dir="$HOME/.claude/plugins/cache"
  if [[ -d "$cache_dir" ]]; then
    local plugin_count
    plugin_count=$(find "$cache_dir" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l)
    if [[ "$plugin_count" -gt 0 ]]; then tier=1; fi
  fi
  # MCP check (기존 로직 동일)
  if [[ $tier -ge 1 ]]; then
    local mcp_config="$HOME/.claude/mcp.json"
    if [[ -f "$mcp_config" ]] && command -v node &>/dev/null; then
      local server_count
      server_count=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('$mcp_config','utf8'));console.log(Object.keys(c.mcpServers||{}).length)}catch{console.log(0)}" 2>/dev/null || echo "0")
      if [[ "$server_count" -gt 0 ]]; then
        tier=2
      fi
    fi
  fi
  echo "$tier"
}
```

### 3-3. `scripts/check-env.mjs` — `checkEnv()` auto-register

```javascript
export function checkEnv() {
  const plugins = detectPlugins();
  const mcpServers = detectMcpServers();
  const tier = calculateTier();
  const manifest = readManifest();

  const capabilities = {};

  // 1) 정적 등록 sources (기존 capabilities.json)
  for (const [srcName, srcDef] of Object.entries(manifest.sources || {})) {
    const detected = plugins.some(p => p.name === srcName);
    capabilities[srcName] = { ...srcDef, detected, tier_contribution: detected ? 1 : 0 };
  }

  // 2) 동적 auto-register (capabilities.json에 없는 플러그인)
  for (const plugin of plugins) {
    if (!capabilities[plugin.name]) {
      capabilities[plugin.name] = {
        type: "plugin",
        description: `Auto-detected plugin: ${plugin.name}@${plugin.version}`,
        required: false,
        detected: true,
        tier_contribution: 1,
        auto_detected: true,
      };
    }
  }

  return { tier, plugins, mcpServers, capabilities };
}
```

### 3-4. `manifests/capabilities.json`

변경 없음. 기존 수동 등록 유지. auto_detect된 플러그인은 런타임에만 추가됨.

---

## 4. 테스트 전략

### 단위 테스트 (scripts 레벨)

1. `calculateTier()` — 플러그인 없을 때 Tier 0
2. `calculateTier()` — superpowers만 있을 때 Tier 1
3. `calculateTier()` — gptaku만 있을 때 Tier 1 (신규)
4. `calculateTier()` — 아무 플러그인 + MCP → Tier 2
5. `checkEnv()` — auto-detect된 플러그인이 capabilities에 포함되는지

### 통합 테스트 (bash 레벨)

1. `_calculate_tier()` — 기존 superpowers 동작 보존
2. `_calculate_tier()` — 새 플러그인 감지

---

## 5. 산출물 맵

| 파일 | Create/Modify | 설명 |
|------|--------------|------|
| `scripts/lib/core.mjs` | Modify | `calculateTier()` generic화 (~15줄) |
| `bin/cch` | Modify | `_calculate_tier()` generic화 (~10줄) |
| `scripts/check-env.mjs` | Modify | `checkEnv()` auto-register (~15줄) |
| `tests/test_contract.sh` | Modify | Tier 테스트 케이스 추가 (~30줄) |
