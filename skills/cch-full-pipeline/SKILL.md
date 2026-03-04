---
name: cch-full-pipeline
description: "End-to-end: PRD interview -> team build -> parallel implementation -> verification -> delivery."
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, WebSearch, WebFetch
argument-hint: <project description>
---

# CCH Full Pipeline

End-to-end 프로젝트 파이프라인: PRD 인터뷰 → 팀 빌드 → 병렬 구현 → 합의 검증 → 최종 산출물.

4가지 페인포인트를 한 번에 해결합니다:
- 병렬 작업 실행
- 기획→개발 브릿지 (PRD → plan-bridge)
- 품질 검증 루프 (consensus review)
- 팀 협업 시뮬레이션 (team builder)

## Guidelines

---

## Prerequisites

1. Find the plugin root by searching for `bin/cch` executable.

## Steps

### Phase 1 — PRD Generation

1. Accept the user's project description (argument or AskUserQuestion if not provided).
2. Conduct an iterative interview via AskUserQuestion:
   - Target users and pain points
   - Core features and priority
   - Technical constraints
   - Success metrics
3. Generate 4 documents:
   - **PRD**: Problem statement, goals, features, scope
   - **User Stories**: Persona-based stories with acceptance criteria
   - **Technical Spec**: Architecture, data model, API design
   - **API Design**: Endpoints, schemas, auth model
4. Save all documents to `docs/plans/<date>-<project-slug>/`.
5. Create a TaskCreate entry: "[Pipeline] PRD Complete".

### Phase 2 — Team Building

1. Analyze the generated PRD to determine required roles and agent types.
2. Map roles to models:
   - Architecture/coordination: claude
   - Backend implementation: codex
   - Frontend/UI tasks: gemini (if applicable)
3. Create TaskCreate entries for each team member's assignment.
4. Report team composition to the user before proceeding.

### Phase 3 — Parallel Implementation

1. Use Agent(architect) to decompose the Technical Spec into parallel work units.
2. Create TaskCreate entries for each work unit with dependencies.
3. Spawn parallel agents using the Agent tool:
   - Each agent handles one work unit
   - Use isolation: "worktree" for independent work
4. Collect all results and resolve any integration conflicts.
6. Update TaskUpdate entries for completed work units.

### Phase 4 — Consensus Verification

1. Spawn 3 independent review agents in parallel using the Agent tool:
   - Agent 1: Correctness review (does the implementation match the spec?)
   - Agent 2: Security review (OWASP top 10, secrets, unsafe patterns)
   - Agent 3: Quality review (code style, maintainability, test coverage)
2. Collect all reviews with verdict (approve/reject/needs-work) and confidence scores.
3. Apply Byzantine consensus: require 2/3 supermajority.
4. If consensus is **approve**: proceed to Phase 5.
5. If consensus is **needs-work**:
   - Extract specific issues from review feedback.
   - Use Agent(executor) to fix identified issues.
   - Re-run verification (max 2 iterations).
6. If consensus is **reject** after retries: report issues to user for manual resolution.

### Phase 5 — Documentation & Delivery

1. Use Agent(writer) to generate final documentation:
   - Updated README sections (if applicable)
   - API documentation (if APIs were created)
   - Changelog entry
2. Update `docs/plans/<project-slug>/` with:
   - Implementation results per work unit
   - Verification results and consensus score
   - Final file change summary
3. Generate the pipeline execution report:

```
## Pipeline Report: <project-name>

| Phase | Status | Duration | Details |
|-------|--------|----------|---------|
| PRD Generation | ✓ | Xs | 4 documents |
| Team Building | ✓ | Xs | N agents |
| Implementation | ✓ | Xs | M work units |
| Verification | ✓ | Xs | Consensus: X% |
| Documentation | ✓ | Xs | N files updated |

### Files Changed
- `path/to/file` — description

### Verification Summary
- Correctness: PASS (confidence: X%)
- Security: PASS (confidence: X%)
- Quality: PASS (confidence: X%)
```

4. Report the final summary to the user with file paths and next steps.
