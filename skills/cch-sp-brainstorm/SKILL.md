---
name: cch-sp-brainstorm
description: Use before any creative or implementation work — feature design, component creation, behavior changes. Runs structured design dialogue before any code is written.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write
argument-hint: <idea or feature to design>
---

# cch-sp-brainstorm

Collaborative design dialogue that turns ideas into approved specs before touching code. Explores requirements, proposes approaches, and writes a design doc before handing off to implementation planning.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates fully to the superpowers brainstorming skill. Follow it exactly:

1. **Explore project context** — check files, docs, recent commits.
2. **Ask clarifying questions** — one at a time until you understand purpose, constraints, and success criteria.
3. **Propose 2-3 approaches** — with trade-offs and a recommendation.
4. **Present design** — section by section, get user approval after each section.
5. **Write design doc** — save to `docs/plans/YYYY-MM-DD-<topic>-design.md` and commit.
6. **Hand off** — invoke `cch-sp-write-plan` to create the implementation plan.

**HARD GATE:** Do NOT write any code, scaffold any project, or take any implementation action until the user has approved the design. No exceptions.

### Key Rules
- One question per message only.
- Prefer multiple-choice questions.
- Apply YAGNI ruthlessly — remove unnecessary features from all designs.
- The only next step after this skill is `cch-sp-write-plan`.

## Integration

**Next skill:** `cch-sp-write-plan` — always invoke after design approval.

**Source skill:** `superpowers:brainstorming` at `.claude/cch/sources/superpowers/skills/brainstorming/SKILL.md`
