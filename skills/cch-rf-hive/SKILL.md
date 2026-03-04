---
name: cch-rf-hive
description: Byzantine fault-tolerant consensus with Queen-led hive mind.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, TaskCreate, TaskUpdate, TaskList
argument-hint: <decision topic or code review task>
---

# cch-rf-hive

Byzantine fault-tolerant consensus with a Queen-led hive mind of worker agents.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure ruflo`
3. Set: `RUFLO_CLI="$(sources_resolve_path ruflo)/bin/cli.js"` — or resolve manually: `RUFLO_CLI="$(pwd)/.claude/cch/sources/ruflo/bin/cli.js"`
4. Verify: `test -f "$RUFLO_CLI"` — if missing, report error and stop.

### Execution

1. Accept the decision topic or code review task.
2. Determine worker count N (default: 3, minimum for Byzantine tolerance: 3f+1 where f=1).

3. **Queen Setup**:
   - The main agent acts as Queen (coordinator).
   - Create TaskCreate entries for each worker evaluation.

4. **Worker Spawn**:
   - Spawn N Worker agents in parallel using the Agent tool.
   - Each worker independently evaluates the topic/code.
   - Workers use different perspectives: correctness, performance, security, maintainability.

5. **Collection**:
   - Gather all worker evaluations.
   - Each evaluation includes: verdict (approve/reject/needs-work), confidence score (0-100), detailed reasoning.

6. **Consensus Algorithm**:
   - Apply Byzantine fault tolerance: require 2/3 supermajority for consensus.
   - Calculate agreement score and identify outlier opinions.

7. **Report**:
   - Generate consensus report with:
     - Final verdict and confidence level
     - Majority reasoning summary
     - Dissenting opinions (if any)
     - Recommendations for action
   - If no consensus reached, report the split and recommend human decision.
