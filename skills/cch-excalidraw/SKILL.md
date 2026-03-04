---
name: cch-excalidraw
description: Excalidraw 다이어그램 생성 — 워크플로우, 아키텍처, 개념을 시각화
user-invocable: true
allowed-tools: Write, Read, Glob, Bash
argument-hint: <diagram description or topic>
---

# cch-excalidraw

Excalidraw 다이어그램 생성 — 워크플로우, 아키텍처, 개념을 시각화. Delegates to the standalone `excalidraw-diagram` skill installed at `.claude/skills/excalidraw-diagram/`, with CCH project context automatically injected.

## Steps

### Prerequisites
1. Verify the excalidraw-diagram skill exists at `.claude/skills/excalidraw-diagram/SKILL.md`.
2. If missing, report: "excalidraw-diagram skill not found at .claude/skills/excalidraw-diagram/" and stop.

### CCH Context Injection
Before generating the diagram, load the following CCH project context so diagrams accurately reflect the actual system:

1. If `docs/Architecture.md` exists, read it to understand the system architecture, component boundaries, and data flows.
2. If `docs/PRD.md` exists, read it to understand the product goals, user flows, and feature scope.
3. If the user's topic relates to a specific plan, read the relevant file from `docs/plans/` (e.g. `docs/plans/YYYY-MM-DD-<topic>.md`).
4. Use this context to:
   - Label diagram nodes with actual CCH component names (e.g. `bin/cch`, `scripts/plan-bridge.mjs`, `hooks/hooks.json`)
   - Reflect the real mode system (plan / code / tool / swarm)
   - Show actual data flows between CCH components where relevant

### Execution
1. Read `.claude/skills/excalidraw-diagram/SKILL.md` for the full diagram-generation methodology.
2. Read `.claude/skills/excalidraw-diagram/references/color-palette.md` for the color scheme.
3. Read `.claude/skills/excalidraw-diagram/references/element-templates.md` for copy-paste JSON templates.
4. Follow the design process defined in the excalidraw-diagram SKILL.md:
   - Assess depth (simple/conceptual vs. comprehensive/technical)
   - Understand the concept deeply and map to visual patterns
   - Apply CCH context from the injection step above
   - Generate `.excalidraw` JSON file section by section for large diagrams
5. Write the output `.excalidraw` file to `docs/diagrams/` by default, or the path specified by the user.
6. Render and validate using the render script:
   ```bash
   cd .claude/skills/excalidraw-diagram/references && uv run python render_excalidraw.py <path-to-file.excalidraw>
   ```
7. View the rendered PNG with the Read tool and iterate until the diagram is correct.
