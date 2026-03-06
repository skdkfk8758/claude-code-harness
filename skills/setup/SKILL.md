---
name: setup
description: Use when first installing CCH or setting up a new project. Deploys HUD, validates plugin health, and cleans v2 legacy.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# CCH Setup

Initialize Claude Code Harness environment for the current system and project.

Plugin root: !`echo ${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname ${CLAUDE_SKILL_DIR}))}`

## Process

### Step 1: Environment Detection

1. Detect OS and Node.js version:
   ```bash
   uname -s
   node --version
   ```
2. Resolve plugin root path via bash injection above
3. Check for v2 remnants:
   - `.claude/cch/` directory exists?
   - `.beads/` directory exists?
   - `.git/hooks/pre-commit` contains "beads" or "bd"?

Report:
```
Environment
  OS: macOS (Darwin) / Linux
  Node: v22.x.x
  Plugin root: /path/to/plugin
  v2 detected: yes / no
```

### Step 2: v2 Legacy Cleanup (if detected)

Only run if Step 1 detected v2 remnants. Ask user before proceeding:

```
v2 잔재가 감지되었습니다. 정리하시겠습니까?
  - .claude/cch/ (v2 상태 디렉터리)
  - .beads/ (v2 beads 디렉터리)
  - .git/hooks/pre-commit (beads hook)
  - .git/hooks/post-merge (beads hook)
```

If approved:
1. Remove `.claude/cch/` if exists
2. Remove `.beads/` if exists
3. Remove `.git/hooks/pre-commit` if it contains "bead" or "bd"
4. Remove `.git/hooks/post-merge` if it contains "bead" or "bd"
5. Clean v2 skill permissions from `~/.claude/settings.json`:
   - Remove entries matching `Skill(cch-dot)`, `Skill(cch-sync)`, `Skill(cch-hud)`, `Skill(cch-sp-*)`, `Skill(cch-rf-*)`, `Skill(cch-gp-*)`

### Step 3: HUD Deployment

1. Create `~/.claude/hud/` directory if not exists
2. Copy HUD files from plugin root:
   ```bash
   cp "{plugin-root}/hud/cch-hud.mjs" ~/.claude/hud/cch-hud.mjs
   cp "{plugin-root}/hud/cch-hud-config.json" ~/.claude/hud/cch-hud-config.json
   ```
3. Read `~/.claude/settings.json`
4. Check if `statusLine` is already configured:
   - If not present or different command → update:
     ```json
     "statusLine": {
       "type": "command",
       "command": "node ~/.claude/hud/cch-hud.mjs",
       "padding": 0
     }
     ```
   - If already correct → skip
5. Write updated `~/.claude/settings.json`

**Important**: Preserve all existing settings — only add/update the `statusLine` key.

### Step 4: Project Preparation

1. Ensure `.claude/` directory exists in project root:
   ```bash
   mkdir -p .claude
   ```
2. Check project `.gitignore` for required entries:
   - `.claude/settings.local.json` — should be ignored (local preferences)
   - `.claude/workflow-state.json` — should be ignored (session state)
   - `.claude/knowledge-graph.json` — should be ignored (knowledge ontology, session-local)
   - `.DS_Store` — should be ignored
3. If missing entries found, ask user:
   ```
   .gitignore에 다음 항목 추가를 권장합니다:
     + .claude/workflow-state.json
   추가하시겠습니까?
   ```
4. If approved, append missing entries to `.gitignore`

### Step 5: Health Check

1. Glob skills: `{plugin-root}/skills/*/SKILL.md`
   - Expected: 10 (workflow, brainstorming, writing-plans, finishing-branch, systematic-debugging, tdd, verification, workflow-manager, skill-manager, cch-lsp)
2. Glob agents: `{plugin-root}/agents/*.md`
   - Expected: 10
3. Glob workflow YAMLs: `{plugin-root}/skills/workflow/*.yaml`
   - Expected: 6 (feature-dev, bugfix, refactor, quick-fix, planning-only, skill-creation)
4. Read `{plugin-root}/.claude-plugin/plugin.json` for version
5. Report any missing components

### Step 6: Output

```
╔══════════════════════════════════════╗
║  CCH Setup Complete (v0.3.0)        ║
╠══════════════════════════════════════╣
║  HUD         ✓ installed            ║
║  Skills      ✓ 10/10               ║
║  Agents      ✓ 10/10               ║
║  Workflows   ✓ 6/6                 ║
║  v2 cleanup  ✓ done  (or N/A)      ║
║  .gitignore  ✓ valid               ║
╠══════════════════════════════════════╣
║  Next steps:                        ║
║    /workflow feature-dev             ║
║    /cch-lsp  (optional, LSP setup)  ║
╚══════════════════════════════════════╝
```

## Rules
- Never overwrite existing `~/.claude/settings.json` entries other than `statusLine`
- Always ask before deleting v2 remnants
- Always ask before modifying `.gitignore`
- If plugin root cannot be resolved, report error and stop
- HUD files are COPIED, not symlinked (portability across systems)
