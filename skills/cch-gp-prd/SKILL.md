---
name: cch-gp-prd
description: Generate PRD from interview. Produces 4 documents from a single sentence.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, AskUserQuestion
argument-hint: <product idea or one-sentence description>
---

# cch-gp-prd

Generate a full set of product documents from a single sentence via structured interview. Produces PRD, User Stories, Technical Spec, and API Design documents.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/show-me-the-prd`
4. If either command fails, report the error and stop.

### Execution
1. Read show-me-the-prd template from the submodule.
2. **Intake**: Accept the user's product idea (argument or AskUserQuestion if not provided).
3. **Deep Interview**: Conduct iterative Q&A via AskUserQuestion to clarify:
   - Target users and their pain points
   - Core features and priority ranking
   - Technical constraints and preferences
   - Success metrics
4. **Document Generation**: Generate 4 documents:
   - **PRD** (Product Requirements Document): Problem statement, goals, features, scope
   - **User Stories**: Persona-based user stories with acceptance criteria
   - **Technical Spec**: Architecture, data model, API design, technology choices
   - **API Design**: Endpoint definitions, request/response schemas, auth model
5. **Save**: Write documents to `docs/plans/` directory with a date-prefixed naming convention.
6. **Bridge**: Note that plan-bridge (plan-bridge.mjs) will automatically detect new documents in `docs/plans/`.
7. Report generated file paths to the user.
