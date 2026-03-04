---
name: cch-gp-research
description: Deep research with multi-agent verification. 7-phase pipeline.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskList
argument-hint: <research topic or question>
---

# cch-gp-research

Deep research with multi-agent verification across a 7-phase pipeline. Produces a verified, synthesized research report with source confidence ratings.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/deep-research`
4. If either command fails, report the error and stop.

### Execution
1. **Topic Analysis**: Use Agent(analyst) to break down the research question into sub-questions and identify key search terms.
2. **Source Collection**: Use Agent(researcher) with WebSearch and WebFetch to gather information from multiple sources. Create TaskCreate entries for each sub-question.
3. **Fact Extraction**: Parse collected sources and extract key facts, claims, and data points.
4. **Cross-Verification**: Use Agent(verifier) to cross-reference claims across multiple sources. Flag contradictions and low-confidence findings.
5. **Synthesis**: Use Agent(scientist) to synthesize verified findings into a coherent narrative.
6. **Peer Review**: Use Agent(analyst) for a final critical review — check for gaps, biases, and unsupported claims.
7. **Report Generation**: Write the final research report to `docs/research/<topic-slug>.md` with:
   - Executive summary
   - Detailed findings per sub-question
   - Source list with confidence ratings
   - Limitations and areas for further research
