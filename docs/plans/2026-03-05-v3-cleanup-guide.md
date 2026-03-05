# CCH v3 Cleanup Guide - External Dependency Removal

- 작성일: 2026-03-05
- 용도: v3 리뉴얼 시 참고하는 삭제/정리 가이드

---

## 1. Archive (Phase 0) - 먼저 실행

아카이브를 먼저 만들어야 삭제 시 복구가 가능합니다.

### 1-1. v2 아카이브 디렉터리 생성

```bash
# 프로젝트 루트에서
mkdir -p archive/v2/plans
mkdir -p archive/v2/beads
mkdir -p archive/v2/config-snapshots
```

### 1-2. 기존 플랜 문서 아카이브

```bash
# v2 시절 플랜 문서 모두 이동
mv docs/plans/2026-03-04-*.md archive/v2/plans/

# v3 플랜 문서는 유지 (2026-03-05-* 파일들)
```

### 1-3. Beads 데이터 아카이브

```bash
# .beads 디렉터리 전체 복사 후 삭제
cp -r .beads/ archive/v2/beads/
rm -rf .beads/
```

### 1-4. 현재 설정 스냅샷

```bash
# 삭제 전 현재 설정 백업
cp ~/.claude/settings.json archive/v2/config-snapshots/global-settings.json
cp .claude/settings.local.json archive/v2/config-snapshots/project-settings.json
cp ~/.claude/plugins/installed_plugins.json archive/v2/config-snapshots/installed-plugins.json
cp ~/.claude/plugins/known_marketplaces.json archive/v2/config-snapshots/known-marketplaces.json
```

### 1-5. 아카이브 커밋 & 태그

```bash
git add archive/
git commit -m "archive: preserve v2 plans, beads data, and config snapshots"
git tag v2-archive
```

---

## 2. External Plugin Removal (Phase 6)

### 2-1. superpowers 삭제

**settings.json 수정** (`~/.claude/settings.json`):

```json
// enabledPlugins에서 제거:
"superpowers@superpowers-marketplace": true  // <- 이 줄 삭제
```

**캐시 삭제**:
```bash
rm -rf ~/.claude/plugins/cache/superpowers-marketplace/
```

**마켓플레이스 정리** (`~/.claude/plugins/known_marketplaces.json`):

```json
// 이 블록 전체 제거:
"superpowers-marketplace": {
  "source": { "source": "github", "repo": "obra/superpowers-marketplace" },
  ...
}
```

**settings.json extraKnownMarketplaces에서도 제거**:
```json
// extraKnownMarketplaces에서 제거:
"superpowers-marketplace": { ... }  // <- 이 블록 삭제
```

**installed_plugins.json에서 제거**:
```json
// plugins에서 제거:
"superpowers@superpowers-marketplace": [ ... ]  // <- 이 블록 삭제
```

### 2-2. kkirikkiri 삭제

**settings.json 수정**:
```json
// enabledPlugins에서 제거:
"kkirikkiri@gptaku-plugins": true  // <- 이 줄 삭제
```

**캐시 삭제**:
```bash
rm -rf ~/.claude/plugins/cache/gptaku-plugins/
```

**마켓플레이스 정리** (`known_marketplaces.json`):
```json
// 이 블록 전체 제거:
"gptaku-plugins": {
  "source": { "source": "git", "url": "https://github.com/fivetaku/gptaku_plugins.git" },
  ...
}
```

**installed_plugins.json에서 제거**:
```json
// plugins에서 제거:
"kkirikkiri@gptaku-plugins": [ ... ]  // <- 이 블록 삭제
```

### 2-3. oh-my-claudecode 정리

```bash
# oh-my-claudecode 디렉터리 확인 후 삭제
rm -rf ~/.claude/plugins/oh-my-claudecode/
```

**settings.json에서 관련 permission 제거**:
```json
// 이 항목들 제거:
"mcp__plugin_oh-my-claudecode_t__lsp_diagnostics"
"mcp__plugin_oh-my-claudecode_t__ast_grep_search"
"mcp__plugin_oh-my-claudecode_t__state_list_active"
"mcp__plugin_oh-my-claudecode_t__state_clear"
```

### 2-4. Beads CLI 관련 정리

`bd` CLI 자체는 글로벌 설치이므로 다른 프로젝트에서 사용 중이 아닌지 확인 후:

```bash
# 다른 프로젝트에서 .beads 사용 여부 확인
find ~/Workspace -name ".beads" -type d 2>/dev/null

# 이 프로젝트에서만 사용한다면 삭제 가능 (선택적)
# rm ~/.local/bin/bd
```

### 2-5. 프로젝트 settings.local.json 정리

`.claude/settings.local.json`에서 불필요한 permission 제거:
```json
// 제거 대상:
"Bash(bin/cch beads:*)"   // beads 서브커맨드
"Bash(bd:*)"              // bd CLI 직접 호출
```

---

## 3. Codebase Cleanup (Phase 1)

### 3-1. 삭제할 파일

```bash
# Beads 어댑터
rm bin/lib/beads.sh

# Beads 테스트
rm tests/test_beads.sh

# Beads 데이터 (아카이브 완료 후)
rm -rf .beads/
```

### 3-2. bin/cch 수정 포인트

```bash
# 확인: beads 서브커맨드 참조
grep -n "beads" bin/cch
# -> source 라인과 case 분기 제거

# 확인: Tier 로직
grep -n -i "tier" bin/cch
# -> Tier 1/2 분기 단순화 (Tier 0만 유지)
```

### 3-3. 스크립트 수정 포인트

```bash
# plan-bridge.mjs: beads create 호출
grep -n "beads" scripts/plan-bridge.mjs

# core.mjs: beads list 호출
grep -n "beads" scripts/lib/core.mjs

# bridge-output.mjs: bead_id 참조
grep -n "bead" scripts/lib/bridge-output.mjs

# test.sh: beads 테스트 레이어
grep -n "beads" scripts/test.sh
```

### 3-4. 스킬 수정 포인트 요약

| 스킬 | grep 패턴 | 작업 |
|------|----------|------|
| cch-plan | `bead\|Bead\|bd ` | Phase 3 전면 재작성 |
| cch-commit | `bead\|Bead` | 트레일러 방식 변경 |
| cch-todo | `bead\|Bead\|bd ` | 데이터 소스 변경 |
| cch-pr | `bead\|Bead` | 링크 방식 변경 |
| cch-team | `bead\|Bead\|bd ` | TaskList 전용으로 전환 |
| cch-init-scaffold | `bead\|Bead\|bd ` | 체크박스 방식으로 전환 |
| cch-init | `bead\|Bead` | 참조 제거 |
| cch-status | `bead\|Bead` | 표시 제거 |
| 모든 스킬 | `superpowers\|Enhancement\|Tier` | Enhancement 섹션 제거 |

---

## 4. 검증 체크리스트

삭제/수정 후 반드시 확인:

### 코드 정합성
- [ ] `grep -r "beads\|Bead\|bd " --include="*.{sh,mjs,json,md}" bin/ scripts/ skills/` — 잔여 참조 0
- [ ] `grep -r "superpowers" --include="*.{sh,mjs,json,md}" bin/ scripts/ skills/ manifests/ profiles/` — 잔여 참조 0
- [ ] `grep -r "kkirikkiri" --include="*.{sh,mjs,json,md}" skills/` — 잔여 참조 0
- [ ] `grep -r "Tier 1\|Tier 2\|tier_level" --include="*.{sh,mjs,json}" bin/ scripts/` — Tier 분기 0

### 테스트
- [ ] `bash scripts/test.sh all` — 전체 통과
- [ ] `node --test tests/unit/` — 유닛 테스트 통과

### 런타임
- [ ] 새 세션 시작 시 SessionStart 훅 정상 동작
- [ ] `/cch-plan` 호출 시 Beads 참조 없이 정상 동작
- [ ] `/cch-commit` 호출 시 `Plan:` 트레일러 생성 확인
- [ ] `/cch-todo` 호출 시 플랜 문서 기반 목록 표시

---

## 5. Rollback

문제 발생 시 복구 방법:

```bash
# v2 아카이브 태그로 전체 복원
git checkout v2-archive

# 또는 개별 파일 복원
git checkout v2-archive -- .beads/
git checkout v2-archive -- bin/lib/beads.sh

# 플러그인 재활성화
# settings.json의 enabledPlugins에 다시 추가
# 캐시는 플러그인 재설치로 복원
```

---

## 6. 참고: 삭제 후 남아야 하는 것

### 유지되는 플러그인
- **claude-code-harness** — 이것이 CCH 자체 (삭제 대상 아님)

### 유지되는 MCP 서버
- **serena** — 시맨틱 코드 분석 (외부 플러그인이 아닌 MCP)
- **context7** — 라이브러리 문서 조회
- **slack** — Slack 연동
- **bigquery** — BigQuery 쿼리

### 유지되는 설정
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — 팀 기능은 유지
- `statusLine` (cch-hud.mjs) — HUD 유지
- `language: korean` — 언어 설정
