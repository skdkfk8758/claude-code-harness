---
name: cch-init-docs
description: "프로젝트 문서 역산 생성 — Architecture/PRD/Roadmap/TODO 4개 문서 자동 생성"
user-invocable: false
allowed-tools: [Read, Write, Glob, Grep, Agent, AskUserQuestion]
---

# cch-init-docs

Generate 4 project documents (Architecture, PRD, Roadmap, TODO) from scan results produced by cch-init-scan.

## Prerequisites

Verify `.claude/cch/init/scan-result.json` exists before proceeding. If it is missing, report the error and stop — run cch-init-scan first.

## Steps

### Step 1: 스캔 결과 로드

1. Read `.claude/cch/init/scan-result.json`.
2. Extract project characteristics: primary language, frameworks, module count, entry points, dependency graph.
3. Note any existing `docs/` files so Step 3 (merge mode) can be applied where needed.

### Step 2: 4개 문서 병렬 생성

Spawn 3 Agent calls in parallel to draft the documents, then write them to `docs/`.

**Agent A** — generates `docs/Architecture.md`:
- System structure and layering
- Module dependency map
- Data flow diagrams (text-based)
- Full technology stack derived from scan results

**Agent B** — generates `docs/PRD.md` and `docs/Roadmap.md`:
- PRD: product vision, core feature list, user stories, non-functional requirements
- Roadmap: milestones, current progress inferred from existing code, next steps

Each document must include the marker `<!-- CCH-GENERATED -->` on the first non-frontmatter line so merge mode can locate generated sections.

### Step 3: 병합 모드 (기존 문서가 있을 때)

When a target file already exists in `docs/`:
1. Search the file for `<!-- CCH-GENERATED -->`.
2. If the marker is present, replace only the content between the marker and the next `<!-- /CCH-GENERATED -->` tag (or end of file) with the newly generated content.
3. If the marker is absent (manually authored file), use AskUserQuestion to ask the user whether to:
   - **Overwrite** the existing file entirely
   - **Append** the generated section below the existing content
   - **Skip** this document
4. Preserve all content outside the generated markers.

### Step 4: Cross-validation

After all 4 documents are written, perform consistency checks:

1. **Terminology**: Confirm that module names in Architecture.md match feature names in PRD.md.
2. **Feature ↔ Module mapping**: Every core feature in PRD.md must reference at least one module in Architecture.md.
3. **Milestone ↔ Phase mapping**: Each milestone in Roadmap.md must correspond to a Beads phase label.
4. **Dependency alignment**: Critical-path tasks in Beads must not depend on modules absent from Architecture.md.

Report all inconsistencies found. Do not auto-fix — list them clearly so the user can decide.

## Output

- List of created or updated document paths (absolute)
- Cross-validation result summary (pass / issues found)
- If issues were found, a numbered list of each inconsistency with file and section references
