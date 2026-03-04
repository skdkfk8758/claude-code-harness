---
name: cch-rf-sparc
description: SPARC methodology - Specification, Pseudocode, Architecture, Refinement, Completion.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, TaskCreate, TaskUpdate, TaskList
argument-hint: <task description>
---

# cch-rf-sparc

SPARC methodology: Specification, Pseudocode, Architecture, Refinement, Completion.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure ruflo`
3. Set: `RUFLO_CLI="$(sources_resolve_path ruflo)/bin/cli.js"` — or resolve manually: `RUFLO_CLI="$(pwd)/.claude/cch/sources/ruflo/bin/cli.js"`
4. Verify: `test -f "$RUFLO_CLI"` — if missing, report error and stop.

### Execution

1. Accept the task description from the user.
2. Create a TaskCreate entry for each SPARC phase.

3. **S — Specification**:
   - Use Agent(analyst) to produce a detailed specification document.
   - Define inputs, outputs, constraints, edge cases, and acceptance criteria.
   - Save to `docs/plans/<task-slug>-spec.md`.

4. **P — Pseudocode**:
   - Use Agent(architect) to write pseudocode for the solution.
   - Cover all major algorithms and data flows.
   - Review pseudocode against the specification.

5. **A — Architecture**:
   - Use Agent(architect) to design the system architecture.
   - Define modules, interfaces, data models, and dependencies.
   - Create architecture diagram description.

6. **R — Refinement**:
   - Use Agent(executor) to implement the solution based on architecture and pseudocode.
   - Iterate: implement → test → fix → re-test until all tests pass.
   - Update TaskUpdate status for each iteration.

7. **C — Completion**:
   - Use Agent(verifier) to perform final validation.
   - Run all tests, check code quality (LSP diagnostics).
   - Generate documentation for the implementation.
   - Write completion report with metrics (lines changed, tests passed, coverage).
